package CSV::Test;

use strict;

our @open_params;
our @close_params;

use lib '../httpd_modperl/lib/perl';

use parent qw(Test::Class);
use Test::More;
use Test::MockObject;
use Test::MockModule;
use Data::Dumper;

BEGIN {
    no strict 'refs';
    use Symbol ();

    *CORE::GLOBAL::open = sub (*;$@) {
        my $res = CORE::open($_[0], $_[1], $_[2]);
        @open_params = ($_[0], $_[1], $_[2]);
        return $res;
    };

    *CORE::GLOBAL::close = sub (*) {
        @close_params = @_;
        return CORE::close($_[0]);
    };
}

use CSV;

sub clear_params
{
    @open_params = ();
    @close_params = ();
}

###
# Start up method to be run before any tests get going.
##
sub start_up : Test(startup => 0)
{
}

###
# Shut down method to do clean up after all tests have run.
##
sub shut_down : Test(shutdown => 0)
{
}

###
# Set up method to be run at the beginning of each test.
##
sub set_up : Test(setup => 0)
{
}

###
# Tear down method to be run after each test.
##
sub tear_down : Test(teardown => 1)
{
    clear_params();
    unlink('t/fixtures/gen_test_csv.txt') if -e 't/fixtures/gen_test_csv.txt';
}

sub test_readLine_basic_csv : Tests
{
    my $csv = CSV->new("a,b,c\n1,2,3\n4,5,6");
    is_deeply($csv->readLine(), [qw(a b c)]);
    is_deeply($csv->readLine(), [qw(1 2 3)]);
    is_deeply($csv->readLine(), [qw(4 5 6)]);
    is($csv->readLine(), undef);
}

sub test_readLine_quoted_strings : Tests
{
    my @rows = (
        'a,"b",c',
        '1,"2 ""apples""",3',
        '4,5,6'
    );
    my $csv = CSV->new(join("\n", @rows));
    is_deeply($csv->readLine(), [qw(a b c)]);
    is_deeply($csv->readLine(), ['1', '2 "apples"', '3']);
    is_deeply($csv->readLine(), [qw(4 5 6)]);
    is($csv->readLine(), undef);
}

sub test_readLine_fields_with_commas : Tests
{
    my @rows = (
        'a,"b",c',
        '1,"one, two, three",3',
        '4,5,6'
    );
    my $csv = CSV->new(join("\n", @rows));
    is_deeply($csv->readLine(), [qw(a b c)]);
    is_deeply($csv->readLine(), ['1', 'one, two, three', '3']);
    is_deeply($csv->readLine(), [qw(4 5 6)]);
    is($csv->readLine(), undef);
}

sub test_readLine_fields_with_newlines : Tests
{
    my @rows = (
        'a,"b",c',
        qq(1,"one\ntwo\nthree",3),
        '4,5,6'
    );
    my $csv = CSV->new(join("\n", @rows));
    is_deeply($csv->readLine(), [qw(a b c)]);
    is_deeply($csv->readLine(), ['1', "one\ntwo\nthree", '3']);
    is_deeply($csv->readLine(), [qw(4 5 6)]);
    is($csv->readLine(), undef);
}

sub test_readLine_fields_mixed_cases : Tests
{
    my @rows = (
        'a,"b",c',
        qq(1,"one\ntwo ""apples"", and\nthree, four",3),
        '4,5,6'
    );
    my $csv = CSV->new(join("\n", @rows));
    is_deeply($csv->readLine(), [qw(a b c)]);
    is_deeply($csv->readLine(), ['1', qq{one\ntwo "apples", and\nthree, four}, '3']);
    is_deeply($csv->readLine(), [qw(4 5 6)]);
    is($csv->readLine(), undef);
}

sub test_readLine_empty_lines : Tests
{
    my @rows = (
        'a,"b",c',
        '',
        '4,5,6'
    );
    my $csv = CSV->new(join("\n", @rows));
    is_deeply($csv->readLine(), [qw(a b c)]);
    is_deeply($csv->readLine(), []);
    is_deeply($csv->readLine(), [qw(4 5 6)]);
    is($csv->readLine(), undef);
}

