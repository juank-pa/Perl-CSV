# Perl-CSV [![Build Status](https://travis-ci.org/juank-pa/Perl-CSV.svg?branch=master)](https://travis-ci.org/juank-pa/Perl-CSV)
This is a simple CSV parser library that doesn't have dependencies underneath. It provides interface to CSV files and data. It offers tools to enable you to read from Strings or IO handlers, as needed.

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
```

There are several specialized class methods for one-statement reading, described in the Specialized Methods section.

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
