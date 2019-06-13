package CSV;

# This class allows parsing CSV strings of files.

use strict;
use warnings;

use CSV::Table;
use CSV::Row;

our $VERSION = '0.001';

sub DESTROY
{
    my $self = shift;
    close($self->{_io}) if $self->{_io} && $self->{_owned};
}

# PRE-DECLARATIONS

sub _open
{
    my $options = shift // {};
    my $encoding = $options->{encoding} ? ":encoding($options->{encoding})" : '';
    open(my $fh, "$_[0]$encoding", $_[1]) // die("Could not open: $_[1]");
    return $fh;
}

# CLASS METHODS

# Creates a new CSV instance.
# @params
#   @data     A string or file handler to use for CSV parsing. The file handler should be already
#             opened for writing or reading depending and the expected CSV functionality.
#   @options  A hashref with CSV options
#     {
#       headers => If a scalar is provided then: if the scalar value is truthy it will use the
#                  first row as a header and will generate rows as CSV::Row instances, while
#                  a falsey value will generate rows as arrayrefs.
#                  If an arrayref is provided it will be used as the headers for the generated
#                  CSV::Row row instances keeping the first row as non-header.
#       return_headers => This option only has effect when headers is a truthy scalar value.
#                         If truthy it will return the headers rows (first row) when parsing.
#                         A falsey value will skip this rows. Default value is falsey.
#       write_headers => If thruthy and headers is a hashref it will write the headers into the
#                        CSV file or string before the first CSV line. Default value is falsey.
#       skip_blanks => If truthy the parser will skip CSV blank lines. Note the parser will
#                      still parse rows with all fields blank e.g. ,,,
#     }
# @returns
#   The CSV instance.
sub new
{
    my $class = shift;
    my $data = ref($_[0]) ? $_[0] : \$_[0]; shift;
    my $options = shift // {};
    if (ref($data) ne 'SCALAR' && ref($data) ne 'GLOB') {
        die('Data should be a scalar reference or a file handle'.ref($data));
    }
    my $self = bless { data => $data, options => $options }, $class;
    $self->{_custom_headers} = ref($options->{headers});
    $self->rewind();
    return $self;
}