sub test_readLine_skips_empty_lines : Tests
{
    my @rows = (
        'a,"b",c',
        '',
        '4,5,6',
        '',
        ''
    );
    my $csv = CSV->new(join("\n", @rows), { 'skip_blanks' => 1 });
    is_deeply($csv->readLine(), [qw(a b c)]);
    is_deeply($csv->readLine(), [qw(4 5 6)]);
    is($csv->readLine(), undef);
}

sub test_readLine_empty_fields : Tests
{
    my @rows = (
        'a,,c',
        ',,',
        '4,5,'
    );
    my $csv = CSV->new(join("\n", @rows));
    is_deeply($csv->readLine(), ['a', '', 'c']);
    is_deeply($csv->readLine(), ['','','']);
    is_deeply($csv->readLine(), ['4', '5', '']);
    is($csv->readLine(), undef);
}

sub test_rewind_restarts_csv_parsing : Tests
{
    my @rows = (
        'a,b,c',
        '1,2,3'
    );
    my $csv = CSV->new(join("\n", @rows));
    is_deeply($csv->readLine(), ['a', 'b', 'c']);
    $csv->rewind();
    is_deeply($csv->readLine(), ['a','b','c']);
    is_deeply($csv->readLine(), [1,2,3]);
}

sub test_readLines_calls_readLine_repeatedly_until_undef_and_adds_to_array : Test
{
    my @rows = (
        [1, 2, 3],
        'any',
        ['other results']
    );
    my $csv_mod = Test::MockModule->new("CSV");
    $csv_mod->mock('readLine', sub { return shift(@rows); });
    my $csv = CSV->new('');
    is_deeply($csv->readLines(), [[1,2,3],'any',['other results']]);
}

sub test_readLines_reads_lines_from_last_position : Tests
{
    my @rows = (
        'a,b,c',
        '1,2,3',
        '4,5,6'
    );
    my $csv = CSV->new(join("\n", @rows));
    is_deeply($csv->readLine(), ['a', 'b', 'c']);
    is_deeply($csv->readLines(), [['1','2','3'],['4','5','6']]);
}

sub test_line_returns_the_last_parsed_line : Tests
{
    my $csv = CSV->new("a,b,c\n1,2,3\n4,5,6\n");
    $csv->readLine();
    is_deeply($csv->line(), "a,b,c\n");
    $csv->readLine();
    is_deeply($csv->line(), "1,2,3\n");
    $csv->readLine();
    is_deeply($csv->line(), "4,5,6\n");
    is($csv->readLine(), undef);
    is_deeply($csv->line(), "4,5,6\n");
}

sub test_lineno_returns_the_last_parsed_line_number : Tests
{
    my $csv = CSV->new("a,b,c\n1,2,3\n4,5,6");
    $csv->readLine();
    is($csv->lineno(), 1);
    $csv->readLine();
    is($csv->lineno(), 2);
    $csv->readLine();
    is($csv->lineno(), 3);
    is($csv->readLine(), undef);
    is($csv->lineno(), 3);
}

sub test_line_and_lineno_returns_the_last_non_skipped_line : Tests
{
    my $csv = CSV->new("a,b,c\n\n1,2,3\n\n\n", { skip_blanks => 1 });
    $csv->readLine();
    is($csv->lineno(), 1);
    is_deeply($csv->line(), "a,b,c\n");
    $csv->rewind();
    $csv->readLine();
    is($csv->lineno(), 1);
    is_deeply($csv->line(), "a,b,c\n");
    $csv->readLine();
    is($csv->lineno(), 3);
    is_deeply($csv->line(), "1,2,3\n");
    is($csv->readLine(), undef);
    is($csv->lineno(), 3);
    is_deeply($csv->line(), "1,2,3\n");
}

sub test_returnHeaders_returns_return_headers_option : Tests
{
    my $csv = CSV->new("a,b,c\n1,2,3\n4,5,6", {'return_headers' => 'OPT VAL'});
    is($csv->returnHeaders(), 'OPT VAL');
}

