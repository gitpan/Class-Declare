use 5.006;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME              => 'Class::Declare',
    VERSION_FROM      => 'Declare.pm', 
    PREREQ_PM         => {},
    ABSTRACT_FROM     => 'Declare.pm',
    AUTHOR            => 'Luke Palmer <luke at luqui dot org>',
);
