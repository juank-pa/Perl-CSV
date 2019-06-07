package CSV;

# This class allows parsing CSV strings of files.

use strict;
use warnings;

use CSV::Table;
use CSV::Row;

our $VERSION = '0.001';

# CLASS METHODS

# Creates a new CSV instance.
# @params
#   @data     A string or file handler to use for CSV parsing
#   @options  A hashref with CSV options
#     {
#       headers => If a scalar is provided then: if the scalar value is truthy it will use the
#                  first row as a header and will generate rows as CSV::Row instances, while
#                  a falsey value will generate rows as arrayrefs.
#                  If an arrayref is provided it will be used as the headers for the generated
#                  CSV::Row row instances keeping the first row as non-header.
#       return_headers => This option only has effect when headers is a truthy value scalar.
#                         If truthy it will return the headers rows (first row) when parsing.
#                         A falsey value will skip this rows. Default value is falsey.
#       skip_blanks => If truthy the parser will skip CSV blank lines. Note the parser will
#                      still parse rows with all fields blank e.g. ,,,
#     }
sub new
{
    my $class = shift;
    my $data = shift;
    my $options = shift // {};
    if (ref($data) && ref($data) ne 'GLOB') {
        die('Data should be a scalar reference or a file handle'.ref($data));
    }
    my $self = bless { 'data' => $data, 'options' => $options }, $class;
    $self->rewind();
    return $self;
}

# Main method of parsing a CSV string.
# @params
#   @str      The CSV string to be parsed.
#   @options  A hashref with CSV options. See new for an options reference.
#   @sub      An optional function. If no function is passed then the method parses all CSV rows
#             and returns the results (see readLines). If a function is passed then the CSV rows
#             will be parsed one by one and sent to the function as parameter.
sub parse
{
    my $class = shift;
    my $str = shift;
    my $options = shift;
    my $sub = shift;

    my $csv = $class->new($str, $options);
    return $csv->readLines() if !defined($sub);
    $csv->each($sub);
}

# Parse one the first row of the provided CSV string. The result depends on the headers
# options. See readLine.
# @params
#   @str      The CSV string to be parsed.
#   @options  A hashref with CSV options. See new for an options reference.
sub parseLine
{
    my $class = shift;
    my $str = shift;
    my $options = shift;

    my $csv = $class->new($str, $options);
    return $csv->readLine();
}

# Main method of parsing a CSV file. The method opens the file before parsing
# and closes it down when finished, so there is no need to worry about that.
# @params
#   @filename The path to the CSV file to be parsed.
#   @options  A hashref with CSV options. See new for an options reference.
#   @sub      The CSV file rows will be parsed one by one and sent to the function as parameter.
sub foreach
{
    my $class = shift;
    my $filename = shift;
    my $options = shift;
    my $sub = shift;

    open(my $fh, '<', $filename) // die("Could not open file: $filename");
    my $csv = $class->new($fh, $options);
    $csv->each($sub);
    close($fh);
}

# Reads all files from a CSV file and returns the results. The results depend on the
# headers option. See readLines.
# @params
#   @filename The path to the CSV file to be parsed.
#   @options  A hashref with CSV options. See new for an options reference.
sub read
{
    my $class = shift;
    my $filename = shift;
    my $options = shift;

    open(my $fh, '<', $filename) // die("Could not open file: $filename");
    my $csv = $class->new($fh, $options);
    my $lines = $csv->readLines();
    close($fh);
    return $lines;
}

# INSTANCE METHODS

# Returns the return_headers option
sub returnHeaders
{
    my $self = shift;
    return $self->{'options'}->{'return_headers'};
}

# Returns the last non-skipped read CSV line.
sub line
{
    my $self = shift;
    return $self->{'line'};
}

# Returns the line number of the last non-skipped read CSV line.
sub lineno
{
    my $self = shift;
    return $self->{'lineno'};
}

# Rewinds the parsing to the start of the data
sub rewind
{
    my $self = shift;
    $self->{'lineno'} = 0;
    $self->{'_curlineno'} = 0;
    delete $self->{'headers'};
    delete $self->{'line'};
    seek($self->{'_input'}, 0, 0) if $self->{'_input'};
}