sub test_each_calls_readLine_repeatedly_until_undef_and_passes_to_sub : Tests
{
    my @rows = (
        '1,2,3',
        'any,other,val'
    );
    my @results;
    my $csv = CSV->new(join("\n", @rows));
    $csv->each(sub {
        my $line = shift;
        push(@results, $line);
    });
    is_deeply(\@results, [[1,2,3],['any','other','val']]);
}

sub test_each_sub_never_called_for_empty_strings : Tests
{
    my @rows = (
        '1,2,3',
        'any,other,val'
    );
    my $called = 0;
    my $csv = CSV->new('');
    $csv->each(sub { $called = 1 });
    is($called, 0);
}

sub test_readLine_read_mixed_content_from_file_handler : Tests
{
    open(my $fh, '<', 't/fixtures/test_csv.txt');
    my $csv = CSV->new($fh);
    is_deeply($csv->readLine(), [qw(one two three)]);
    is_deeply($csv->readLine(), ['123', qq{456\n+ 2 "apples", and grapes}, '789']);
    is_deeply($csv->readLine(), [qw(a b c d)]);
    is($csv->readLine(), undef);
    close($fh);
}

sub test_parse_without_sub_is_a_shorcut_to_new_csv_object_and_readLines : Tests
{
    my $options = {};
    my @params;
    my $read_lines = 0;
    my $read_lines_res = {};
    my $csv_mod = Test::MockModule->new('CSV');
    my $csv_mock = Test::MockObject->new()
        ->mock('readLines', sub { $read_lines = 1; return $read_lines_res });
    $csv_mod->mock('new', sub { shift; push(@params, @_); return $csv_mock; });

    my $res = CSV->parse("a,b,c\n1,2,3", $options);

    is($params[0], "a,b,c\n1,2,3");
    is($params[1], $options);
    is($read_lines, 1);
    is($res, $read_lines_res);
}

sub test_parse_with_sub_is_a_shorcut_to_new_csv_object_and_each : Tests
{
    my $options = {};
    my $sub = sub {};
    my (@params1, @params2);
    my $csv_mod = Test::MockModule->new('CSV');
    my $csv_mock = Test::MockObject->new()
        ->mock('each', sub { shift; push(@params2, @_); });
    $csv_mod->mock('new', sub { shift; push(@params1, @_); return $csv_mock; });

    CSV->parse("a,b,c\n1,2,3", $options, $sub);

    is($params1[0], "a,b,c\n1,2,3");
    is($params1[1], $options);
    is($params2[0], $sub);
}

sub test_parseline_is_a_shorcut_to_new_csv_object_and_readLine : Tests
{
    my $options = {};
    my @params;
    my $read_line = 0;
    my $read_line_res = {};
    my $csv_mod = Test::MockModule->new('CSV');
    my $csv_mock = Test::MockObject->new()
        ->mock('readLine', sub { $read_line = 1; return $read_line_res });
    $csv_mod->mock('new', sub { shift; push(@params, @_); return $csv_mock; });

    my $res = CSV->parseLine("a,b,c\n1,2,3", $options);

    is($params[0], "a,b,c\n1,2,3");
    is($params[1], $options);
    is($read_line, 1);
    is($res, $read_line_res);
}

sub test_foreach_is_a_shorcut_to_open_file_new_csv_object_each_and_close_file : Tests
{
    my $options = {};
    my $sub = sub {};
    my (@params1, @params2, $closed);

    my $csv_mod = Test::MockModule->new('CSV');
    my $csv_mock = Test::MockObject->new()
        ->mock('each', sub { shift; push(@params2, @_); })
        ->mock('close', sub { $closed = 1 });
    $csv_mod->mock('new', sub { shift; push(@params1, @_); return $csv_mock; });

    CSV->foreach('t/fixtures/test_csv.txt', $options, $sub);

    is(ref $open_params[0], 'GLOB');
    is($open_params[1], '<');
    is($open_params[2], 't/fixtures/test_csv.txt');
    ok($closed);

    is($params1[0], $open_params[0]);
    is($params1[1], $options);
    is($params2[0], $sub);
}

