#!/usr/bin/perl -Tw
# $Id: 17storable.t,v 1.6 2003/06/03 22:50:46 ian Exp $

# storable.t
#
# Ensure Class::Declare objects are serializable via Storable.

use strict;
use Test::More	tests => 16;
use Test::Exception;

# define a Class::Declare package
package Test::Storable::One;
use base qw( Class::Declare );

# declare some public attributes
__PACKAGE__->declare( public => { a => 1 , b => \2 } );

1;


# commence the tests
package main;

#
# Storable uses hooks within the defining class to perform custom
# serializations of objects: STORABLE_freeze() & STORABLE_thaw()
# To test whether these both work, we can atempt to deep clone the
# object, since this will involve initially a freeze and then a thaw.
#

use Storable	qw( dclone );

# create an instance of the Test::Storable object
my	$object	= Test::Storable::One->new;

# create a clone of this object using Storable's dclone()
my	$clone;
lives_ok { $clone = dclone( $object ) } 'cloning lives';

# ensure that $clone is a reference and is a reference to a
# Test::Storable object
ok( ref( $clone ) , 'clone is a reference' );
ok( ref( $clone ) eq ref( $object ) , 'clone is an object' );

# ensure these represent two different objects
ok(    $object   !=    $clone   , 'cloned object is different from original' );
{ # ensure the scalar the clone references is different from the original
	no strict 'refs';
	ok( ${ $object } != ${ $clone } ,
	    'cloned object index is different from original' );
}

# ensure the public attributes have been cloned properly
#   - references should be cloned
#   - values should be copied
ok(    $object->a   ==    $clone->a               , 'scalar value cloned' );
ok(                  ref( $clone->b )             , 'reference copied' );
ok(                  ref( $clone->b ) eq 'SCALAR' , 'reference type cloned' );
ok(    $object->b   !=    $clone->b               , 'reference cloned' );
ok( ${ $object->b } == ${ $clone->b }             , 'reference value cloned' );


# Storable doesn't handle CODEREFs, so Class::Declare implements a little
# hack to allow dclone() to work with CODEREFs ... time to test it

package Test::Storable::Two;

use strict;
use base qw( Class::Declare );

# declare a public attribute with a CODEREF value
use constant	RANDOM	=> rand;

__PACKAGE__->declare( public => { attribute => sub { RANDOM } } );

1;

# return to main to resume testing
package main;

# can we create the object?
lives_ok { $object = Test::Storable::Two->new }
         "object creation with code reference attribute succeeds";

# can we clone the object?
lives_ok { $clone  = dclone( $object ) }
         "cloning of object with code reference attribute value succeeds";

# is the original object still have a CODEREF as the attribute value?
ok( ref( $object->attribute ) eq 'CODE' ,
    "cloning preserves original attribute as code reference" );

# does the original CODEREF still return the right value?
ok( $object->attribute->() == Test::Storable::Two::RANDOM ,
    "original attribute preserves value after cloning" );

# does the cloned object have a CODEREF as the attribute value?
ok( ref( $clone->attribute ) eq 'CODE' ,
    "cloned attribute takes code reference value" );

# does this CODEREF return the correct value?
ok( $clone->attribute->() == Test::Storable::Two::RANDOM ,
    "cloned attribute preserves original value" );
