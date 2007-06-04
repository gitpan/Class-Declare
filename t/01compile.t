#!/usr/bin/perl -w
# $Id: 01compile.t,v 1.4 2003-06-17 06:04:24 ian Exp $

# compile.t
#
# Ensure the module compiles.

use strict;
use Test::More tests => 1;

# make sure the module compiles
BEGIN{ use_ok( 'Class::Declare' ) }