sub test_read_is_a_shorcut_to_open_file_new_csv_object_readLines_and_close_file : Tests
{
    my $options = {};
    my $readlines_res = ['result'];
    my (@params1, $closed);

    my $csv_mod = Test::MockModule->new('CSV');
    my $csv_mock = Test::MockObject->new()
        ->mock('readLines', sub { return $readlines_res })
        ->mock('close', sub { $closed = 1 });
    $csv_mod->mock('new', sub { shift; push(@params1, @_); return $csv_mock; });

    my $res = CSV->read('t/fixtures/test_csv.txt', $options);

    is(ref $open_params[0], 'GLOB');
    is($open_params[1], '<');
    is($open_params[2], 't/fixtures/test_csv.txt');
    ok($closed);

    is($params1[0], $open_params[0]);
    is($params1[1], $options);
    is($res, $readlines_res);
}

sub test_readLine_with_headers_return_instances_of_csv_row : Tests
{
    my $csv = CSV->new("a,b,c\n1,2,3\n4,5,6\n", { 'headers' => 1 });
    is(ref $csv->readLine(), 'CSV::Row');
}

sub test_readLine_with_headers_creates_field_csv_rows_skipping_header_row : Tests
{
    my $csv = CSV->new("a,b,c\n1,2,3\n4,5,6\n", { 'headers' => 1 });
    my $row = $csv->readLine();
    is_deeply($row->fields(), [qw(1 2 3)]);
    is_deeply($row->headers(), [qw(a b c)]);
    ok($row->isFieldRow());
    $row = $csv->readLine();
    is_deeply($row->fields(), [qw(4 5 6)]);
    is_deeply($row->headers(), [qw(a b c)]);
    ok($row->isFieldRow());
    is($csv->readLine(), undef);
}

sub test_readLine_with_headers_sets_headers_on_first_read : Tests
{
    my $csv = CSV->new("a,b,c\n1,2,3\n4,5,6\n", { 'headers' => 1 });
    is($csv->headers(), 1);
    $csv->readLine();
    is_deeply($csv->headers(), [qw(a b c)]);
}

sub test_readLine_with_headers_and_return_headers_set_to_true_does_not_skip_header_row : Tests
{
    my $csv = CSV->new("a,b,c\n1,2,3\n", { 'headers' => 1, 'return_headers' => 1 });
    my $row = $csv->readLine();
    is_deeply($row->fields(), [qw(a b c)]);
    is_deeply($row->headers(), [qw(a b c)]);
    ok($row->isHeaderRow());
    $row = $csv->readLine();
    is_deeply($row->fields(), [qw(1 2 3)]);
    is_deeply($row->headers(), [qw(a b c)]);
    ok($row->isFieldRow());
    is($csv->readLine(), undef);
}

sub test_readLine_with_custom_headers_does_not_skip_first_row : Tests
{
    my $csv = CSV->new("a,b,c\n1,2,3\n", { 'headers' => [qw(m mm mmm)] });
    my $row = $csv->readLine();
    is_deeply($row->fields(), [qw(a b c)]);
    is_deeply($row->headers(), [qw(m mm mmm)]);
    ok($row->isFieldRow());
    $row = $csv->readLine();
    is_deeply($row->fields(), [qw(1 2 3)]);
    is_deeply($row->headers(), [qw(m mm mmm)]);
    ok($row->isFieldRow());
    is($csv->readLine(), undef);
}

sub test_readLine_with_custom_headers_uses_given_headers : Tests
{
    my $headers = [qw(m mm mmm)];
    my $csv = CSV->new("a,b,c\n1,2,3\n4,5,6\n", { 'headers' => $headers });
    is($csv->headers(), $headers);
    $csv->readLine();
    is($csv->headers(), $headers);
}

sub test_readLines_encloses_csv_rows_in_csv_table : Tests
{
    my $csv = CSV->new("a,b,c\n1,2,3\n", { 'headers' => 1 });
    my $table = $csv->readLines();
    is(ref $table, 'CSV::Table');
    is_deeply($table->headers(), [qw(a b c)]);
    my $rows = $table->rows();
    is_deeply($rows->[0]->fields(), [qw(1 2 3)]);
    is_deeply($rows->[0]->headers(), [qw(a b c)]);
    ok($rows->[0]->isFieldRow());
    is(scalar(@$table), 1);
}

