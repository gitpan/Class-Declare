#!/usr/bin/perl -Tw
# $Id: 01compile.t,v 1.3 2003/06/03 22:50:46 ian Exp $

# compile.t
#
# Ensure the module compiles.

use strict;
use Test::More tests => 1;

# make sure the module compiles
BEGIN{ use_ok( 'Class::Declare' ) }
