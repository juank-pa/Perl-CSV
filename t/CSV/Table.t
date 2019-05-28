package CSV::Table::Test;

use strict;

use lib '../httpd_modperl/lib/perl';

use parent qw(Test::Class);
use Test::More;
use Test::MockObject;
use Test::MockModule;
use Data::Dumper;

use CSV::Row;
use CSV::Table;

sub test_each_cycles_trough_all_rows_and_sends_them_to_sub : Tests
{
    my @rows = (CSV::Row->new(['a','b','c'],[]), CSV::Row->new(['x','y','z'],[]));
    my $table = CSV::Table->new(\@rows);
    $table->each(sub {
        my $row = shift;
        is($row, shift(@rows));
    });
}

sub test_rows_returns_the_rows : Tests
{
    my $rows = [CSV::Row->new(['a','b','c'],[]), CSV::Row->new(['x','y','z'],[])];
    my $table = CSV::Table->new($rows);
    is($table->rows()->[0], $rows->[0]);
    is($table->rows()->[1], $rows->[1]);
}

sub test_headers_returns_the_first_row_headers : Tests
{
    my $table = CSV::Table->new([CSV::Row->new(['a','b','c'],[]), CSV::Row->new(['x','y','z'],[])]);
    is_deeply($table->headers(), [qw(a b c)]);
}

sub test_toArrarRef_returns_a_list_of_rows_as_fields : Tests
{
    my @rows = ([qw(first row)],[qw(yet another row)]);
    my $row_mod = Test::MockModule->new('CSV::Row');
    $row_mod->mock('fields', sub { return shift(@rows) });
    my $table = CSV::Table->new(_get_rows());
    is_deeply($table->toArrayRef(), [[qw(first row)], [qw(yet another row)]]);
}

sub test_toArrayRef_returns_table_as_array_ref_when_no_headers : Tests
{
    my $table = CSV::Table->new(_get_rows());
    is_deeply($table->toArrayRef(),  [[1,2,3],[4,5,6]]);
    is_deeply($table->toArrayRef(1), [[1,2,3],[4,5,6]]);
    is_deeply($table->toArrayRef(0), [[1,2,3],[4,5,6]]);
}

sub test_toArrayRef_returns_table_as_array_ref_when_headers : Tests
{
    my $table = CSV::Table->new(_get_rows(1));
    is_deeply($table->toArrayRef(),  [[qw(a b c)],[1,2,3],[4,5,6]]);
    is_deeply($table->toArrayRef(1), [[qw(a b c)],[1,2,3],[4,5,6]]);
    is_deeply($table->toArrayRef(0), [[1,2,3],[4,5,6]]);
}

sub test_table_dereferences_to_array_as_row_list : Tests
{
    my $table = CSV::Table->new(_get_rows());
    isa_ok($table->[0], 'CSV::Row');
    is_deeply($table->[0]->fields(), [1,2,3]);
    is_deeply($table->[1]->fields(), [4,5,6]);
    is(scalar @{ $table }, 2);
}

sub test_toCSV_joins_csv_serialized_rows : Tests
{
    my @rows = ('first,row','yet,another,row');
    my $row_mod = Test::MockModule->new('CSV::Row');
    $row_mod->mock('toCSV', sub { return shift(@rows)."\n" });
    my $table = CSV::Table->new(_get_rows());
    is($table->toCSV(), "first,row\nyet,another,row\n");
}

sub test_toCSV_returns_table_as_csv_string_when_no_headers : Tests
{
    my $table = CSV::Table->new(_get_rows());
    is($table->toCSV(), qq(1,2,3\n4,5,6\n));
    is($table->toCSV(1), qq(1,2,3\n4,5,6\n));
    is($table->toCSV(0), qq(1,2,3\n4,5,6\n));
}

sub test_toCSV_returns_table_as_csv_string_when_headers : Tests
{
    my $table = CSV::Table->new(_get_rows(1));
    is($table->toCSV(), qq(a,b,c\n1,2,3\n4,5,6\n));
    is($table->toCSV(1), qq(a,b,c\n1,2,3\n4,5,6\n));
    is($table->toCSV(0), qq(1,2,3\n4,5,6\n));
}

sub test_table_stringifies_to_csv : Tests
{
    my $table = CSV::Table->new(_get_rows());
    is($table, qq(1,2,3\n4,5,6\n));
}

sub test_table_equality : Tests
{
    my $table1 = CSV::Table->new(_get_rows());
    my $table2 = CSV::Table->new(_get_rows());
    ok($table1 == $table2);

    pop(@{ $table2->{'_rows'} });
    ok($table1 != $table2);

    $table2 = CSV::Table->new(_get_rows());
    $table2->[0]->{'_hashref'}->{'b'} = 'z';
    ok($table1 != $table2);

    $table2 = CSV::Table->new(_get_rows(1));
    ok($table1 != $table2);
}

sub _get_rows
{
    my $with_header_row = shift;
    my @headers = ('a', 'b', 'c');
    my @fields = (['a','b','c'],[1,2,3], [4,5,6]);
    my @rows;
    my $first_time = 1;
    for my $field (@fields) {
        push(@rows, CSV::Row->new(\@headers, $field, $first_time)) if !$first_time || $with_header_row;
        $first_time = 0;
    }
    return \@rows;
}

Test::Class->runtests();
