#!/usr/bin/perl -Tw
# $Id: 03new.t,v 1.3 2003/06/03 22:50:46 ian Exp $

# new.t
#
# Ensure new() behaves appropriately. Test such things as:
#   - returns a valid Class::Declare object
#   - honours default values
#   - allows setting of public only attributes

use strict;
use Test::More tests => 9;
use Test::Exception;

# Declare the a Class::Declare package
package Test::New::One;

use base qw( Class::Declare );

__PACKAGE__->declare( public    => { mypublic    => 1 } ,
                      private   => { myprivate   => 1 } ,
                      protected => { myprotected => 1 } ,
                      class     => { myclass     => 1 } );

1;

package main;

# does object creation work
my	$obj;
lives_ok { $obj = Test::New::One->new } 'object creation succeeds';

# is $obj an object?
ok( ref $obj  , 'object is a reference' );

# is $obj a Class::Declare object
ok( $obj->isa( 'Class::Declare' ) , 'object is a Class::Declare object' );

# is the public attribute honoured?
ok( $obj->mypublic == 1 , 'public attribute default value is honoured' );

# can we change the default value for the public attribute?
lives_ok { $obj = Test::New::One->new( mypublic => 2 ) }
         'constructor calling with public attribute values';

# was this value set?
ok( $obj->mypublic == 2 , 'constructor setting of public attributes' );

# shouldn't be able to set private, protected or class values in the
# constructor
dies_ok { $obj = Test::New::One->new( myprivate   => 2 ) }
        'private attribute setting in the constructor';
dies_ok { $obj = Test::New::One->new( myprotected => 2 ) }
        'protected attribute setting in the constructor';
dies_ok { $obj = Test::New::One->new( myclass     => 2 ) }
        'class attribute setting in the constructor';
