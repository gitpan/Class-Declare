#!/usr/bin/perl -w
# $Id: Makefile.PL,v 1.10 2008-07-06 23:09:06 ian Exp $
#
# Makefile.PL for Class::Declare
#
# Copyright (c) 2003 Ian Brayshaw <ian@onemore.org>

use 5.000;
use ExtUtils::MakeMaker;

WriteMakefile(
    'NAME'         => 'Class::Declare' ,
    'VERSION_FROM' => 'Declare.pm'     ,

	# list the module prerequisites
    'PREREQ_PM'    => {  Storable         => 0    ,
	                      'Test::More'      => 0    ,
	                      'Test::Exception' => 0.15 }, # needed for lives_and()

	# if we've got Perl > v5.005 then we can add other module keywords
    ($] >= 5.005 ?    ## Add these new keywords supported since 5.005
      ( ABSTRACT_FROM => 'Declare.pm'                          ,
        AUTHOR        => 'Ian Brayshaw <ian@onemore.org>' ) : ())
);