sub test_readLines_encloses_csv_rows_in_csv_table_without_skipping_headers : Tests
{
    my $csv = CSV->new("a,b,c\n1,2,3\n", { 'headers' => 1, 'return_headers' => 1 });
    my $table = $csv->readLines();
    is(ref $table, 'CSV::Table');
    is_deeply($table->headers(), [qw(a b c)]);
    my $rows = $table->rows();
    is_deeply($rows->[0]->fields(), [qw(a b c)]);
    is_deeply($rows->[0]->headers(), [qw(a b c)]);
    ok($rows->[0]->isHeaderRow());
    is_deeply($rows->[1]->fields(), [qw(1 2 3)]);
    is_deeply($rows->[1]->headers(), [qw(a b c)]);
    ok($rows->[1]->isFieldRow());
    is(scalar(@$table), 2);
}

sub test_skipBlanks_returns_the_headers_options : Tests
{
    my $csv = CSV->new("a,b,c\n1,2,3\n", { 'skip_blanks' => 'BLANK VAL' });
    is($csv->skipBlanks(), 'BLANK VAL');
}

sub test_readLine_assembles_and_returns_rows_with_the_right_headers_and_fields : Tests
{
    my (@rows, @params);
    push(@rows, bless({}, 'Row')) for (1..2);
    my @expected_rows = @rows;

    my $row_mod = Test::MockModule->new('CSV::Row');
    $row_mod->mock('new', sub { shift; push(@params, [@_]);  return shift(@rows); });

    my $csv = CSV->new("a,b,c\n1,2,3\n4,5,6", { 'headers' => 1 });
    is($csv->readLine(), $expected_rows[0]);
    is($csv->readLine(), $expected_rows[1]);
    is($csv->readLine(), undef);
    is_deeply($params[0], [[qw(a b c)], [qw(1 2 3)]]);
    is_deeply($params[1], [[qw(a b c)], [qw(4 5 6)]]);
}

sub test_readLine_assembles_and_returns_rows_with_the_right_headers_and_fields_custom_headers : Tests
{
    my (@rows, @params);
    push(@rows, bless({}, 'Row')) for (1..3);
    my @expected_rows = @rows;

    my $row_mod = Test::MockModule->new('CSV::Row');
    $row_mod->mock('new', sub { shift; push(@params, [@_]);  return shift(@rows); });

    my $csv = CSV->new("a,b,c\n1,2,3\n4,5,6", { 'headers' => [qw(m n o)] });
    is($csv->readLine(), $expected_rows[0]);
    is($csv->readLine(), $expected_rows[1]);
    is($csv->readLine(), $expected_rows[2]);
    is($csv->readLine(), undef);
    is_deeply($params[0], [[qw(m n o)], [qw(a b c)]]);
    is_deeply($params[1], [[qw(m n o)], [qw(1 2 3)]]);
    is_deeply($params[2], [[qw(m n o)], [qw(4 5 6)]]);
}

sub test_readLine_assembles_and_returns_rows_with_the_right_headers_and_fields_return_headers : Tests
{
    my (@rows, @params);
    push(@rows, bless({}, 'Row')) for (1..3);
    my @expected_rows = @rows;

    my $row_mod = Test::MockModule->new('CSV::Row');
    $row_mod->mock('new', sub { shift; push(@params, [@_]);  return shift(@rows); });

    my $csv = CSV->new("a,b,c\n1,2,3\n4,5,6", { 'headers' => 1, 'return_headers' => 1 });
    is($csv->readLine(), $expected_rows[0]);
    is($csv->readLine(), $expected_rows[1]);
    is($csv->readLine(), $expected_rows[2]);
    is($csv->readLine(), undef);
    is_deeply($params[0], [[qw(a b c)], [qw(a b c)], 1]);
    is_deeply($params[1], [[qw(a b c)], [qw(1 2 3)]]);
    is_deeply($params[2], [[qw(a b c)], [qw(4 5 6)]]);
}

sub test_creating_csv_with_string_opens_an_io_handler_for_read_write : Tests
{
    my $str = "test";
    my $csv = CSV->new($str);
    $csv->readLines();
    $csv->close();
    is(ref($open_params[0]), 'GLOB');
    is($open_params[1], '+<');
    is($open_params[2], \$str);
}

