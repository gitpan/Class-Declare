#!/usr/bin/perl -Tw
# $Id: 18strict.t,v 1.4 2003/06/03 22:50:46 ian Exp $

# strict.t
#
# Ensure turning strict off permits calling of prohibited methods &
# attributes (e.g. private, protected, static, etc)

use strict;
use lib                 	qw( t          );
use Class::Declare::Test	qw( :constants );

#
# define all the tests permutations that are expected to live
#

# all tests should behave the same regardless of context
my	@contexts	= ( CTX_CLASS    , CTX_DERIVED   , CTX_UNRELATED ,
  	         	    CTX_INSTANCE , CTX_INHERITED , CTX_FOREIGN   );

# class attributes/methods are accessible and readable, but not writeable
my	@class		= ( TGT_CLASS    , TGT_DERIVED   );
# instance attributes/methods are accessible, readable and writeable
my	@instance	= ( TGT_INSTANCE , TGT_INHERITED );

# add the class tests
#   i.e. for class, static and shared attributes and methods
my	@ctests;	undef @ctests;
foreach my $context ( @contexts ) {
	# the method and attribute behaviours are the same for classes as
	# for instances
	foreach my $target ( @class , @instance ) {
		# class attributes are accessible, readable and not writeable
		push @ctests , ( $context | $target | ATTRIBUTE | TST_ACCESS | LIVE ,
		                 $context | $target | ATTRIBUTE | TST_READ   | LIVE ,
		                 $context | $target | ATTRIBUTE | TST_WRITE  | DIE  ,

		# class methods are accessbile and readable
		# NB: Class::Declare::Test will only test methods for
		#     accessibility and to determine if the values are
		#     readable. All other tests are meaningless for methods.
		                 $context | $target | METHOD    | TST_ALL    | LIVE );
	}
}

# add the instance tests
#   i.e. for public, private and protected attributes and methods
my	@itests;	undef @itests;
foreach my $context ( @contexts ) {
	# access is permitted for instances
	foreach my $target ( @instance ) {
		# instance attributes are accessible, readable and writeable
		push @itests , ( $context | $target | ATTRIBUTE | TST_ALL    | LIVE ,

		# instance methods are accessbile and readable
		# NB: Class::Declare::Test will only test methods for
		#     accessibility and to determine if the values are
		#     readable. All other tests are meaningless for methods.
		                 $context | $target | METHOD    | TST_ALL    | LIVE );
	}

	# for classes, attribute access is denied since we need to be
	# able to resolve the referrant to a Class::Declare hash, but
	# access is permitted to methods (we have no idea what the
	# method will do)
	foreach my $target ( @class ) {
		push @itests , ( $context | $target | ATTRIBUTE | TST_ALL    | DIE  ,
		                 $context | $target | METHOD    | TST_ALL    | LIVE );
	}
}


# run the class attribute/method tests
foreach my $type ( qw( class static shared ) ) {
	# create the test object
	my	$test	= Class::Declare::Test->new( type   =>  $type   ,
	  	     	                             tests  => \@ctests ,
	  	     	                             strict => 0        );
	# run the tests
		$test->run;
}

# run the instance attribute/method tests
foreach my $type ( qw( public private protected ) ) {
	# create the test object
	my	$test	= Class::Declare::Test->new( type   =>  $type   ,
	  	     	                             tests  => \@itests ,
	  	     	                             strict => 0        );
	# run the tests
		$test->run;
}
