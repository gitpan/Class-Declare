#!/usr/bin/perl -Tw
# $Id: 16arguments.t,v 1.4 2003/06/03 22:50:46 ian Exp $

# arguments.t
#
# Ensure the arguments() function works correctly.

use strict;
use Test::More	qw( no_plan );
use Test::Exception;

# load the Class::Declare module for the argument() method
use Class::Declare;

# create a method with named arguments
sub named
{
	my	%args	= Class::Declare->arguments( \@_ => { a => 1 } );

	# return the argument passed in
	return $args{ a };
} # named()

# create a method that accepts any arguments
sub any
{
	my	%args	= Class::Declare->arguments( \@_ );

	return 1;
} # any()


# ensure Class::Declare::arguments() can be called
lives_ok { Class::Declare->arguments } 'arguments() can be called';

# ensure arguments() returns undef when called with no parameters
ok( ! defined Class::Declare->arguments ,  'arguments() returns undef' );

# ensure arguments() dies if the first argument is not an array
# reference
 dies_ok { Class::Declare->arguments( 123   ) } 'scalar argument fails';
 dies_ok { Class::Declare->arguments( \12   ) } 'scalar reference fails';
 dies_ok { Class::Declare->arguments( {}    ) } 'hash reference fails';
 dies_ok { Class::Declare->arguments( sub{} ) } 'code reference fails';
lives_ok { Class::Declare->arguments( []    ) } 'array reference lives';

# ensure arguments() fails if the first argument is a list with an
# odd number of elements
 dies_ok { Class::Declare->arguments( [ 1 ] ) } 'odd length array fails';

# ensure arguments() fails if the second argument (if defined) is not
# a hash reference
 dies_ok { Class::Declare->arguments( [] => 123   ) } 'scalar argument fails';
 dies_ok { Class::Declare->arguments( [] => \12   ) } 'scalar reference fails';
 dies_ok { Class::Declare->arguments( [] => []    ) } 'array reference fails';
 dies_ok { Class::Declare->arguments( [] => sub{} ) } 'code reference fails';
lives_ok { Class::Declare->arguments( [] => {}    ) } 'hash reference lives';

# ensure arguments() returns the default values correctly
#   - as an array (hash)
my	%hash	= Class::Declare->arguments( [] => { a => 1 } );
ok(   $hash{ a } == 1 , 'default values return as a list' );

#   - as a hash reference
my	$hash	= Class::Declare->arguments( [] => { a => 1 } );
ok( $hash->{ a } == 1 , 'default values return as a hash reference' );

# ensure passed arguments are honoured
#    - defined arguments
	$hash	= Class::Declare->arguments( [ a => 2 ] => { a => 1 } );
ok( $hash->{ a } == 2 , 'passed argument values honoured' );

#    - undefined arguments
	$hash	= Class::Declare->arguments( [ a => undef ] => { a => 1 } );
ok( ! defined $hash->{ a } , 'passed undefined argument values honoured' );

# ensure unknown arguments raise an error
 dies_ok { Class::Declare->arguments( [ b => 2 ] => { a => 1 } ) }
         'unknown arguments raise an error with defaults';

# ensure unknown arguments are OK when we don't specify defaults
lives_ok { Class::Declare->arguments( [ b => 2 ] => undef ) }
         'unknown arguments are OK without defaults';