sub test_close_closes_the_io_handler : Tests
{
    my $csv = CSV->new("test");
    $csv->readLines();
    $csv->close();
    is(ref($close_params[0]), 'GLOB');
    is($open_params[0], $close_params[0]);

    open(my $fh, '<', 't/fixtures/test_csv.txt');
    $csv = CSV->new($fh);
    $csv->readLines();
    $csv->close();
    is($close_params[0], $fh);
}

sub test_addRows_writes_into_string : Test
{
    my $str = '';
    my $csv = CSV->new($str);
    $csv->addRow([1, 2, 3]);
    $csv->addRow(CSV::Row->new([qw(my test headers)], [4,5,6]));
    $csv->addRow(CSV::Row->new([qw(my test headers)], [4,5,6], 1));
    is($str, "1,2,3\n4,5,6\nmy,test,headers\n")
}

sub test_addRows_writes_into_file : Tests
{
    my $exists = -e 't/fixtures/gen_test_csv.txt';
    ok(!$exists);

    open(my $fh, '>', 't/fixtures/gen_test_csv.txt');
    my $csv = CSV->new($fh);
    $csv->addRow([1, 2, 3]);
    $csv->addRow(CSV::Row->new([qw(my test headers)], [4,5,6]));
    $csv->addRow(CSV::Row->new([qw(my test headers)], [4,5,6], 1));
    close($fh);

    open($fh, '<', 't/fixtures/gen_test_csv.txt');
    local $/ = undef;
    my $data = <$fh>;
    is($data, "1,2,3\n4,5,6\nmy,test,headers\n");
}

sub test_addRows_relies_in_CSV_Row_for_serialization : Tests
{
    my $str = '';
    my $csv = CSV->new($str);
    my @new_params;
    my $row1 = [1, 2, 3];
    my $row2 = CSV::Row->new();

    my $csv_mock = Test::MockObject->new()
        ->mock('toCSV', sub { "my,test,line\n" });
    my $row_mod = Test::MockModule->new('CSV::Row');
    $row_mod->mock('new', sub { push(@new_params, @_); return $csv_mock; });
    $row_mod->mock('toCSV', sub { 'my,second,line' });

    $csv->addRow($row1);
    $csv->addRow($row2);

    is($str, "my,test,line\nmy,second,line");
    is($new_params[1], $row1);
    is($new_params[2], $row1);
    is($new_params[3], 0);
}

sub test_open_opens_a_file_in_write_mode_passed_csv_instance_to_the_sub_and_closes : Tests
{
    my $options = {};
    my @steps;
    my @params;

    my $csv_mod = Test::MockModule->new('CSV');
    my $csv_mock = Test::MockObject->new()
        ->mock('close', sub { push(@steps, 'closed') });
    $csv_mod->mock('new', sub { shift; push(@params, @_); return $csv_mock; });

    CSV->open('t/fixtures/gen_test_csv.txt', $options, sub {
        push(@steps, shift);
    });

    is(ref $open_params[0], 'GLOB');
    is($open_params[1], '>');
    is($open_params[2], 't/fixtures/gen_test_csv.txt');

    is($params[0], $open_params[0]);
    is($params[1], $options);
    is($steps[0], $csv_mock);
    is($steps[1], 'closed');

    (@params, @steps) = ();
    clear_params();

    CSV->open('t/fixtures/gen_test_csv.txt', undef, sub {
        push(@steps, shift);
    });

    is(ref $open_params[0], 'GLOB');
    is($open_params[1], '>');
    is($open_params[2], 't/fixtures/gen_test_csv.txt');

    is($params[0], $open_params[0]);
    is($params[1], undef);
    is($steps[0], $csv_mock);
    is($steps[1], 'closed');
}