sub filter
{
    my $class = shift;
    my ($input, $output, $options, $sub) = @_;
    ($input, $output, $options, $sub) = (undef, undef, $input, $output) if ref($output) eq 'CODE';
    ($input, $output, $options, $sub) = ($input, undef, $output, $options) if ref($options) eq 'CODE';
    $input //= *ARGV;
    $output //= *STDOUT;

    my ($in_options, $out_options) = _split_options($options);
    my $in_csv = CSV->new($input, $in_options);
    my $out_csv = CSV->new($output, $out_options);
    $in_csv->each(sub { $out_csv->addRow($sub->(shift)) });
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

# Parse only the first row of the provided CSV string. See readLine.
# @params
#   @str      The CSV string to be parsed.
#   @options  A hashref with CSV options. See new for an options reference.
# @returns
#   Either an arrayref representing the CSV line or a CSV::Row instance depending on the headers
#   option value.
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
#   @options  A hashref with CSV options. See new for an options reference. Additionally the
#             options can support an encoding option where you can specify the input encoding
#             using any of the available perl encoding strings.
#   @sub      The CSV file rows will be parsed one by one and sent to the function as parameter.
sub foreach
{
    my $class = shift;
    my $filename = shift;
    my $options = shift;
    my $sub = shift;

    my $fh = _open($options, '<', $filename);
    my $csv = $class->new($fh, $options);
    $csv->each($sub);
    $csv->close();
}

# Reads all lines from a CSV file and returns the results. See readLines.
# @params
#   @filename The path to the CSV file to be parsed.
#   @options  A hashref with CSV options. See new for an options reference. Additionally the
#             options can support an encoding option where you can specify the input encoding
#             using any of the available perl encoding strings.
# @returns
#   Returns either a hashref of hashrefs or a CSV::Table instance depending on the headers
#   option value.
sub read
{
    my $class = shift;
    my $filename = shift;
    my $options = shift;

    my $fh = _open($options, '<', $filename);
    my $csv = $class->new($fh, $options);
    my $lines = $csv->readLines();
    $csv->close();
    return $lines;
}

# Opens a file for CSV writing.
# @variations
#   open(@filename, @options, @sub)
#   open(@filename, @mode, @options, @sub)
#   open(@filename, @options)
#   open(@filename, @mode, @options)
# @params
#   @filename The path to the file to write the CSV into
#   @mode     The mode used to open the file. By default the mode is '>' but you can use any of
#             the modes supported by the open function. For example to append use '>>'.
#   @options  A hashref with CSV options. See new for an options reference. Additionally the
#             options can support an encoding option where you can specify the input encoding
#             using any of the available perl encoding strings.
#   @sub      A block of code used to write the CSV file. The block will receive a CSV instance
#             as parameter. You can use the CSV::addRow method to add rows to the instance. If a
#             block is not provided then the CSV instance is returned and will not be closed.
# @returns
#   undef if the @sub parameter is provided or the unclosed CSV instance.
sub open
{
    my $class = shift;
    my $has_mode = $_[1] && !ref($_[1]);
    splice(@_, 1, 0, '>') if !$has_mode;
    my ($filename, $mode, $options, $sub) = @_;

    my $fh = _open($options, $mode, $filename);
    my $csv = $class->new($fh, $options);
    return $csv if !ref($sub);
    $sub->($csv);
    $csv->close();
}

# Generates or appends to a string the CSV generated in the given code block.
# @variations
#   generate(@str, @options, @sub)
#   generate(@options, @sub)
# @params
#   @str      An string into which to append the CSVi results.
#   @options  A hashref with CSV options. See new for an options reference. Additionally the
#             options can support an encoding option where you can specify the input encoding
#             using any of the available perl encoding strings. This option will only be used
#             for the returned string when @str parameter is not sent to the method.
#   @sub      A block of code used to write the CSV file. The block will receive a CSV instance
#             as parameter. You can use the CSV::addRow method to add rows to the instance.
# @returns
#   If the @str parameter is not sent then it returns the generated CSV as a string.
sub generate
{
    my $class = shift;
    my $has_str = ref($_[2]) eq 'CODE';
    my ($str, $options, $sub, $csv) = ('');
    if ($has_str) {
        (undef, $options, $sub) = @_;
        $csv = $class->new($_[0], $options);
    }
    else {
        ($options, $sub) = @_;
        $csv = $class->new(_open($options, '>>', \$str), $options);
    }
    $sub->($csv);
    $csv->close();
    return $str if !$has_str;
}

# This is a shortcut to using the generate method and adding a single CSV row.
# @variations
#   generate(@str, @options, @sub)
#   generate(@options, @sub)
# @params
#   @row      An arrayref with the row values or an instance of CSV::Row.
#   @options  A hashref with CSV options. See new for an options reference. Additionally the
#             options can support an encoding option where you can specify the input encoding
#             using any of the available perl encoding strings.
# @returns
#   The generated CSV row as a string.
sub generateLine
{
    my $class = shift;
    my $row = shift;
    my $options = shift;
    return $class->generate($options, sub { shift->addRow($row) });
}

# INSTANCE METHODS

# Main way of writing rows to the CSV file or string.
# @params
#   @row A hashref with the CSV row values or an instance of CSV::Row.
sub addRow
{
    my $self = shift;
    $self->_addRow($self->headers, 1) if ref($self->headers) && $self->writeHeaders && !$self->{_header_added};
    $self->_addRow($_[0]);
}

# Returns the return_headers option.
sub returnHeaders
{
    my $self = shift;
    return $self->{options}->{return_headers};
}

# Returns truthy if the next row read will be a header row.
sub isHeaderRow
{
    my $self = shift;
    return $self->headers && !ref($self->headers) && $self->returnHeaders;
}

# Returns the write_headers option.
sub writeHeaders
{
    my $self = shift;
    return $self->{options}->{write_headers};
}

# Returns the encoding option.
sub encoding
{
    my $self = shift;
    return $self->{options}->{encoding};
}

# Returns the last non-skipped read CSV line as a string.
sub line
{
    my $self = shift;
    return $self->{line};
}

# Returns the line number of the last non-skipped read CSV line.
sub lineno
{
    my $self = shift;
    return $self->{lineno};
}

# Rewinds the parsing to the start of the data. Does not make sense when writing.
sub rewind
{
    my $self = shift;
    $self->{lineno} = 0;
    $self->{_curlineno} = 0;
    $self->{options}->{headers} = 1 if ref($self->headers) && !$self->{_custom_headers};
    delete $self->{line};
    seek($self->{_io}, 0, 0) if $self->{_io};
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

    while ($read_line = readline($self->_io)) {
        $line .= $read_line;
        last if !$self->_hasOddQuotes($line);
    }
    return undef if !defined($read_line);

    my $row = $self->_generateLine($line);
    goto &readLine if !$row;

    $self->{lineno} = $self->{_curlineno};
    $self->{line} = $line;
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

    return $self->headers ? CSV::Table->new(\@lines) : \@lines;
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
    return $self->{options}->{headers};
}

# Returns the value of the skip_blanks option.
sub skipBlanks
{
    my $self = shift;
    return $self->{options}->{skip_blanks};
}

# Closes the handler used to read or write the CSV.
sub close
{
    my $self = shift;
    close($self->{_io}) if $self->{_io};
}

# PRIVATE METHODS

# Helper to get the IO handler
sub _io
{
    my $self = shift;
    my $append = shift // 0;
    if (!defined($self->{_io})) {
        if (ref($self->{data}) eq 'GLOB') {
            $self->{_io} = $self->{data};
        }
        else {
            $self->{_io} = _open(undef, ($append ? '+>>' : '+<'), $self->{data});
            $self->{_owned} = 1;
        }
    }
    return $self->{_io};
}

sub _addRow
{
    my $self = shift;
    my $row = shift;
    my $header = shift // 0;
    $row = CSV::Row->new($row, $row, $header) if ref($row) ne 'CSV::Row';
    $self->{_header_added} = 1 if $header;
    my $io = $self->_io(1);
    print $io $row->toCSV();
}

sub _generateLine
{
    my $self = shift;
    my $line = shift;
    chomp($line);

    my @cols = $self->_compactColumns(split(',', $line, -1));
    $self->{_curlineno}++;

    return undef if $self->skipBlanks && scalar(@cols) == 0;
    return $self->headers ? $self->_getCSVRow(@cols) : \@cols;
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
    return CSV::Row->new($self->headers, $fields) if ref($self->headers);

    # first row conditionals
    $self->{options}->{headers} = $fields;
    return $self->returnHeaders ? CSV::Row->new($fields, $fields, 1) : undef;
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

sub _split_options
{
    my $options = shift // {};

    my ($in_options, $out_options) = ({}, {});
    for my $key (keys %$options) {
        my $new_key;
        if (($new_key = $key) =~ s/^out_//) {
            $out_options->{$new_key} = $options->{$key};
        }
        elsif (($new_key = $key) =~ s/^in_//) {
            $in_options->{$new_key} = $options->{$key};
        }
        else {
            $in_options->{$key} = $out_options->{$key} = $options->{$key};
        }
    }

    return $in_options, $out_options;
}

return 1;
