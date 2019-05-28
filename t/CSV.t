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

    is(@params[0], "a,b,c\n1,2,3");
    is(@params[1], $options);
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

    is(@params1[0], "a,b,c\n1,2,3");
    is(@params1[1], $options);
    is(@params2[0], $sub);
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

    is(@params[0], "a,b,c\n1,2,3");
    is(@params[1], $options);
    is($read_line, 1);
    is($res, $read_line_res);
}

sub test_foreach_is_a_shorcut_to_open_file_new_csv_object_each_and_close_file : Tests
{
    my $options = {};
    my $sub = sub {};
    my (@params1, @params2);

    my $csv_mod = Test::MockModule->new('CSV');
    my $csv_mock = Test::MockObject->new()
        ->mock('each', sub { shift; push(@params2, @_); });
    $csv_mod->mock('new', sub { shift; push(@params1, @_); return $csv_mock; });

    CSV->foreach('t/fixtures/test_csv.txt', $options, $sub);

    is(ref @open_params[0], 'GLOB');
    is(@open_params[0], @close_params[0]);
    is(@open_params[1], '<');
    is(@open_params[2], 't/fixtures/test_csv.txt');

    is(@params1[0], @open_params[0]);
    is(@params1[1], $options);
    is(@params2[0], $sub);
}

sub test_read_is_a_shorcut_to_open_file_new_csv_object_readLines_and_close_file : Tests
{
    my $options = {};
    my $readlines_res = ['result'];
    my @params1;

    my $csv_mod = Test::MockModule->new('CSV');
    my $csv_mock = Test::MockObject->new()
        ->mock('readLines', sub { return $readlines_res });
    $csv_mod->mock('new', sub { shift; push(@params1, @_); return $csv_mock; });

    my $res = CSV->read('t/fixtures/test_csv.txt', $options);

    is(ref @open_params[0], 'GLOB');
    is(@open_params[0], @close_params[0]);
    is(@open_params[1], '<');
    is(@open_params[2], 't/fixtures/test_csv.txt');

    is(@params1[0], @open_params[0]);
    is(@params1[1], $options);
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
    is($csv->headers(), undef);
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

sub test_readLine_with_custom_headers_sets_headers_on_first_read : Tests
{
    my $csv = CSV->new("a,b,c\n1,2,3\n4,5,6\n", { 'headers' => [qw(m mm mmm)] });
    is($csv->headers(), undef);
    $csv->readLine();
    is_deeply($csv->headers(), [qw(m mm mmm)]);
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

sub test_useHeaders_returns_the_headers_options : Tests
{
    my $csv = CSV->new("a,b,c\n1,2,3\n", { 'headers' => 'ANY VAL' });
    is($csv->useHeaders(), 'ANY VAL');
}

sub test_skipBlanks_returns_the_headers_options : Tests
{
    my $csv = CSV->new("a,b,c\n1,2,3\n", { 'skip_blanks' => 'BLANK VAL' });
    is($csv->skipBlanks(), 'BLANK VAL');
}

sub test_readLine_assemblesi_and_returns_rows_with_the_right_headers_and_fields : Tests
{
    my (@rows, @params);
    push(@rows, bless({}, 'Row')) for (1..2);
    my @expected_rows = @rows;

    my $row_mod = Test::MockModule->new('CSV::Row');
    $row_mod->mock('new', sub { shift; push(@params, [@_]);  return shift(@rows); });

    my $csv = CSV->new("a,b,c\n1,2,3\n4,5,6", { 'headers' => 1 });
    is($csv->readLine(), @expected_rows[0]);
    is($csv->readLine(), @expected_rows[1]);
    is($csv->readLine(), undef);
    is_deeply(@params[0], [[qw(a b c)], [qw(1 2 3)]]);
    is_deeply(@params[1], [[qw(a b c)], [qw(4 5 6)]]);
}

sub test_readLine_assemblesi_and_returns_rows_with_the_right_headers_and_fields_custom_headers : Tests
{
    my (@rows, @params);
    push(@rows, bless({}, 'Row')) for (1..3);
    my @expected_rows = @rows;

    my $row_mod = Test::MockModule->new('CSV::Row');
    $row_mod->mock('new', sub { shift; push(@params, [@_]);  return shift(@rows); });

    my $csv = CSV->new("a,b,c\n1,2,3\n4,5,6", { 'headers' => [qw(m n o)] });
    is($csv->readLine(), @expected_rows[0]);
    is($csv->readLine(), @expected_rows[1]);
    is($csv->readLine(), @expected_rows[2]);
    is($csv->readLine(), undef);
    is_deeply(@params[0], [[qw(m n o)], [qw(a b c)], '']);
    is_deeply(@params[1], [[qw(m n o)], [qw(1 2 3)]]);
    is_deeply(@params[2], [[qw(m n o)], [qw(4 5 6)]]);
}

sub test_readLine_assemblesi_and_returns_rows_with_the_right_headers_and_fields_return_headers : Tests
{
    my (@rows, @params);
    push(@rows, bless({}, 'Row')) for (1..3);
    my @expected_rows = @rows;

    my $row_mod = Test::MockModule->new('CSV::Row');
    $row_mod->mock('new', sub { shift; push(@params, [@_]);  return shift(@rows); });

    my $csv = CSV->new("a,b,c\n1,2,3\n4,5,6", { 'headers' => 1, 'return_headers' => 1 });
    is($csv->readLine(), @expected_rows[0]);
    is($csv->readLine(), @expected_rows[1]);
    is($csv->readLine(), @expected_rows[2]);
    is($csv->readLine(), undef);
    is_deeply(@params[0], [[qw(a b c)], [qw(a b c)], 1]);
    is_deeply(@params[1], [[qw(a b c)], [qw(1 2 3)]]);
    is_deeply(@params[2], [[qw(a b c)], [qw(4 5 6)]]);
}

Test::Class->runtests();
