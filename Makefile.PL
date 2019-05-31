use ExtUtils::MakeMaker;

WriteMakefile(
  NAME => 'CSV',
  VERSION_FROM => 'lib/CSV.pm',
  test => { TESTS => 't/*.t t/*/*.t' },
  MIN_PERL_VERSION => '5.10.1',
  TEST_REQUIRES => {
    'Test::MockObject' => '0',
    'Test::MockModule' => '0',
    'Test::Class' => '0',
  },
);
