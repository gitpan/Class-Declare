#!/usr/bin/perl -w
# $Id: 23shared.t,v 1.1 2006-01-31 21:38:04 ian Exp $

# shared.t
#
# Ensure calls to Class::Declare::shared() die
#   - shared() has been deprecated since v0.02

use strict;
use Test::More	tests => 2;
use Test::Exception;

# make sure trying to declare a shared attribute fails
throws_ok {
	package Test::Shared::One;

	use strict;
	use base qw( Class::Declare );

	__PACKAGE__->declare( shared => undef );

	1;
} "/Unknown parameter 'shared'/" ,
  "deprecated type 'shared' caught in call to declare()";

# make sure a call to Class::Declare::shared() dies with a message about the
# deprecation of the the attribute/method type
throws_ok { Class::Declare->shared } '/deprecated/' ,
          "caught deprecation error message from shared()";
