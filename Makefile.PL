#!/usr/bin/perl -w
# $Id: Makefile.PL,v 1.4 2003/06/03 22:50:46 ian Exp $
#
# Makefile.PL for Class::Declare
#
# Copyright (c) 2003 Ian Brayshaw <ian@onemore.org>

use 5.000;
use ExtUtils::MakeMaker;

WriteMakefile(
    'NAME'         => 'Class::Declare',
    'VERSION_FROM' => 'Declare.pm'    , # finds $VERSION

	# list the module prerequisites
    'PREREQ_PM'    => {  Storable         => 0 ,
	                    'Test::More'      => 0 ,
	                    'Test::Exception' => 0 },

	# if we've got Perl > v5.005 then we can add other module
	# keywords
    ($] >= 5.005 ?    ## Add these new keywords supported since 5.005
      ( AUTHOR     => 'Ian Brayshaw <ian@ian@onemore.org>') : ())
);
