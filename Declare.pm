#!/usr/bin/perl -Tw

# $Id: Declare.pm,v 1.37 2003/06/06 12:18:29 ian Exp $
package Class::Declare;

use strict;

=head1 NAME

Class::Declare - Declare classes with public, private and protected attributes
and methods.


=head1 SYNOPSIS

  package My::Class;

  use strict;
  use warnings;
  use base qw( Class::Declare );

  __PACKAGE__->declare( public     => { public_attr     => 42         } ,
                        private    => { private_attr    => 'Foo'      } ,
                        protected  => { protected_attr  => 'Bar'      } ,
                        class      => { class_attr      => [ 3.141 ]  }
                        static     => { static_attr     => { a => 1 } } ,
                        restricted => { restricted_attr => \'string'  } ,
                        friends    => 'main::trustedsub'                ,
                        init       => sub { # object initialisation
                                        ...
                                        1;
                                      }                                 ,
                        strict     => 0
                      );

  sub publicmethod {
    my $self = __PACKAGE__->public( shift );
    ...
  }

  sub privatemethod {
    my $self = __PACKAGE__->private( shift );
    ...
  }

  sub protectedmethod {
    my $self = __PACKAGE__->protected( shift );
    ...
  }

  sub classmethod {
    my $self = __PACKAGE__->class( shift );
    ...
  }

  sub staticmethod {
    my $self = __PACKAGE__->static( shift );
    ...
  }

  sub restrictedmethod {
    my $self = __PACKAGE__->restricted( shift );
    ...
  }

  1;

  ...

  my $obj = My::Class->new( public_attr => 'fish' );
   
=cut


use base qw( Exporter           );
use vars qw/ $VERSION $REVISION /;

# the version of this module
             $VERSION	= '0.02';
			 $REVISION	= '$Revision: 1.37 $';

# use Storable for deep-cloning of Class::Declare objects
use Storable;


=head1 MOTIVATION

