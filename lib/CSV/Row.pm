package CSV::Row;

# This class represents a single CSV line.
# The class automatically stringifies to a CSV row string representation of the row when in
# string context, it can be dereferenced as a list to access its fields positionally, and
# and can be compared for equality with other CSV::Rows.

use strict;
use warnings;

use overload
    fallback => 1,
    '""' => sub { $_[0]->toCSV() },
    '@{}' => sub { $_[0]->fields() },
    '<=>' => sub { !$_[0]->eq($_[1]) };

# Creates a new CSV row instance.
# @params
#   @headers An arrayref of headers for the row.
#   @fields  An arrayref of field values for the headers. If there are more fields than headers,
#            they will be ignored. If there are fewer fields than headers, remaining headers will
#            be initialized as undef.
#   @header_row Whether this is a header row 1 or normal fields row 0.
sub new
{
    my $class = shift;
    my $headers = shift // [];
    my $fields = shift // [];
    my $header_row = shift // '';
    my $self = { '_hashref' => {}, '_headers' => $headers, '_header_row' => $header_row };

    for my $i (0..$#$headers) {
        $self->{'_hashref'}->{$headers->[$i]} = $fields->[$i];
    }

    return bless $self, $class;
}

# Returns whether the row is a header 1 or not 0.
sub isHeaderRow
{
    my $self = shift;
    return $self->{'_header_row'};
}

# Returns whether the row is a normal field row 1 or not 0.
sub isFieldRow
{
    my $self = shift;
    return !$self->isHeaderRow();
}

# Returns the row headers.
sub headers
{
    my $self = shift;
    return $self->{'_headers'};
}

# Returns a field value given a header key.
# @params
#   @header the header key for which we want to get the value.
sub field
{
    my $self = shift;
    my $header = shift;
    return $self->{'_hashref'}->{$header};
}

# Returns whether the row has a header key or not.
sub hasHeader
{
    my $self = shift;
    my $header = shift;
    return exists($self->{'_hashref'}->{$header});
}

# Returns the row values in the original CSV row as a hashref.
sub fields
{
    my $self = shift;
    my %fields = %{ $self->toHashRef() };
    return [ @fields{@{ $self->headers() }} ];
}

# Returns the index of a given header key.
# @params
#   @header the header key for which we want to get the positional index.
sub index
{
    my $self = shift;
    my $header = shift;
    my $index = 0;
    ($_ eq $header ? return $index : $index++) for @{ $self->headers() };
    return -1;
}

# Returns the hashref representation of the row using the headers as keys.
sub toHashRef
{
    my $self = shift;
    return { %{ $self->{'_hashref'} } };
}

sub _escapeField
{
    my $self = shift;
    my $field = shift // '';
    if ($field =~ /,|"|\n/) {
        $field =~ s/"/""/g;
        $field = "\"$field\"";
    }
    return $field;
}

# Serializes the CSV row to a valid CSV row string
sub toCSV
{
    my $self = shift;
    my @escaped_fields = map { $self->_escapeField($_) } @{ $self->isHeaderRow() ? $self->headers() : $self->fields() };
    return join(',', @escaped_fields)."\n";
}

# Allows comparing rows for equality.
sub eq
{
    my $self = shift;
    my $row = shift;

    return 0 if $self->isFieldRow() != $row->isFieldRow();
    return 0 if scalar @{ $self->headers() } != scalar @{ $row->headers() };
    for my $header (@{ $self->headers() }) {
        return 0 if "$self->{'_hashref'}->{$header}" ne "$row->{'_hashref'}->{$header}";
    }
    return 1;
}

return 1;
