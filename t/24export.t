#!/usr/bin/perl -w
# $Id: 24export.t,v 1.1 2006-01-31 21:38:04 ian Exp $

# export.t
#
# Ensure the symbol exports from Class::Declare are honoured.

use strict;
use Test::More	tests	=> 1;

# make sure we can import the read-write and read-only modifiers
BEGIN { use_ok( 'Class::Declare' , qw( :modifiers ) ) };