One of Perl's greatest strengths is it's flexible object model. You can turn
anything (so long as it's a reference, or you can get a reference to it) into
an object. This allows coders to choose the most appropriate implementation for
each specific need, and still maintain a consistent object oriented approach.

A common paradigm for implementing objects in Perl is to use a blessed hash
reference, where the keys of the hash represent attributes of the class. This
approach is simple, relatively quick, and trivial to extend, but it's not
very secure. Since we return a reference to the hash directly to the user
they can alter hash values without using the class's accessor methods. This
allows for coding "short-cuts" which at best reduce the maintainability of
the code, and at worst may introduce bugs and inconsistencies not anticipated
by the original module author.

On some systems, this may not be too much of a problem. If the developer
base is small, then we can trust the users of our modules to Do The Right
Thing. However, as a module's user base increases, or the complexity of
the systems our module's are embedded in grows, it may become desirable
to control what users can and can't access in our module to guarantee our
code's behaviour. A traditional method of indicating that an object's data
and methods are for internal use only is to prefix attribute and method
names with underscores. However, this still relies on the end user Doing
The Right Thing.

B<Class::Declare> provides mechanisms for module developers to explicitly
state where and how their class attributes and methods may be accessed, as
well as hiding the underlying data store of the objects to prevent unwanted
tampering with the data of the objects and classes. This provides a robust
framework for developing Perl modules consistent with more strongly-typed
object oriented languages, such as Java and C++, where classes provide
C<public>, C<private>, and C<protected> interfaces to object and class data
and methods.


=head1 DESCRIPTION

B<Class::Declare> allows class authors to specify public, private and
protected attributes and methods for their classes, giving them
control over how their modules may be accessed. The standard object oriented
programming concepts of I<public>, I<private> and I<protected> have been
implemented for both class and instance (or object) attributes and methods.

Attributes and methods belong to either the I<class> or an I<instance> 
depending on whether they may be invoked via class instances (class
and instance methods/attributes), or via classes (class methods/attributes
only).

B<Class::Declare> uses the following definitions for I<public>, I<private>
and I<protected>:

=over 4

=item B<public>

Public attributes and methods may be accessed by anyone from anywhere. The
term B<public> is used by B<Class::Declare> to refer to instance attributes
and methods, while the equivalent for class attributes and methods are given
the term B<class> attributes and methods.

=item B<private>

Private attributes and methods may be accessed only by the class defining
them and instances of that class. The term B<private> is used to refer
to instance methods and attributes, while the term B<static> refers to class
attributes and methods that exhibit the same properties.

=item B<protected>

Protected attributes and methods may only be accessed by the defining class
and it's instances, and classes and objects derived from the defining
class. Protected attributes and methods are used to define the interface for
extending a given class (through normal inheritance/derivation). The term
B<protected> is used to refer to protected instance methods and attributes,
while protected class methods and attributes are referred to as B<restricted>.

B<Note:> since version 0.02, protected class methods and attributes are
refered to as I<restricted>, rather than I<shared>. This change was brought
about by the introduction of L<Class::Declare::Attributes> and then clash
with the existing Perl threading attribute B<:shared>. The term I<restricted>
has been chosen to reflect that the use of these methods and attributes is
restricted to the family of classes derived from the base class.

=back

The separation of terms for class and instance methods and attributes has
been adopted to simplify class declarations. See B<declare()> below.

Class attributes are regarded as constant by B<Class::Declare>: once
declared they may not be modified. Instance attributes, on the other hand,
are specific to each object, and may be modified at run-time.

Internally, B<Class::Declare> uses hashes to represent the attributes of each
of its objects, with the hashes remaining local to B<Class::Declare>. To
the user, the objects are represented as references to scalars which
B<Class::Declare> maps to object hashes in the object accessors. This prevents
users from accessing object and class data without using the class's accessors.

The granting of access to attributes and methods is determined by examining the
I<target> of the invocation (the first parameter passed to the method, usually
represented by C<$self>), as well as the I<context> of the invocation (where
was the call made and who made it, determined by examining the L<caller>()
stack). This adds an unfortunate but necessary processing overhead for
B<Class::Declare> objects for each method and attribute access. While this
overhead has been kept as low as possible, it may be desirable to turn it
off in a production environment. B<Class::Declare> permits disabling of
the access control checks on a per-module basis, which may greatly improve
the performance of an application.  Refer to the I<strict> parameter of
B<declare()> below for more information.

B<Class::Declare> inherits from L<Exporter>, so modules derived from
B<Class::Declare> can use the standard symbol export mechanisms. See
L<Exporter> for more information.

=head2 Defining Classes

To define a B<Class::Declare>-derived class, a package must first C<use>
B<Class::Declare> and inherit from it (either by adding it to the C<@ISA>
array, or through C<use base>). Then B<Class::Declare::declare()> must be
called with the new class's name as its first parameter, followed by a list
of arguments that actually defines the class. For example:

  package My::Class;

  use strict;
  use warnings;
  use base qw( Class::Declare );

  __PACKAGE__->declare( ... );

  1;

B<Class::Declare::declare()> is a class method of B<Class::Declare> and has the following call syntax and behaviour:

=over 4

=item B<declare(> [ I<param> => I<value> ] B<)>

B<declare()>'s primary task is to define the attributes of the class
and its instances. In addition, it supports options for defining object
initialisation code, friend methods and classes, and the application of
strict access checking. I<param> may have one of the following values:

=over 4

=item I<public>

I<public> expects a hash reference of attribute names and default values,
that represent the public attributes of this class. B<Class::Declare>
constructs accessor methods within the class, with the same name as the
attributes. These methods are C<lvalue> methods, which means that the
attributes may be assigned to, as well as being set by passing the new value
as an accessor's argument.

For example:

  package My::Class;

  use strict;
  use warnings;
  use base qw( Class::Declare );

  __PACKAGE__->declare( public => { name => 'John' } );

  1;

  my $obj = My::Class->new;
  print $obj->name . "\n"; # prints 'John'
     $obj->name = 'Fred';  # the 'name' attribute is now 'Fred'
     $obj->name( 'Mary' ); # the 'name' attribute is now 'Mary'

The default value of each attribute is assigned during the object
initialisation phase (see I<init> and B<new()> below). Public attributes
may be set during the object creation call:

  my $obj = My::Class->new( name => 'Jane' );
  print $obj->name . "\n"; # prints 'Jane'

I<public> attributes are instance attributes and therefore may only be
accessed through class instances, and not through the class itself.

=item I<private>

As with I<public> above, but the attributes are private (i.e. only accessible
from within this class). If access is attempted from outside the defining
class, then an error will be reported through B<die()>. I<Private>
attributes may not be set in the call to the constructor, and as with I<public>
attributes, are instance attributes. See also I<strict> and I<friends> below.

=item I<protected>

As with I<private> above, but the attributes are protected (i.e. only
accessible from within this class, and all classes that inherit from
this class).  Protected attributes are instance attributes, and they may not
be set in the call to the constructor. See also I<strict> and I<friends> below.

=item I<class>

This declares class attributes in the same manner as I<public> above. I<class>
attributes are not restricted to object instances, and may be accessed via the
class directly. The accessor methods created by B<Class::Declare>, however,
are not C<lvalue> methods, and cannot, therefore, be assigned to. Nor can the
values be set through the accessor methods. They behave in the same manner
as values declared by C<use constant> (except they must be called as class
or instance methods). I<Class> attributes may not be set in the call to
the constructor.

=item I<static>

As with I<class> attributes, except access to C<static> attributes is
limited to the defining class and its objects. I<static> attributes are the
class-equivalent of I<private> instance attributes. See also I<friends>.

=item I<restricted>

As with I<class> attributes, except access to C<restricted> attributes is
limited to the defining class and all classes that inherit from the defining
class, and their respective objects.  I<restricted> attributes are the
class-equivalent of I<protected> instance attributes. See also I<friends>.

=item I<friends>

Here you may specify classes and methods that may be granted access to the
defining classes I<private>, I<protected>, I<static> and I<restricted>
attributes and methods. I<friends> expects either a single value, or a
reference to a list of values. These values may either be class names, or
fully-qualified method names (i.e. class and method name). When a call is
made to a private or protected method or attribute accessor, and a friend
has been declared, a check is performed to see if the caller is within a
friend package or is a friend method. If so, access is granted. Otherwise,
access is denied through a call to B<die()>.

Note that friend status may not be inherited. This is to avoid scenarios
such as the following:

  package My::Class;

  use strict;
  use warnings;
  use base qw( Class::Declare );

  __PACKAGE__->declare( ...
                        friends => 'My::Trusted::Class' );
  1;

  package My::Trusted::Class;
  ...
  1;

  package Spy::Class;

  use strict;
  use warnings;
  use base qw( My::Trusted::Class );

  sub infiltrate {
    .. do things here to My::Class objects that we shouldn't
  }

  1;


=item I<init>

This defines the object initialisation code, which is executed as the last
phase of object creation by B<new()>. I<init> expects a C<CODEREF> which is
called with the first argument being the new object being created by the
call to B<new()>. The initialisation routine is expected to return a true
value to indicate success. A false value will cause B<new()> to C<die()>
with an error. The initialisation routines are invoked during object creation
by B<new()>, after default and constructor attribute values have been assigned.

If the inheritance tree of a class contains multiple I<init> methods, then
these will be executed in reverse @ISA order to ensure the primary base-class
of the new class has the final say on object initialisation (i.e. the class
left-most in the @ISA array will have it's I<init> routine executed last). If
a class appears multiple times in an @ISA array, either through repetition or
inheritance, then it will only be executed once, and as early in the I<init>
execution chain as possible.

B<Class::Declare> uses a C<CODEREF> rather than specifying a default
initialisation subroutine (e.g. C<sub INIT { ... }>) to avoid unnecessary
pollution of class namespaces. There is generally no need for initialisation
routines to be accessible outside of B<new()>.

=item I<strict>

If I<strict> is set to I<true>, then B<Class::Declare> will define B<class()>,
B<static()>, B<restricted()>, B<public()>, B<private()>, and B<protected()>
methods (see L</Class Methods> and L</Object Methods> below) within the
current package that enforce the
class/static/restricted/public/private/protected relationships in method calls.

If I<strict> is set to I<false> and defined (e.g. 0, not C<undef>), then
B<Class::Declare> will convert the above method calls to no-ops, and no
invocation checking will be performed. Note that this conversion is
performed for this class only.

By setting I<strict> to C<undef> (or omitting it from the call to B<declare()>
altogether), B<Class::Declare> will not create these methods in the current
package, but will rather let them be inherited from the parent class.
In this instance, if the parent's methods are no-ops, then the child class
will inherit no-ops. Note that the B<public()>, B<private()>, etc methods
from B<Class::Declare> enforce the public/private/etc relationships.

One possible use of this feature is as follows:

  package My::Class;

  use strict;
  use warnings;
  use base qw( Class::Declare );

  __PACKAGE__->declare( public    => ...                ,
                        private   => ...                ,
                        protected => ...                ,
                        strict    => $ENV{ USE_STRICT } );

  ...

  1;

Here, during development and testing the environment variable C<USE_STRICT> may
be left undefined, or set to true to help ensure correctness of the code, but
then set to false (e.g. 0) in production to avoid the additional computational
overhead.

Setting I<strict> to I<false> does not interfere with the B<friends()> method
(see below). Turning strict access checking off simply stops the checks from
being performed and does not change the logic of whether a class or method
as been declared as a friend of a given class.

=back

B<Note:>

=over 4

=item *

B<declare()> may be called only once per class to prevent class redefinitions

=item *

attribute names specified in the call to B<declare()> may not be the same
as class and instance methods already defined in the class

=item *

attribute names must be unique for a class

=back

If any of the above rules are violated, then B<declare()> will raise an
error with B<die()>.

=cut

{ # closure for Class admin storage

	# define class declaration list storage
	#
	my	%__DECL__		= ();

	# define class initialisation storage
	#
	my	%__INIT__		= ();

	# define class default attribute storage
	#
	my	%__DEFN__		= ();

	# define class default attribute storage
	#
	my	%__ATTR__		= ();

	# define class mapping of attributes to attribute types
	#
	my	%__TYPE__		= ();

	# define class friend definitions storage
	#
	my	%__FRIEND__		= ();

	# define global object storage
	#
	my	@__OBJECTS__	= ();	# array holding current object hashes
	my	@__DESTROYED__	= ();	# indices of destroyed objects

	# pre-extend the @__OBJECTS__ array and randomly populate the
	# @__DESTROYED__ array to minimise the risk of object indices
	# being predicted
	{
		# define the number of indices to pre-declare
		my $INDICES		= 31;	# $INDICES+1 entries created

		# generate an empty @__OBJECTS__ array
			$__OBJECTS__[ $INDICES ]	= undef;

		# generate a random list of indices to prepopulate the
		# @__DESTROYED__ array
		#    - new object indices will be taken from this list

		# $shuffle()
		#
		# Implementation of Fisher-Yates shuffle, as presented in
		# "Perl Cookbook", by Christiansen and Torkington, O'Reilly &
		# Associates, First Edition, p121.
		my	$shuffle	= sub {
				for ( my $i = scalar @_ ; --$i ; ) {
					my	$j	= int( rand( $i + 1 ) );

					# don't bother with the swap if there's no swap
					next		if ( $i == $j );

					# swap the array elements
					@_[ $i , $j ]	= @_[ $j , $i ];
				}

				@_;		# return the now scrambled array
			}; # $shuffle()

		# generate the random list of "destroyed" indices
			@__DESTROYED__	= $shuffle->( 0 .. $INDICES );
	}

	# define a random offset for the object indices
	#    NB: this will not be used to generate actual array indices,
	#        but rather to hide the actual object position within the
	#        @__OBJECTS__ array.
	my	$OFFSET			= int( rand time );

	# create a map to say which attributes are instance attributes and
	# which are class attributes
	my	%__INSTANCE__	= map { $_ => 1 } qw( public private protected );


# declare()
#
sub declare : locked
{
	# determine the class we've been called from
	my	$class		= __PACKAGE__->class( shift );	# this should be our name
		$class		= ref( $class ) || $class;		# ... make sure it is :)
	
	# where were we called from
	my	( undef , $file , $line )	= caller 0;

	# make sure this is only called once per class
	( exists $__DECL__{ $class } )
		and die "$class redeclared at $file line $line "
		        . "\n\t(original declaration at "
				. $__DECL__{ $class }->{ file } . " line "
				. $__DECL__{ $class }->{ line } . ")\n";

	# make sure we have a valid set of arguments
	my	$_args	= __PACKAGE__->arguments( \@_ => { public     => undef ,
	  	      	                                   private    => undef ,
	  	      	                                   protected  => undef ,
	  	      	                                   class      => undef ,
	  	      	                                   static     => undef ,
	  	      	                                   restricted => undef ,
	  	      	                                   init       => undef ,
	  	      	                                   strict     => undef ,
	  	      	                                   friends    => undef } );

	# ensure the init argument is undefined or is a code ref
	( ! defined $_args->{ init } || ref( $_args->{ init } ) eq 'CODE' )
		or die "$class init failure: " . $_args->{ init }
		       . " is not a CODEREF at $file line $line\n";

	# store the class initialiser reference
	my	$ref				= delete $_args->{ init };
		$__INIT__{ $class }	= $ref			if ( defined $ref );

	# are we required to perform strict type checking, or not, or are
	# they just not bothered?
	my	$strict					= delete $_args->{ strict };
	if ( defined $strict ) {
		# if the class requires strict relationship checking, then
		# insert reference to the standard Class::Declare public(),
		# private(), protected() and class() methods into the new
		# class's symbol table, otherwise, just ad no-ops.
		foreach ( grep { $_ ne 'friends' } keys %{ $_args } ) {
			no strict 'refs';

			my	$glob	= join '::' , $class , $_;
			 *{ $glob }	= ( $strict ) ? *{ join '::' , __PACKAGE__ , $_ }
			           	              : sub { $_[ 1 ] };
		}

	}
	# if there's no explicit definition of the public(), private(), etc
	# methods, so this class will just inherit from its parents

	# have we been told of friends of this class?
	my	$friends				= delete $_args->{ friends };
	if ( defined $friends ) {
		# make sure we have a list of values
		$friends	= [ $friends ]		unless ( ref $friends );
		( ref( $friends ) eq 'ARRAY' )
			or die "An array reference or scalar expected for declaration "
			       . "of friend methods and classes at $file line $line\n";

		# now create the friends lookup table for this class
		$__FRIEND__{ $class }	= { map { $_ => undef } @{ $friends } };
	}

	# make sure there are no duplicate attribute names
	{
		local	%_;

		# examine each type of attribute
		TYPE: foreach my $type ( keys %{ $_args } ) {
			my	$ref	= $_args->{ $type };

			# if there are no attributes of this type, then skip
			next TYPE		unless ( defined $ref );

			# make sure we don't have doubling up
			METHOD: foreach my $attr ( keys %{ $ref } ) {
				( exists $_{ $attr } )
					and die "$class attribute $attr redefined as $type "
					        . " at $file line $line"
							. "\n\t(also defined as "
							. $_{ $attr }->{ type } . " at "
							. $_{ $attr }->{ file } . " line "
							. $_{ $attr }->{ line } . ")\n";

				# store where this attribute was defined
				$_{ $attr }	= { type => $type ,
				           	    file => $file ,
				           	    line => $line };
			}
		}
	}

	# create the required attribute accessor methods
	TYPE: foreach my $type ( keys %{ $_args } ) {
		my	$ref	= $_args->{ $type };

		# if there are no types of these routines, then don't proceed
		next TYPE		unless ( defined $ref );

		# must make sure we have a hash reference
		( ref( $ref ) eq 'HASH' )
			or die "Hash reference expected for declaration of $type "
			       . "attributes at $file line $line\n";

		# create all of the attribute accessor methods for this package
		CREATE: foreach ( $type ) {
			# class attribute
			( ! $__INSTANCE__{ $_ } )	&& do {
				METHOD: foreach my $method ( keys %{ $ref } ) {
					# firstly, make sure this class doesn't already have a
					# method of this name defined
					( $class->has( $method ) )
						and die "Attempt to redeclare method $method in "
						        . "class $class as a $type method at $file "
								. "line $line\n";

					# now, make sure Class::Declare doesn't already have
					# a method of this name defined
					( __PACKAGE__->has( $method ) )
						and die "Attempt to override " . __PACKAGE__
						        . "::$method() in class $class as a "
								. "$type method at $file line $line\n";

					# OK, this method doesn't exist elsewhere, so we can
					# continue
					{
						no strict 'refs';

						# generate the glob name
						my	$glob	= join '::' , $class , $method;

						# class methods simply return a value
					 	*{ $glob }	= sub {
								my	$self	= $class->$type( shift , $glob );

								return $ref->{ $method };
							}; # new class/static/restricted method
					}
				}

				last CREATE;
			};

			# otherwise we're creating public, protected and private
			# methods
			METHOD: foreach my $method ( keys %{ $ref } ) {
				# need to make sure this class doesn't have a method of this
				# name already
				( $class->has( $method ) )
					and die "Attempt to redeclare method $method in "
					        . "class $class as a $type method at $file "
							. "line $line\n";

				# now, make sure Class::Declare doesn't already have
				# a method of this name defined
				( __PACKAGE__->has( $method ) )
					and die "Attempt to override " . __PACKAGE__
					        . "::$method() in class $class as a "
							. "$type method at $file line $line\n";

				# OK, this method doesn't exist already, so we can continue
				{
					no strict 'refs';

					# generate the glob name
					my	$glob	= join '::' , $class , $method;

					# public, private and protected attributes are lvalue
					# methods that update the object hash
				 	*{ $glob }	= sub : lvalue {
							my	$self	= $class->$type( shift , $glob );

							my	( $indx , $hash );
							# make sure we have a valid object
							( ref( $self )
								and ( $indx = ${ $self } - $OFFSET ) >= 0
								and   $hash	= $__OBJECTS__[ $indx ] )
								 or do {
									my	( undef , $file , $line )	= caller 0;
									die "$self is not a $class object at "
									    . "$file line $line\n";
								};

							# set the value if required and return
								$hash->{ $method }	= shift		if ( @_ );
								$hash->{ $method };
						}; # new public/private/protected method
				}
			}

		} # end of CREATE

	} # end of TYPE

	# OK, this is a new definition, so record the relevant details
	$__DECL__{ $class }	= { file => $file , line => $line };
	$__DEFN__{ $class }	= { map { %{ $_ } }
	                   	        grep { defined }
								     values %{ $_args } };

	# keep a record of the attributes of this class, making note of the type
	# of each attribute as well
	$__TYPE__{ $class }	= {};
	foreach my $type ( qw( class  static  restricted
	                       public private protected  ) ) {
		# do we have attributes of this type for this class?
		if ( my	@attr = keys %{ $_args->{ $type } } ) {
			$__ATTR__{ $class }->{ $type }	= \@attr;
			$__TYPE__{ $class }->{ $_    }	=  $type	foreach ( @attr );

		# if not, store an empty list
		} else {
			$__ATTR__{ $class }->{ $type }	= [];
		}
	}

	1;	# everything is OK
} # declare()


=back

=head2 Creating Objects

Once a B<Class::Declare>-derived class has been declared, instances
of that class may be created through the B<new()> method supplied by
B<Class::Declare>. B<new()> may be called either as a class or an instance
method. If called as a class method, a new instance will be created, using
the class's default attribute values as the default values for this
instance. If B<new()> is called as an instance method, the default attribute
values for the new instance will be taken from the invoking instance. This
may be used to clone B<Class::Declare>-derived objects.

B<Class::Declare::new()> has the following call syntax and behaviour:

=over 4

=item B<new(> [ I<param> => I<value> ] B<)>

B<new()> creates instances of B<Class::Declare> objects. If a problem
occurs during the creation of an object, such as the failure of an object
initialisation routine, then B<new()> will raise an error through B<die()>.

When called as a class method, B<new()> will create new instances of the
specified class, using the class's default attribute values. If it's called
as an instance method, then B<new()> will clone the invoking object.

B<new()> accepts named parameters as arguments, where I<param> corresponds
to a I<public> attribute of the class of the object being created. If
an unknown attribute name, or a non-I<public> attribute name is specified,
then B<new()> will B<die()> with an error. Public attribute values specified
in the call to B<new()> are assigned after the creation of the object, to
permit over-riding of default values (either class-default attributes or
attributes cloned from the invoking object).

If the calling class, or any of its base classes, has an object initialisation
routine defined (specified by the I<init> parameter of B<declare()>), then
these routines will be invoked in reverse C<@ISA> order, once the object's
attribute values have been set. An initialisation routine may only be called
once per class per object, so if a class appears multiple times in the C<@ISA>
array of the new object's class, then the base class's initialisation routine
will be called as early in the initialisation chain as possible, and only
once (i.e. as a result of the right-most occurrence of the base class in the
C<@ISA> array).

The initialisation routines should return a true value to indicate success. If
any of the routines fail (i.e. return a false value), then B<new()> will
B<die()> with an error.

=back

When a new instance is created, instance attributes (i.e. I<public>, I<private>
and I<protected> attributes) are cloned, so that the new instance has a copy
of the default values. For values that are not references, this amounts to
simply copying the value through assignment. For values that are references,
B<Storable::dclone()> is used to ensure each instance has it's own copy
of the references data structure (the structures are local to each instance).

However, if an instance attribute value is a C<CODEREF>, then B<new()> simply
copies the reference to the new object, since C<CODEREF>s cannot be cloned.

Class attributes are not cloned as they are assumed to be constant across
all object instances.

=cut
sub new : locked
{
	my	$self	= __PACKAGE__->class( shift );
	my	$class	= ref( $self ) || $self;

	# extract the next available slot in our array of objects
	my	$indx	=  shift @__DESTROYED__;
		$indx	= scalar @__OBJECTS__		unless ( defined $indx );

	# generate the combined @ISA array for this class
	my	@isa	= ( $class );
	my	$i		= 0;
	while ( $i <= $#isa ) {
		no strict 'refs';

		my	$pkg	= $isa[ $i++ ]	or next;
		push @isa , @{ $pkg . '::ISA' };
	}
	# remove the duplicates and reverse
		@isa	= local %_ || grep { ! $_{ $_ }++ } reverse @isa;

	# initialise the hash reference for this object instance
	#   - use Storable::dclone here to ensure that each object has
	#     a copy of the default values of the attributes, regardless
	#     of the structure
	#   - CODEREFs are not copied
	#   NB: when using Storable::dclone we need to make sure that we 
	#       only clone each reference once, so if multiple entries 
	#       refer to the same structure, then the copy of the hash will show
	#       those entries pointing to the same structure
	my	%hash;	undef %hash;
	{
		# create a lookup table of all stored references
		my	%memory;	undef %memory;

		# for each class, extract the attribute definition array
		ISA: foreach my $isa ( @isa ) {
			# only worry about Class::Declare classes
			next ISA		unless ( exists $__DECL__{ $isa } );

			# extract the definition hash for this class
			#   this contains the default values for the class and object
			#   attributes
			# however, if we've been called as an instance method, then we
			#   should use the calling object's instance hash (stored in
			#   @__OBJECTS__) for the default values
			# have we been called as an instance method?
			#   - extract the instance hash
			#   - otherwise, use the class's default hash (ignore this class
			#       if there is no default hash)
			my	$defn	= ref( $self ) ? $__OBJECTS__[ ${ $self } - $OFFSET ]
			     	                   : $__DEFN__{ $isa };

			# split the typemap hash into key/value pairs
			#    - the typemap hash maps attributes to their types
			#        e.g. public, private, protected, etc
			while ( my ( $key , $type ) = each %{ $__TYPE__{ $isa } } ) {
				# extract the value for this attribute
				my	$value	= $defn->{ $key };

				# if this is an instance attribute and it has a reference
				# value then we should clone the attribute value so that
				# each instance has a copy of the original structure
				my	$vtype	= ref( $value );
				if ( $vtype && $vtype ne 'CODE' && $__INSTANCE__{ $type } ) {
					# OK, we need to keep track of the references we
					# clone, so that if we see the same reference more
					# than once we only clone it a single time

					# clone this reference if we haven't seen it before
					$value	  = $memory{ $value }
					      	||= Storable::dclone( $value );
				}

				# store the key/value pair
					$hash{ $key }	= $value;
			}
		}
	}

	# create an anonymous hash reference for this object
		$__OBJECTS__[ $indx ]	= \%hash;

	# create the new object (applying the index offset)
		$indx	+= $OFFSET;
	my	$obj	 = bless \$indx => $class;

	# if there were any arguments passed, then these will be used to
	# set the parameters for this object
	# NB: - only public attributes may be set this way
	#     - need to examine every class in the @ISA hierarchy
	my	%default	= map { $_ => $hash{ $_ } }
	  	        	      map { @{ $_ } }
	  	        	          grep { defined }
	  	        	               map { $_->{ public } }
	  	        	                   grep { defined }
	  	        	                        map { $__ATTR__{ $_ } } @isa;
	my	%args		= eval { __PACKAGE__->arguments( \@_ => \%default ) };

	# if there has been an error, then augment the error string
	# with a new() specific explanation
	#    NB: have to adjust the original error string to show the
	#        source of the original error
	if ( $@ ) {
		my	( undef , $file , $line , $sub )	= caller 0;

		# rather than report this base class, make sure the
		# subroutine is a method of the calling class
		my	$pkg	= __PACKAGE__;
			$sub	=~ s#$pkg#$class#g;

		# augment the error message
		my	$msg	= $@;
			$msg	=~ s#\S+ at #$sub() at #;
			$msg	=~ s#at \S+ line \d+#at $file line $line#;

		# add the additional explanation to the message
		die $msg . "\t(only public attributes may be set during "
		         . "object creation)\n";
	}

	# otherwise, set the default attributes for this object
		$hash{ $_ }	= $args{ $_ }		foreach ( keys %args );

	# execute the initialisation routines
	foreach my $pkg ( grep { exists $__INIT__{ $_ } } @isa ) {
		# make sure the initialisation succeeds
		$__INIT__{ $pkg }->( $obj )
			or do {
				my	( undef , $file , $line )	= caller 0;

				die "Initialisation of $class object failed at "
				    . "$file line $line\n\t($pkg initialisation)\n";
			};
	}

	# return the object
	return $obj;
} # new()


=head2 Class Access Control Methods

B<Class::Declare> provides the following class methods for implementing
I<class>, I<static> and I<restricted> access control in class methods. These
methods may be called either through a B<Class::Declare>-derived class,
or an instance of such a class.

Note that a I<class> method is a I<public> class method, a I<static> method
is a I<private> class method, and a I<restricted> method is a I<protected>
class method.


=over 4

=item B<class(> I<target> B<)>

Ensure a method is called as a class method of this package via the I<target>.

  sub myclasssub {
    my $self = __PACKAGE__->class( shift );
    ...
  }

A I<class> method may be called from anywhere, and I<target> must inherit
from this class (either an object or instance). If B<class()> is not invoked
in this manner, then B<class()> will B<die()> with an error.

See also the I<strict> parameter for B<declare()> above.

=cut
sub class
{
	# has this method been called as a class or object method?
	return $_[ 1 ]		if ( defined $_[ 1 ] && $_[ 1 ]->isa( $_[ 0 ] ) );

	# determine where we (i.e. the method containing class()) was called from
	my	( undef , $file , $line , $sub )	= caller 1;
	my	  $class							= ref $_[ 0 ] || $_[ 0 ];
	die "$_[ 1 ] is not a $class class or object in call to $sub() "
	    . "at $file line $line\n";
} # class()


=item B<static(> I<target> B<)>

Ensure a method is called as a static method of this package via I<target>.

  sub mystaticsub {
    my $self = __PACKAGE__->static( shift );
    ...
  }

A I<static> method may only be called from within the defining class,
and I<target> must inherit from this class (either an object or instance).
If B<static()> is not invoked in this manner, then B<static()> will B<die()>
with an error.

See also the I<strict> and I<friends> parameters for B<declare()> above.

=cut
sub static
{
	# extract the caller context
	my	( $pkg , $file , $line , $sub )		= caller 1;
	my	  $class							= ref $_[ 0 ] || $_[ 0 ];
	
	# at the very least we must have a reference
	if ( defined $_[ 1 ] ) {
		# has this method been called as a static method?
		return $_[ 1 ]	if (    $_[ 1 ]->isa( $class )
	              	         &&       $pkg eq $class   );

		# have to go back on more depth in the caller stack to obtain
		# the name of the method in which this call was made
		my	( undef , undef , undef , $caller )	= caller 2;
		# is the caller a friend of this class?
		if ( my $ref = $__FRIEND__{ $class } ) {
			return $_[ 1 ]		if (    exists $ref->{ $pkg    }
			              		     || exists $ref->{ $caller } );
		}
	}

	# someone's trying to be naughty: time to tell them about it
	#   - the subroutine name may be passed in to ensure the correct
	#     glob is reported by the dynamically instantiated methods
	#     created by declare()
		  $sub								= $_[ 2 ] || $sub;
	die "cannot call static method $sub() from outside "
	    . "$class at $file line $line\n";
} # static()


=item B<restricted(> I<target> B<)>

Ensure a method is called as a restricted method of this package via I<target>.

  sub myrestrictedsub {
    my $self = __PACKAGE__->restricted( shift );
    ...
  }

A I<restricted> method may only be called from within the defining class or a
class that inherits from the defining class, and I<target> must inherit from
this class (either an object or instance).  If B<restricted()> is not invoked
in this manner, then B<restricted()> will B<die()> with an error.

See also the I<strict> and I<friends> parameters for B<declare()> above.

B<Note:> B<restricted()> was called B<shared()> in the first release of
B<Class::Declare>. However, with the advent of L<Class::Declare::Attributes>,
there was a clash between the use of B<:shared> as an attribute by
L<Class::Declare::Attributes>, and the Perl use of B<:shared> attributes
for threading.

=cut
sub restricted
{
	# extract the caller context
	my	( $pkg , $file , $line , $sub )		= caller 1;
	my	  $class							= ref $_[ 0 ] || $_[ 0 ];
	
	# at the very least we must have a reference
	if ( defined $_[ 1 ] ) {
		# has this method been called as a private method?
		return $_[ 1 ]	if (    $_[ 1 ]->isa( $_[ 0 ] )
	              	         &&    $pkg->isa( $_[ 0 ] ) );
		#
		# have to go back on more depth in the caller stack to obtain
		# the name of the method in which this call was made
		my	( undef , undef , undef , $caller )	= caller 2;

		# is the caller a friend of this class?
		if ( my $ref = $__FRIEND__{ $class } ) {
			return $_[ 1 ]		if (    exists $ref->{ $pkg    }
			              		     || exists $ref->{ $caller } );
		}
	}

	# someone's trying to be naughty: time to tell them about it
	#   - the subroutine name may be passed in to ensure the correct
	#     glob is reported by the dynamically instantiated methods
	#     created by declare()
		  $sub								= $_[ 2 ] || $sub;
	die "cannot call restricted method $sub() from outside $class "
	    . "sub-class at $file line $line\n";
} # restricted()

# NB: restricted() used to be shared(), so let's put a stub in place to show
#     the deprecation of shared()
sub shared
{
	# determine where we were called from
	my	( undef , $file , $line )		= caller 0;

	# show that shared() is no longer supported and die
	die __PACKAGE__ . '::shared() has been deprecated - see ' .
	    __PACKAGE__ ."'::restricted() instead (at $file line $line)\n";
} # shared()


=back

=head2 Instance Access Control Methods

B<Class::Declare> provides the following instance methods for implementing
I<public>, I<private> and I<protected> access control in instance methods.
These methods may only be called through a B<Class::Declare>-derived instance.

=over 4

=item B<public(> I<target> B<)>

Ensure a method is called as a public method of this class via I<target>.

  sub mypublicsub {
    my $self = __PACKAGE__->public( shift );
    ...
  }

A I<public> method may be called from anywhere, and I<target> must be an
object that inherits from this class. If B<public()> is not invoked in this
manner, then B<public()> will B<die()> with an error.

See also the I<strict> parameter for B<declare()> above.

=cut
sub public
{
	# has this method been called as a public method?
	return $_[ 1 ]		if ( defined $_[ 1 ] && ref $_[ 1 ]
	              		                     &&     $_[ 1 ]->isa( $_[ 0 ] ) );

	# determine where we (i.e. the method containing public())
	# was called from
	my	( undef , $file , $line , $sub )	= caller 1;
	my	  $class							= ref $_[ 0 ] || $_[ 0 ];
		  $sub								= $_[ 2 ] || $sub;
	die "$_[ 1 ] is not a $class object in call to $sub() "
	    . "at $file line $line\n";
} # public()


=item B<private(> I<target> B<)>

Ensure a method is called as a private method of this class via I<target>.

  sub myprivatesub {
    my $self = __PACKAGE__->private( shift );
    ...
  }

A I<private> method may only be called from within the defining class, and
I<target> must be an instance that inherits from this class. If B<private()>
is not invoked in this manner, then B<private()> will B<die()> with an error.

See also the I<strict> and I<friends> parameters for B<declare()> above.

=cut
sub private
{
	# extract the caller context
	my	( $pkg , $file , $line , $sub )		= caller 1;
	my	  $class							= ref $_[ 0 ] || $_[ 0 ];
	
	# at the very least we must have a reference
	if ( defined $_[ 1 ] && ref $_[ 1 ] ) {
		# has this method been called as a private method?
		return $_[ 1 ]	if (    $_[ 1 ]->isa( $class )
	              	         &&       $pkg eq $class   );

		# have to go back on more depth in the caller stack to obtain
		# the name of the method in which this call was made
		my	( undef , undef , undef , $caller )	= caller 2;
		# is the caller a friend of this class?
		if ( my $ref = $__FRIEND__{ $class } ) {
			return $_[ 1 ]		if (    exists $ref->{ $pkg    }
			              		     || exists $ref->{ $caller } );
		}
	}

	# someone's trying to be naughty: time to tell them about it
	#   - the subroutine name may be passed in to ensure the correct
	#     glob is reported by the dynamically instantiated methods
	#     created by declare()
		  $sub								= $_[ 2 ] || $sub;
	die "cannot call private method $sub() from outside "
	    . "$class at $file line $line\n";
} # private()


=item B<protected(> I<target> B<)>

Ensure a method is called as a protected method of this class via I<target>.

  sub myprotectedsub {
    my $self = __PACKAGE__->protected( shift );
    ...
  }

A I<protected> method may only be called from within the defining class
or a class that inherits from the defining class, and I<target> must be an
instance that inherits from this class. If B<protected()> is not invoked
in this manner, then B<protected()> will B<die()> with an error.

See also the I<strict> and I<friends> parameters for B<declare()> above.

=cut
sub protected
{
	# extract the caller context
	my	( $pkg , $file , $line , $sub )		= caller 1;
	my	  $class							= ref $_[ 0 ] || $_[ 0 ];
	
	# at the very least we must have a reference
	if ( defined $_[ 1 ] && ref $_[ 1 ] ) {
		# has this method been called as a private method?
		return $_[ 1 ]	if (    $_[ 1 ]->isa( $_[ 0 ] )
	              	         &&    $pkg->isa( $_[ 0 ] ) );

		# have to go back on more depth in the caller stack to obtain
		# the name of the method in which this call was made
		my	( undef , undef , undef , $caller )	= caller 2;

		# is the caller a friend of this class?
		if ( my $ref = $__FRIEND__{ $class } ) {
			return $_[ 1 ]		if (    exists $ref->{ $pkg    }
			              		     || exists $ref->{ $caller } );
		}
	}

	# someone's trying to be naughty: time to tell them about it
	#   - the subroutine name may be passed in to ensure the correct
	#     glob is reported by the dynamically instantiated methods
	#     created by declare()
		  $sub								= $_[ 2 ] || $sub;
	die "cannot call protected method $sub() from outside $class "
	    . "sub-class at $file line $line\n";
} # protected()


=back

=head2 Destroying Objects

Object destruction is handled via the normal Perl C<DESTROY()>
method. B<Class::Declare> implements a C<DESTROY()> method that performs
clean-up and house keeping, so it is important that any class derived from
B<Class::Declare> that requires a C<DESTROY()> method ensures that it invokes
it's parent's C<DESTROY()> method, using a paradigm similar to the following:

  sub DESTROY
  {
    my $self = __PACKAGE__->public( shift );

    ... do local clean-up here ..

    # call the parent clean-up
       $self->SUPER::DESTROY( @_ );
  } # DESTROY()


=cut

# DESTROY()
#
# Free hash references and keep track of available slots in the
# @__OBJECTS__ array
sub DESTROY : locked
{
	my	$self	= __PACKAGE__->public( shift );

	# delete the hash holding this object's data
	# NB: the @__OBJECTS__ array is maintained at its maximum length
	#     to avoid reallocation when more objects are required
	my	$indx					= ${ $self } - $OFFSET;
	# make sure the index is positive or zero, otherwise we could
	# destroy another object
	if ( $indx >= 0 ) {
		$__OBJECTS__[ $indx ]	= undef;

		# add this index to the list of destroyed indices
		push @__DESTROYED__ , $indx;
	}
} # DESTROY()


=head2 Serialising Objects

B<Class::Declare> objects may be serialised (and therefore cloned) by using
L<Storable>. B<Class::Declare> uses B<Storable::dclone()> itself during
object creation to copy instance attribute values. However, L<Storable>
is unable to serialise C<CODEREF>s, and attempts to do so will fail. This
causes the failure of serialisation of B<Class::Declare> objects that have
C<CODEREF>s as attribute values. However, for cloning, B<Class::Declare>
avoids this problem by simply copying C<CODEREF>s from the original object
to the clone.

=cut
{ # closure for freezing/thawing CODEREFs

	# Storable is unable to freeze/thaw CODEREFs, so here we provide
	# in-memory storage for CODEREFs to create the illusion of being able to
	# handle CODEREFs. This is used to ensure Storable::dclone() works, but
	# is not guaranteed to work for all freeze/thaw combinations (otherwise
	# Storable would have done this a lot sooner), so is disabled for
	# non-cloning invocations.
	my	%__CODEREFS__;	undef %__CODEREFS__;

#
# STORABLE_freeze()
#
# Hook for Storable to freeze Class objects.
sub STORABLE_freeze : locked
{
	my	$self		= __PACKAGE__->public( shift );
	my	$cloning	= shift;

	# make sure we're storing
	Storable::is_storing
		or do {
			my	( undef , $file , $line , $sub )	= caller 0;

			die "Unexpected call to " . __PACKAGE__ . "::$sub() "
			    . "at $file line $line\n";
		};

	#
	# serialise the object
	#
	
	# we only want to freeze the actual @__OBJECTS__ index and the
	# hash, not the offset as this may change between freezing and
	# thawing
	my	$indx		= ${ $self } - $OFFSET;

	# extract the object hash
	my	$hash		= $__OBJECTS__[ $indx ];

	# if we're cloning, then we may have to play with attributes that have
	# CODEREFs as values
	my	$code;		undef $code;
	if ( $cloning ) {

		# if any of the attributes are CODEREFs then store them in %__CODEREFS__
		# and replace their values with a key to the %__CODEREFS__ hash
		#   - a list of attributes with stored CODEREFs is then serialised in
		#       addition to the rest of the object

		# because we may be playing around with the stored CODEREFs we should
		# clone $hash first (not a deep clone, just to the first level)
			$hash		= { %{ $hash } };

		# now, we need to look for CODEREFs and store them in memory
		ATTRIBUTE: foreach ( keys %{ $hash } ) {
			my	$value	= $hash->{ $_ };

			# only interested in CODEREFs
			next ATTRIBUTE		unless (    ref( $value )
			              		         && ref( $value ) eq 'CODE' );

			# now store the coderef in %__CODEREFS__: use the package, attribute
			# and CODEREF itself as the key
			my	$key					= join '=' , ref( $self ) , $_
			  	    					           , $value       , $indx;
				$__CODEREFS__{ $key }	= $value;

			# replace the original CODEREF with the key
				$hash->{ $_ }			= $key;
			# make note of the fact that this attribute has had it's value
			# stashed in the CODEREFs storage
				push @{ $code } , $_;
		}
	}

	# return the object index and the object hash to serialise
	# as well as the list of attributes whose values are CODEREFs and who
	# have had these CODEREFs "serialised" in memory
	return ( defined $code ) ? ( $indx , $hash , $code )
	                         : ( $indx , $hash         );
} # STORABLE_freeze()


# STORABLE_thaw()
#
# Hook for Storable to thaw Class objects.
#   - if possible, the same object index will be used for the
#     recreated object
#   - if the index is currently occupied, then the next available
#     index will be taken.
sub STORABLE_thaw : locked
{
	my	$self		= __PACKAGE__->public( shift );
	my	$cloning	= shift;

	# make sure we're thawing
	Storable::is_retrieving
		or do {
			my	( undef , $file , $line , $sub )	= caller 0;

			die "Unexpected call to " . __PACKAGE__ . "::$sub() "
			    . "at $file line $line\n";
		};

	# OK, @ref should contain the index of the object and a reference
	# to a hash representing the object
	my	( $indx , $hash , $code )	= @_;
	( ref $hash eq 'HASH' )
		or do {
			my	( undef , $file , $line , $sub )	= caller 0;

			die "Corrupt call to " . __PACKAGE__ . "::$sub() "
			    . "at $file line $line\n"
				. "\t(HASH reference expected, got $hash)\n";
		};

	# if the restored index is larger than the size of the
	# @__OBJECTS__ array, then we will need to extend the array,
	# ensuring the indices of the new elements in the array are added
	# to the @__DESTROYED__ array, so that they will be used at a
	# later date
	( $indx > $#__OBJECTS__ )
		and push @__DESTROYED__ , ( $#__OBJECTS__ + 1 ) .. ( $indx - 1 );

	# if this slot has been (or is still allocated) then we need to
	# find the next available slot for recreating this object
	if ( defined $__OBJECTS__[ $indx ] ) {
		$indx	=  shift @__DESTROYED__;
		$indx	= scalar @__OBJECTS__		unless ( defined $indx );
	}

	# ensure this index does not appear in the @__DESTROYED__ array
		@__DESTROYED__			= grep { $_ != $indx } @__DESTROYED__;

	# if we have code references stored in memory and we're cloning,
	# then attempt to retrieve them
	if ( $cloning && defined $code ) {
		foreach ( @{ $code } ) {
			# extract the reference (delete it so that it doesn't consume
			# space ... this will lead to problems if thawing isn't part of
			# a freeze/thaw pair - i.e. cloning - but it's not designed to
			# be robust, just to handle object cloning
			my	$key			= $hash->{ $_ };
			my	$ref			= delete $__CODEREFS__{ $key };

			# now store the CODEREF as the attribute value
				$hash->{ $_ }	= $ref;
		}
	}

	# now we can store the object and recreate it
		$__OBJECTS__[ $indx ]	= $hash;
		${ $self }				= $indx + $OFFSET;

	# that's all folks
} # STORABLE_thaw()

} # end of CODEREFs storage closure


=head2 Miscellaneous Methods

The following methods are class methods of B<Class::Declare> provided to
simplify the creation of classes. They are provided as convenience
methods, and may be called as either class or instance methods.

=over 4

=item B<friend(>B<)>

Returns I<true> if the calling class or method is a friend of the given class
or object. That is, for a given object or class, B<friend()> will return
I<true> if it is called within the context of a class or method that has been
granted friend status by the object or class (see I<friend> in B<declare()>
above). A friend may access I<private>, I<protected>, I<static> and
I<restricted> methods and attributes of a class and it's instances, but not
of derived classes.

B<friend()> will return true for a given class or object if called within
that class. That is, a class is always it's own friend.

In all other circumstances, B<friend()> will return I<false>.

  package Class::A;

  my $object = Class::B;

  sub somesub {
    ...
    $object->private_method   if ( $object->friend );
    ...
  }

=cut
sub friend
{
	# firstly, this is a class method
	my	$self	= __PACKAGE__->class( shift );
	# extract our class name
		$self	= ref( $self ) || $self;

	# extract the calling class and method
	# NB: the calling method is in the call stack before the current
	#     one (i.e. caller 1 not caller 0)
	my	$class	=   caller;
	my	$method	= ( caller 1 )[ 3 ];

	# you should always be a friend to yourself
	return 1			if ( $class eq $self );

	# otherwise, extract the friend declarations for this class
	my	$friend	= $__FRIEND__{ $self };
	# if there's no friend information, then the answer is no
	return undef		unless ( defined $friend );

	# return true only if the class or the method is recorded as a friend
	return (    defined $class  && exists( $friend->{ $class  } )
	         || defined $method && exists( $friend->{ $method } ) );
} # friend()


=item B<dump(> [ I<param> => I<value> ] B<)>

Generate a textual representation of an object or class. Since
B<Class::Declare> objects are represented as references to
scalars, L<Data::Dumper> is unable to generate a meaningful dump of
B<Class::Declare>-derived objects. B<dump()> pretty-prints objects, showing
their attributes and their values. B<dump()> obeys the access control imposed
by B<Class::Declare> on it's objects and classes, limiting it's output to
attributes a caller has been granted access to see or use.

B<dump()> will always observe the access control mechanisms as specified
by B<Class::Declare::class()>, B<Class::Declare::private()>, etc, and it's
behaviour is not altered by the setting of I<strict> in B<declare()> to be
I<false> (see B<declare()> above). This is because I<strict> is designed as
a mechanism to accelerate the execution of B<Class::Declare>-derived modules,
not circumvent the intended access restrictions of those modules.

B<dump()> accepts the following optional named parameters:

=over 4

=item I<all>

If I<all> is true (the default value), and none of the attribute/method type
parameters (e.g. I<public>, I<static>, etc) have been set, then B<dump()>
will display all attributes the caller has access to. If any of the attribute
type parameters have been set to true, then I<all> will be ignored, and only
those attribute types specified in the call to B<dump()> will be displayed.

=item I<class>

If I<class> is true, then B<dump()> will display only I<class> attributes of
the invocant and their values, and all other types of attributes explicitly
requested in the call to B<dump()> (the I<all> parameter is ignored). If the
caller doesn't have access to I<class> methods, then B<dump()> will B<die()>
with an error. If no class attributes exist, and no other attributes have
been requested then C<undef> is returned.

=item I<static>

As with I<class>, but displaying I<static> attributes and their values.

=item I<restricted>

As with I<class>, but displaying I<restricted> attributes and their values.

=item I<public>

As with I<class>, but displaying I<public> attributes and their values. Note
that I<public> attributes can only be displayed for class instances. Requesting
the B<dump()> of public attributes of a class will result in B<dump()>
B<die()>ing with an error.

=item I<private>

As with I<public>, but displaying I<private> attributes and their values.

=item I<protected>

As with I<public>, but displaying I<protected> attributes and their values.

=item I<friends>

If I<friends> is true, then B<dump()> will display the list of friends of
the invoking class or object.

=item I<depth>

By default, B<dump()> operates recursively, creating a dump of all requested
attribute values, and their attribute values (if they themselves are
objects). If I<depth> is set, then I<dump()> will limit it's output to the
given recursive depth. A depth of C<0> will display the target's attributes,
but will not expand those attribute values.

=item I<indent>

I<indent> specifies the indentation used in the output of B<dump()>, and
defaults to C<4> spaces.

=back

If an attribute type parameter, such as I<static> or I<private>, is set
in the call to B<dump()> then this only has effect on the target object
of the B<dump()> call, and not any subsequent recursive calls to B<dump()>
used to display nested objects.

The code to implement B<dump()> is quite long, and so has been split into a
separate module L<Class::Declare::Dump>. The first time B<dump()> is called
on a B<Class::Declare>-derived object or class, B<Class::Declare::Dump> is
loaded, and the dump generated. If the loading of B<Class::Declare::Dump>
fails, a warning is given, and B<dump()> returns the stringification of the
given class or instance.

=cut
sub dump : locked
{
	my	$self	= __PACKAGE__->class( shift );

	# where were we called from, and what are we called?
	my	( undef , $file , $line , $sub )	= caller 0;
	my	$module	= join '::' , map { ucfirst } split '::' ,  $sub;

	#
	# create helper routines that'll be passed to Class::Declare::Dump to
	# grant it (limited) access to the object storage of Class::Declare.
	#
	
	# - create a routine for returning the attribute hash of an object or
	#     class, where the hash values are the current attribute values for
	#     the object, or the default attribute values for the class
	my	$__get_values__	= sub { # <class> | <object>
			my	$self	= shift;
			my	$indx	= undef;

			# make sure we have a valid object
			( ref( $self )
				and ( $indx = ${ $self } - $OFFSET ) >= 0
				and exists $__OBJECTS__[ $indx ]
				# and return the reference to its hash
				and return $__OBJECTS__[ $indx ] )
				# or return the default values for this class
				 or return  $__DEFN__{ $self };
		}; # $__get_values__()

	
	# - create a routine for returning the declared attributes of a given
	#     class or object
	my	$__get_attributes__	= sub { # <class> | <object>
			my	$self	= shift;

			return   $__ATTR__{ ref( $self ) || $self };
		}; # $__get_attributes__()

	
	# - create a routine for returning the list of friends of a given class
	#     or object
	my	$__get_friends__	= sub { # <class> | <object>
			my	$self	= shift;

			return $__FRIEND__{ ref( $self ) || $self };
		}; # $__get_friends__()


	# attempt to load the Class::Declare::Dump module
	# NB: The dump() method in Class::Declare::Dump overwrites this
	#     method, so that future calls to Class::Declare::dump() do
	#     not execute this code, but rather the intended dump() code.
	#
	#     Because Class::Declare::Dump needs access to @__OBJECTS__,
	#     %__ATTR__ and %__FRIEND__, we need to somehow make them
	#     available to Class::Declare::Dump, even though they are "my"
	#     variables in Class::Declare. One option would be to use the
	#     access control methods that Class::Declare provides to create
	#     accessor methods, but this would mean further polluting the
	#     symbol table with a method to pass this information, and
	#     possibly leave us open to attacks (not sure who would want to
	#     attack this, but we're trying to design this so it's secure).
	#     Instead, we simply pass references to anonymous subroutines to
	#     Class::Declare::Dump::__init__() that permit access to these
	#     variables.
	#
	#     __init__() conditionally defines local variables to the
	#     references given, and then, to make sure it is not called
	#     again, removes itself from the symbol table. It then
	#     overwrites the symbol table entry for
	#     Class::Declare::dump() with the entry for
	#     Class::Declare::Dump::dump(), as outlined above.
	#
	#     Yes, this is a bit of a hack, but it works :) The aim of
	#     the hack is to grant access to variables that really
	#     shouldn't be accessed outside this file (hence the
	#     closure), but because we don't want the dump() code to be
	#     loaded all the time (only when necessary), we cheat a
	#     little :)
	eval "require $module"
		and $module->__init__( $__get_attributes__ ,
		                       $__get_values__     ,
							   $__get_friends__    )
		 # the module wasn't found, so raise a warning and return the
		 # normal stringification of the object/class
		 or warn "Unable to load $module in call to $sub at $file line $line\n"
		        . "$@\n"	# give the original error message
		and return "$self";	# simply return the stringified object

	# OK, the module was loaded, which will replace this subroutine
	# in the symbol table, so call ourselves and we'll execute the
	# proper dump() routine
	{
		no strict 'refs';

		unshift @_ , $self;
		goto &{ $sub };
	}
} # dump()

} # end Class admin closure


=item B<arguments(> I<args> => I<default> B<)>

A class helper method for handling named argument lists. In Perl, named
argument lists are supported by coercing a list into a hash by assuming a
key/value pairing. For example, named arguments may be implemented as

  sub mysub {
    my  %args = @_;
    ...
  }

and called as

  mysub( name => 'John' , age => 34 );

C<%args> is now the hash with keys C<name> and C<age> and corresponding
values C<'John'> and C<34> respectively.

So if named arguments are so easy to implement, why go to the trouble of
calling B<arguments()>? To make your code more robust. The above
example failed to test whether there was an even number of elements in
the argument list (needed to flatten the list into a hash), and it made
no checks to ensure the supplied arguments were expected. Does C<mysub()>
really want a name and age, or does it want some other piece of information?

B<arguments()> ensures the argument list can be safely flattened into a
hash, and raises an error indicating the point at which the original method
was called if it can't. Also, it ensures the arguments passed in are those
expected by the method. Note that this does not check the argument values
themselves, but merely ensures unknown named arguments are flagged as errors.

B<arguments()> also enables you to define default values for your
arguments. These values will be assigned when a named argument is not supplied
in the list of arguments.

The calling convention of B<arguments()> is as follows (note, we assume here
that the method is in a B<Class::Declare>-derived class):

  sub mysub {
    ...
    my %args = $self->arguments( \@_ => { name => 'Guest user' ,
                                          age  => undef        } );
    ...
  }

Here, C<mysub()> will accept two arguments, C<name> and C<age>, where
the default value for C<name> is C<'Guest user'>, while C<age> defaults
to C<undef>.

Note that the argument I<args> is a reference to the caller's argument list,
and I<default> is a reference to a hash defining the expected argument
names and their default values. If I<default> is not given (or is undef),
then B<arguments()> will simply flatten the argument list into a hash and
assume that all named arguments are valid. If I<default> is the empty hash
(i.e. C<{}>), then no named arguments will be accepted.

If called in a list context, B<arguments()> returns the argument hash, while if
called in a scalar context, B<arguments()> will return a reference to the hash.
B<arguments()> may be called as either a class or instance method.

=cut
sub arguments
{
	my	$self		= __PACKAGE__->class( shift );

	# if we have no arguments then we should return undef
	return undef		unless ( @_ );

	# extract the argument list and the default arguments
	my	$args		= shift;
	my	$default	= shift;

	# make sure the first argument is a reference to an array
	( ref( $args ) && ref( $args ) eq 'ARRAY' )
		or do {
			my	( undef , $file , $line , $sub )	= caller 1;

			die "Array reference expected in call to "
			    . "$sub() at $file line $line\n";
		};

	# to make a hash we need to ensure we have an even number of
	# arguments
	( scalar( @{ $args } ) % 2 )
		and do {
			my	( undef , $file , $line , $sub )	= caller 1;

			die "Odd number of arguments to $sub() at $file line $line\n";
		};

	# convert the argument list into a hash
		$args	= { @{ $args } };

	# if there is a set of default arguments defined, then make sure
	# the given arguments conform, otherwise, accept whatever
	# arguments we're given
	if ( defined $default ) {
		# make sure default is a hash reference
		( ref( $default ) eq 'HASH' )
			or do {
				my	( undef , $file , $line , $sub )	= caller 0;

				die "Default arguments must be a hash reference at "
				    . "$sub() file $file line $line\n";
			};

		# make sure there are no keys in the given argument list that
		# are not defined in the default argument list
		foreach ( keys %{ $args } ) {
			next	if ( exists $default->{ $_ } );

			# key doesn't exist, so die with an error
			my	( undef , $file , $line , $sub )	= caller 1;

			die "Unknown parameter '$_' used in call to $sub() "
			    . "at $file line $line\n";
		}

		# for each default argument that isn't declared in the given
		# argument list, add it to the called argument list
		$args->{ $_ }	= $default->{ $_ }
			foreach ( grep { ! exists $args->{ $_ } } keys %{ $default } );
	}

	# return the argument hash
	return ( wantarray ) ? %{ $args } : $args;
} # arguments()


=item B<REVISION(>B<)>

Extract the revision number from CVS revision strings. B<REVISION()> looks
for the package variable C<$REVISION> for a valid CVS revision strings, and
if found, will return the revision number from the string. If $REVISION is
not defined, or does not contain a CVS revision string, then B<REVISION()>
returns C<undef>.

  package My::Class;

  use strict;
  use base qw( Class::Declare );
  use vars qw( $REVISION      );
               $REVISION = '$Revision: 1.37 $';

  ...

  1;


  print My::Class->REVISION;	# prints the revision number

=cut
sub REVISION
{
	my	$self		= __PACKAGE__->class( shift );

	# try to find the revision string
	my	$revision	= undef;
	{
		local	$@;
		eval {
			no strict 'refs';

			$revision	= ${ $self . '::REVISION' };
		};
	}

	# if there's no revision string, then return undef
	return undef		unless ( $revision );

	# OK, now attempt to extract the revision number from the string
	#    - because we don't want to expose ourselves to CVS keyword
	#      expansion, we need to construct our target pattern
	my	$target	= ucfirst( 'revision' );
	return undef		unless ( $revision =~ m#\$$target:\s*(\S+)\s*\$#o );

	# extract the revision number
		$revision	= $1;
	# make sure the revision number starts with a digit
		$revision	= undef		unless ( $revision =~ m#^\d#o );

	# return the revision number
	return $revision;
} # REVISION()


=item B<VERSION(>B<)>

Replacement for B<UNIVERSAL::VERSION()>, that falls back to B<REVISION()>
to report the CVS revision number as the version number if the package
variable C<$VERSION> is not defined.

=cut
sub VERSION
{
	my	$self	= __PACKAGE__->class( shift );

	# extract the normal version information (if it exists)
	my	$version	  = $self->SUPER::VERSION;
	# if the version number isn't defined, then return the REVISION
	# number (which might not be defined, also)
	return ( defined $version ) ? $version : $self->REVISION;
} # VERSION()


=item B<has(> I<method> B<)>

If this class directly implements the given I<method>(), then return a
reference to this method. Otherwise, return false. This is similar to
B<UNIVERSAL::>B<can()>, which will return a reference if this class either
directly implements I<method>(), or inherits it.

=cut
sub has
{
	my	$self	= __PACKAGE__->class( shift );
	# if there's no method name, then raise an error
	my	$method	= shift
					or do {
						# find out where we were called from
						my	( undef , $file , $line )	= caller;

						die "no method name supplied in call to can() "
						    . "at $file line $line\n";
					};

	# extract the symbol table entry for this method
	{
		local	$@;
		my		$class	= ref( $self ) || $self;
		local	*glob	= eval '$' . $class . '::{ ' . $method . ' }'
									|| return undef;

		# if something has gone wrong, raise a warning and return undef
		warn	and return undef		if ( $@ );
		
		# if we have a subroutine defined, then return the reference
		# otherwise, return undef
		return ( defined &glob ) ? \&glob : undef;
	}
} # has()


=back


=head1 CAVEAT

B<Class::Declare> has been designed to be thread-safe, and as such is suitable
for such environments as C<mod_perl>. However, it has not been proven to be
thread-safe. If you are coding in a threaded environment, and experience
problems with B<Class::Declare>'s behaviour, please let me know.


=head1 BUGS

The name. I don't really like B<Class::Declare> as a name, but I can't
think of anything more appropriate. I guess it really doesn't matter too
much. Suggestions welcome.

Apart from the name, B<Class::Declare> has no known bugs. That is not to say
the bugs don't exist, rather they haven't been found. The testing for this
module has been quite extensive (there are over 2500 test cases in the module's
test suite), but patches are always welcome if you discover any problems.


=head1 SEE ALSO

L<Class::Declare::Dump>, L<Class::Declare::Attributes>, L<Exporter>,
L<Storable>, L<perlboot>, L<perltoot>.


=head1 AUTHOR

Ian Brayshaw, E<lt>ian@onemore.orgE<gt>


=head1 COPYRIGHT AND LICENSE

Copyright 2003 by Ian Brayshaw. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself. 

=cut

################################################################################
1;	# end of module
__END__
