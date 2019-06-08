# Perl-CSV [![Build Status](https://travis-ci.org/juank-pa/Perl-CSV.svg?branch=master)](https://travis-ci.org/juank-pa/Perl-CSV)
This is a simple CSV parser library that doesn't have dependencies underneath. It provides
interface to CSV files and data. It offers tools to enable you to read and write to and from
Strings or IO handlers, as needed.

The most generic interface of the library is:

```perl
my $csv = CSV->new(string_or_io, $options);

# Reading: IO handler should be open for read
my $rows = $csv->readLines(); # => arrayref of arrayrefs
# or
$csv->each({
  my $row = shift;
  # ...
});
# or
my $row = $csv->readLine();

# Writing: IO handler should be open for write
$csv->addRow($row);
```

There are several specialized class methods for one-statement reading or writing, described in the
Specialized Methods section.

If a String is passed into `CSV::new`, it is internally opened as an IO handler.

# Specialized Methods
## Reading
```perl
# From a file: all at once
my $arr_of_rows = CSV->read("path/to/file.csv", $options);
# iterator-style:
CSV->foreach("path/to/file.csv", $options, sub {
  my $row = shift;
  # ...
});

# From a string
my $arr_of_rows = CSV->parse("CSV,data,String", $options);
# or
CSV->parse("CSV,data,String", $options, sub {
  my $row = shift;
  # ...
});
```
## Writing
```perl
# To a file
CSV->open("path/to/file.csv", ">", $options, sub {
  my $csv = shift;
  $csv->addRow(["row", "of", "CSV", "data"]);
  $csv->addRow(["another", "row"]);
  # ...
});

# To a string
my $csv_string = CSV->generate($options, sub {
  my $csv = shift;
  $csv->addRow(["row", "of", "CSV", "data"]);
  $csv->addRow(["another", "row"]);
  # ...
});
```
# Data Headers
CSV allows to specify column names of CSV file, whether they are in data, or provided separately.
If headers specified, reading methods return an instance of `CSV::Table`, consisting of `CSV::Row`.
```perl
# Headers are part of data
my $data = CSV->parse(<<ROWS, { headers => 1 });
Name,Department,Salary
Bob,Engineering,1000
Jane,Sales,2000
John,Management,5000
ROWS

ref($data);              #=> CSV::Table
ref($data->[0]);         #=> CSV::Row
$data->[0]->toHashRef(); #=> { "Name"=>"Bob", "Department"=>"Engineering", "Salary"=>"1000" }

# Headers provided by developer
$data = CSV->parse('Bob,Engeneering,1000', { headers => [qw(name department salary)] });
$data->[0]->toHashRef(); #=> { "name" => "Bob", "department" => "Engineering", "salary" => "1000" }
```
