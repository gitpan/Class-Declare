#!/usr/bin/perl -w
# $Id: 16version.t 1511 2010-08-21 23:24:49Z ian $

# version.t
#
# Ensure VERSION() and REVISION() behave appropriately.

use strict;
use Test::More tests => 5;

# create a package with just version information
package Test::Version::One;

use base qw( Class::Declare );
use vars qw( $VERSION       );
             $VERSION = '0.04';

1;

# return to the default package
package main;

# make sure this still reports 0.04 through the call to REVISION()
ok( Test::Version::One->VERSION eq '0.04' ,
    'normal version information reported correctly' );


# create a package with just revision information
#   NB: have to hack this to make sure CVS doesn't expand the
#       revision string (so that we can compare with a constant value)

package Test::Version::Two;

use base qw( Class::Declare );
use vars qw( $REVISION      );
             $REVISION  = '$Rev' . 'ision: 1.2.3 $';

1;

# return to the default package
package main;

# make sure the REVISION() method returns the correct revision number
ok( Test::Version::Two->REVISION eq '1.2.3' ,
    'revision information reported correctly' );

# make sure the version is the same as the revision
ok( Test::Version::Two->REVISION eq Test::Version::Two->VERSION ,
    'version numbers from revision strings reports correctly' );


# create a package with revision and version information
#   NB: have to hack this to make sure CVS doesn't expand the
#       revision string (so that we can compare with a constant value)

package Test::Version::Three;

use base qw( Class::Declare     );
use vars qw( $REVISION $VERSION );
             $REVISION  = '$Rev' . 'ision: 1.2.3 $';
       $VERSION = '0.4';

1;

# return to the default package
package main;

# make sure the REVISION() method returns the correct revision number
ok( Test::Version::Three->REVISION eq '1.2.3' ,
    'revision information reported correctly with version information' );

# make sure the version is the reported correctly
ok( Test::Version::Three->VERSION  eq '0.4'   ,
    'version numbers overriding revision strings reports correctly' );
