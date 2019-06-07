package CSV::Table;

# This class represents a complete CSV string.
# The class automatically stringifies to a CSV string representation of the table when in
# string context, it can be dereferenced as a list to access its rows positionally, and
# and can be compared for equality with other CSV::Tables.

use strict;
use warnings;

use CSV::Row;

use overload
    fallback => 1,
    '""' => sub { $_[0]->toCSV() },
    '@{}' => sub { $_[0]->{'_rows'} },
    '<=>' => sub { !$_[0]->eq($_[1]) };

# Creates a new CSV table instance.
# @params
#   @rows An arrayref of CSV::Row instances for the table.
sub new
{
    my $class = shift;
    my $rows = shift // [];
    return bless { '_rows' => $rows }, $class;
}

# Returns the CSV headers as an arrayref.
sub headers
{
    my $self = shift;
    return $self->{'_rows'}->[0]? $self->{'_rows'}->[0]->headers() : [];
}

# Iterated over the table rows.
# @params
#   @sub      The CSV file rows will be sent one by one to the function as parameter.
sub each
{
    my $self = shift;
    my $sub = shift;

    for my $row (@{ $self->{'_rows'} }) {
        $sub->($row);
    }
}

# Returns the arrayref of CSV::Row instances.
sub rows
{
    my $self = shift;
    return $self->{'_rows'};
}

sub _getRows
{
    my $self = shift;
    my $writeHeaders = shift // 1;
    return $writeHeaders ?
        @{ $self->{'_rows'} } :
        grep { $_->isFieldRow() } @{ $self->{'_rows'} };
}

# Converts the CSV table to an arrayref of arrayrefs.
sub toArrayRef
{
    my $self = shift;
    my $writeHeaders = shift;
    my @rows = $self->_getRows($writeHeaders);
    return [ map { $_->fields() } @rows ];
}

# Serializes the CSV table to a valid CSV string
sub toCSV
{
    my $self = shift;
    my $writeHeaders = shift;
    my @rows = map { $_->toCSV() } $self->_getRows($writeHeaders);
    return join('', @rows);
}

# Allows comparing CSV tables for equality.
sub eq
{
    my $self = shift;
    my $table = shift;
    my @rows = @{ $self->{'_rows'} };
    my @other_rows = @{ $table->{'_rows'} };
    return 0 if scalar(@rows) != scalar(@other_rows);

    $_->eq(shift(@other_rows)) || return 0 for @rows;
    return 1;
}

return 1;
