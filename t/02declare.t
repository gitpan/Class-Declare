#!/usr/bin/perl -Tw
# $Id: 02declare.t,v 1.6 2003/06/03 22:50:46 ian Exp $

# declare.t
#
# Ensure declare() behaves appropriately. Test such things as:
#   - calling twice within a package
#   - valid call parameters
#   - invalid call parameters
#
# NB: Not all tests of declare() are performed here. See other test
#     scripts.

use strict;
use Test::More tests => 8;
use Test::Exception;

# create a package with derived from Class::Declare
lives_ok {
	package Test::Declare::One;

	use base qw( Class::Declare );

	__PACKAGE__->declare();

	1;
} 'empty declare() succeeds';

# call declare twice for the same package
dies_ok {
	package Test::Declare::Two;

	use base qw( Class::Declare );

	__PACKAGE__->declare();
	__PACKAGE__->declare();

	1;
} 'duplicate calls to declare() fail';

# only accepts valid arguments
lives_ok {
	package Test::Declare::Three;

	use base qw( Class::Declare );

	__PACKAGE__->declare( public    => undef ,
	                      private   => undef ,
	                      protected => undef ,
	                      class     => undef ,
	                      init      => undef ,
	                      strict    => undef ,
	                      friends   => undef );
	1;
} 'valid arguments to declare() OK';

# invalid arguments cause failure
dies_ok {
	package Test::Declare::Four;

	use base qw( Class::Declare );

	__PACKAGE__->declare( foo => undef );

	1;
} 'invalid declare() arguments fails';

# cannot declare attributes of name 'public', 'private', etc
# i.e. attributes cannot mask any of the methods supplied by
# Class::Declare
# NB: only need to test this twice as all reserved attribute names
#     will execute either the "class" code or the
#     "public/private/etc" code
dies_ok {
	package Test::Declare::Five;

	use base qw( Class::Declare );

	__PACKAGE__->declare( public => { protected => undef } );

	1
} 'invalid public/private/protected attribute name';

dies_ok {
	package Test::Declare::Six;

	use base qw( Class::Declare );

	__PACKAGE__->declare( class  => { private   => undef } );

	1
} 'invalid class attribute name';

# cannot redeclare attributes
dies_ok {
	package Test::Declare::Seven;

	use base qw( Class::Declare );

	__PACKAGE__->declare( public  => { attribute => undef } ,
	                      private => { attribute => undef } );

	1
} 'attribute redefinition' ;

# can declare attributes to have a code reference as their value
lives_ok {
	package Test::Declare::Eight;

	use base qw( Class::Declare );

	__PACKAGE__->declare( static => { attribute => sub { rand } } );

	1
} 'CODEREF attribute value OK' ;