sub test_open_opens_a_file_in_write_mode_and_returns_csv_instance_if_no_sub : Tests
{
    my $options = {};
    my (@params, $closed);

    my $csv_mod = Test::MockModule->new('CSV');
    my $csv_mock = Test::MockObject->new()
        ->mock('close', sub { $closed = 1 });
    $csv_mod->mock('new', sub { shift; push(@params, @_); return $csv_mock; });

    my $csv = CSV->open('t/fixtures/gen_test_csv.txt', $options);

    is(ref $open_params[0], 'GLOB');
    is($open_params[1], '>');
    is($open_params[2], 't/fixtures/gen_test_csv.txt');

    is($params[0], $open_params[0]);
    is($params[1], $options);
    ok(!$closed);
    is($csv, $csv_mock);

    @params = ();
    $closed = 0;
    clear_params();

    $csv = CSV->open('t/fixtures/gen_test_csv.txt');

    is(ref $open_params[0], 'GLOB');
    is($open_params[1], '>');
    is($open_params[2], 't/fixtures/gen_test_csv.txt');

    is($params[0], $open_params[0]);
    is($params[1], undef);
    ok(!$closed);
    is($csv, $csv_mock);
}

sub test_generate_generates_a_csv_string : Tests
{
    my $str = CSV->generate(undef, sub {
        my $csv = shift;
        $csv->addRow([1,2,3]);
        $csv->addRow([qw(a b c)]);
    });
    is($str, "1,2,3\na,b,c\n");
}

sub test_generate_appends_a_csv_to_an_existing_string : Tests
{
    my $str = "Previous Content\n";
    CSV->generate($str, undef, sub {
        my $csv = shift;
        $csv->addRow([1,2,3]);
        $csv->addRow([qw(a b c)]);
    });
    is($str, "Previous Content\n1,2,3\na,b,c\n");
}

sub test_generateLine_is_a_shortcut_to_generate_a_single_row : Tests
{
    my $str = CSV->generateLine([qw(x y z)]);
    is($str, "x,y,z\n");
}

sub test_generate_generates_a_csv_string_with_headers : Tests
{
    my $str = "Previous Content\n";
    CSV->generate($str, { headers => ['x,', 'y', 'z'], write_headers => 1 }, sub {
        my $csv = shift;
        $csv->addRow([1,2,3]);
        $csv->addRow([qw(a b c)]);
    });
    is($str, "Previous Content\n\"x,\",y,z\n1,2,3\na,b,c\n");

    $str = CSV->generate({ headers => [qw(x y z)], write_headers => 1 }, sub {
        my $csv = shift;
        $csv->addRow([1,2,3]);
        $csv->addRow([qw(a b c)]);
    });
    is($str, "x,y,z\n1,2,3\na,b,c\n");

    $str = CSV->generateLine([8,9,0], { headers => [qw(a b c)], write_headers => 1 });
    is($str, "a,b,c\n8,9,0\n");
}

sub test_open_writes_a_csv_file_with_headers : Tests
{
    open(my $fh, '>', 't/fixtures/gen_test_csv.txt');
    print $fh "Previous content\n";
    close($fh);

    CSV->open('t/fixtures/gen_test_csv.txt', { headers => [qw(x y z)], write_headers => 1 }, sub {
        my $csv = shift;
        $csv->addRow([1,2,3]);
        $csv->addRow([qw(a b c)]);
    });

    open($fh, '<', 't/fixtures/gen_test_csv.txt');
    local $/ = undef;
    my $str = <$fh>;
    is($str, "x,y,z\n1,2,3\na,b,c\n");
}

sub test_open_appends_to_a_csv_file : Tests
{
    open(my $fh, '>', 't/fixtures/gen_test_csv.txt');
    print $fh "Previous content\n";
    close($fh);

    CSV->open('t/fixtures/gen_test_csv.txt', '>>', {}, sub {
        my $csv = shift;
        $csv->addRow([1,2,3]);
    });

    open($fh, '<', 't/fixtures/gen_test_csv.txt');
    local $/ = undef;
    my $str = <$fh>;
    is($str, "Previous content\n1,2,3\n");

    my $csv = CSV->open('t/fixtures/gen_test_csv.txt', '>>');
    $csv->addRow([qw(a b c)]);
    $csv->close();

    open($fh, '<', 't/fixtures/gen_test_csv.txt');
    $str = <$fh>;
    is($str, "Previous content\n1,2,3\na,b,c\n");
}

Test::Class->runtests();