# Reads a single line CSV line and returns it. The value returned depends on the
# headers option value. If header was a falsey scalar it returns a CSV row as an arrayref.
# e.g. ['a','b','c']. Otherwise if a truthy scalar or arrayref is sent it returns instances
# of CSV::Row class. This class allows querying the row data by header key instead of by index.
sub readLine
{
    my $self = $_[0];
    my ($line, $read_line) = ('');
    local $/ = "\n";

    while ($read_line = readline($self->_input())) {
        $line .= $read_line;
        last if !$self->_hasOddQuotes($line);
    }
    return undef if !defined($read_line);

    my $row = $self->_generateLine($line);
    goto &readLine if !$row;

    $self->{'lineno'} = $self->{'_curlineno'};
    $self->{'line'} = $line;
    return $row;
}

# Read all lines in the CSV and returns them. The value returned depends on the
# headers option value. If header was a falsey scalar it returns an arrayref or arrayrefs.
# e.g. [['a','b','c'],['1','2','3']]. Otherwise if a truthy scalar or arrayref is sent it returns
# an instance of CSV::Table that contains instances of CSV::Row for each row.
sub readLines
{
    my $self = shift;
    my @lines;

    $self->each(sub {
        my $line = shift;
        push(@lines, $line);
    });

    return $self->{'options'}->{'headers'} ? CSV::Table->new(\@lines) : \@lines;
}

# Read all lines in the CSV and passes them one by one to the function. The type of the
# row depends on the headers option value. See readLine.
# @params
#   @sub A function to be called for each row. The row is passed as parameter.
sub each
{
    my $self = shift;
    my $sub = shift;

    while (defined(my $line = $self->readLine())) {
        $sub->($line);
    }
}

# Returns the headers parsed from the CSV file. If the headers option is falsey or the CSV
# instance has not read at least one line this getter returns undef. The header is returned
# as a hashref.
sub headers
{
    my $self = shift;
    return $self->{'options'}->{'headers'};
}

# Returns the value used as the skip_blanks option.
sub skipBlanks
{
    my $self = shift;
    return $self->{'options'}->{'skip_blanks'};
}

# PRIVATE METHODS
sub _input
{
    my $self = shift;
    if (!defined($self->{'_input'})) {
        if (ref($self->{'data'})) {
            $self->{'_input'} = $self->{'data'};
        }
        else {
            open($self->{'_input'}, '<', \$self->{'data'});
        }
    }
    return $self->{'_input'};
}

sub _generateLine
{
    my $self = shift;
    my $line = shift;
    chomp($line);

    my @cols = $self->_compactColumns(split(',', $line, -1));
    $self->{'_curlineno'}++;

    return undef if $self->skipBlanks() && scalar(@cols) == 0;
    return $self->headers() ? $self->_getCSVRow(@cols) : \@cols;
}

sub _compactColumns
{
    my $self = shift;
    my @cols = @_;
    my @compacted_cols;
    my $col_acc = '';

    for my $col (@cols) {
        # Accumulate until quotes are even
        $col_acc .= $col_acc ? ",$col" : $col;
        next if $self->_hasOddQuotes($col_acc);

        push(@compacted_cols, $self->_sanitizeColumn($col_acc));
        $col_acc = '';
    }

    return @compacted_cols;
}

sub _getCSVRow
{
    my $self = shift;
    my $fields = \@_;
    # headers has been set return normal row
    return CSV::Row->new($self->headers(), $fields) if ref($self->headers());

    # first row conditionals
    $self->{'options'}->{'headers'} = $fields;
    return $self->returnHeaders() ? CSV::Row->new($fields, $fields, 1) : undef;
}

sub _hasOddQuotes
{
    my $self = shift;
    my $str = shift;
    return ($str =~ tr/"/"/) % 2 != 0;
}

# Remove field wrapping quotes and unescape internal quotes
sub _sanitizeColumn
{
    my $self = shift;
    my $col = shift;
    $col =~ s/^"|"$//g;
    $col =~ s/""/"/g;
    return $col;
}

return 1;
