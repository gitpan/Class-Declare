#!/usr/bin/perl -w
# $Id: Makefile.PL,v 1.5 2003/06/16 11:28:28 ian Exp $
#
# Makefile.PL for Class::Declare
#
# Copyright (c) 2003 Ian Brayshaw <ian@onemore.org>

use 5.000;
use ExtUtils::MakeMaker;

WriteMakefile(
    'NAME'         => 'Class::Declare',
    'VERSION'      => '0.04'          , # version no ahead of module version

	# list the module prerequisites
    'PREREQ_PM'    => {  Storable         => 0    ,
	                    'Test::More'      => 0    ,
	                    'Test::Exception' => 0.15 }, # needed for lives_and()

	# if we've got Perl > v5.005 then we can add other module keywords
    ($] >= 5.005 ?    ## Add these new keywords supported since 5.005
      ( ABSTRACT_FROM => 'Declare.pm'                         ,
        AUTHOR        => 'Ian Brayshaw <ian@ian@onemore.org>' ) : ())
);
