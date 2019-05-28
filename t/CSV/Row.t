package CSV::Row::Test;

use strict;

use lib '../httpd_modperl/lib/perl';

use parent qw(Test::Class);
use Test::More;
use Test::MockObject;
use Test::MockModule;
use Data::Dumper;

use CSV::Row;

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
}

sub test_isHeaderRow_reports_row_is_header : Tests
{
    ok(CSV::Row->new([], [], 1)->isHeaderRow());
    ok(!CSV::Row->new([], [], 0)->isHeaderRow());
    ok(!CSV::Row->new([], [])->isHeaderRow());
}

sub test_isFieldRow_reports_row_is_field : Tests
{
    ok(!CSV::Row->new([], [], 1)->isFieldRow());
    ok(CSV::Row->new([], [], 0)->isFieldRow());
    ok(CSV::Row->new([], [])->isFieldRow());
}

sub test_headers_returns_headers : Tests
{
    my $headers = [qw(a b c)];
    my $row = CSV::Row->new($headers, []);
    is_deeply($row->headers(), $headers);
}

sub test_hasHeader_returns_truthy_if_header_exists : Tests
{
    my $row = CSV::Row->new([qw(a b c)], []);
    ok($row->hasHeader('a'));
    ok($row->hasHeader('b'));
    ok($row->hasHeader('c'));
    ok(!$row->hasHeader('x'));
}


sub test_index_returns_the_header_positional_index : Tests
{
    my $row = CSV::Row->new([qw(a b c)], []);
    is($row->index('a'), 0);
    is($row->index('b'), 1);
    is($row->index('c'), 2);
    is($row->index('x'), -1);
}

sub test_fields_returns_fields_for_existing_headers : Tests
{
    my $fields = [1,45,8];
    my $row = CSV::Row->new([qw(a b c)], $fields);
    is_deeply($row->fields(), $fields);

    $row = CSV::Row->new([qw(a b)], $fields);
    is_deeply($row->fields(), [1, 45]);

    $row = CSV::Row->new([], $fields);
    is_deeply($row->fields(), []);
}

sub test_field_returns_field_value : Tests
{
    my $row = CSV::Row->new([qw(a b c)], [1, undef, 8]);
    is($row->field('a'), 1);
    is($row->field('b'), undef);
    is($row->field('c'), 8);
    is($row->field('x'), undef);
}

sub test_toHashRef_returns_the_row_as_hash_ref : Tests
{
    my $row = CSV::Row->new([qw(a b c)], [1, 45]);
    is_deeply($row->toHashRef, { a=> 1, b => 45, c => undef});
}

sub test_toCSV_returns_row_as_csv_string : Tests
{
    my $row = CSV::Row->new([qw(a b c)], [1, 45, 2]);
    is($row->toCSV(), "1,45,2\n");
}

sub test_toCSV_returns_row_as_csv_string_undef_values : Tests
{
    my $row = CSV::Row->new([qw(a b c)], [1, undef, 2]);
    is($row->toCSV(), "1,,2\n");
    $row = CSV::Row->new([qw(a b c)], [1]);
    is($row->toCSV(), "1,,\n");
}

sub test_toCSV_returns_row_as_csv_string_no_headers : Tests
{
    my $row = CSV::Row->new([], [1]);
    is($row->toCSV(), "\n");
}

sub test_toCSV_returns_row_as_csv_string_escape_quotes : Tests
{
    my $row = CSV::Row->new([qw(a b c)], [1, '4"5', 2]);
    is($row->toCSV(), qq(1,"4""5",2\n));
}

sub test_toCSV_returns_row_as_csv_string_escape_commas : Tests
{
    my $row = CSV::Row->new([qw(a b c)], [1, '4,5', 2]);
    is($row->toCSV(), qq(1,"4,5",2\n));
}

sub test_toCSV_returns_row_as_csv_string_escape_newlines : Tests
{
    my $row = CSV::Row->new([qw(a b c)], [1, "4\n5", 2]);
    is($row->toCSV(), qq(1,"4\n5",2\n));
}

sub test_toCSV_returns_row_as_csv_string_using_headers_for_header_type : Tests
{
    my $row = CSV::Row->new(['a', 'b"b', 'c'], [1, "4\n5", 2], 1);
    is($row->toCSV(), qq(a,"b""b",c\n));
}

sub test_row_stringifies_to_csv : Tests
{
    my $row = CSV::Row->new([qw(a b c)], [1, '4,5', 2]);
    is($row, qq(1,"4,5",2\n));
}

sub test_row_dereferences_as_array_as_a_field_list : Tests
{
    my $row = CSV::Row->new([qw(a b c)], [1, '4,5', 2]);
    is($row->[0], 1);
    is($row->[1], '4,5');
    is($row->[2], 2);
}

sub test_row_equality : Tests
{
    my $row1 = CSV::Row->new([qw(a b c)], [1, '4,5', 2]);
    my $row2 = CSV::Row->new([qw(a b c)], [1, '4,5', 2]);
    ok($row1 == $row2);

    $row2 = CSV::Row->new([qw(a b c)], [1, '4,5', 2], 1);
    ok($row1 != $row2);

    $row2 = CSV::Row->new([qw(a b c)], [1, '4,6', 2]);
    ok($row1 != $row2);

    $row2 = CSV::Row->new([qw(a b c e)], [1, '4,5', 2]);
    ok($row1 != $row2);

    # values falling outside of headers are ignored on construction
    $row2 = CSV::Row->new([qw(a b c)], [1, '4,5', 2, 6]);
    ok($row1 == $row2);
}

Test::Class->runtests();
