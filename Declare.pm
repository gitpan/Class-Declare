package Class::Declare;

use 5.006;
no warnings;

use Exporter;
use Carp;
use Symbol ();

our @ISA = qw(Exporter);

# Yeah, I export a bunch by default.  So what?  Wanna fight about it?
our @EXPORT = qw{
    has
    public
    method
    accessor
    extends
    destroy
};

our $VERSION = '0.10';

my @SCAN;
our $VTABLE;
our $PACKAGE;

sub import {
    my ($class) = @_;
    my $package = caller;
    push @SCAN, $package;
    goto &Exporter::import;
}

sub _make_new {
    my ($code) = @_;
    sub {
        my $base = ref $_[0] || $_[0];
        local $PACKAGE = _make_package();
        local $VTABLE = bless { } => $PACKAGE;
        my $package = $PACKAGE;

        @{"$PACKAGE\::ISA"} = ($base);

        *{"$PACKAGE\::DESTROY"} = sub { 
            for (@{"$package\::REBLESSED"}) {  # bless them back into their original class
                bless $_->[0] => $_->[1];
            }
            Symbol::delete_package($package); 
        };

        *{"$PACKAGE\::isa"} = sub {
            my ($self, $class) = @_;
            return 1 if $base->isa($class);
            for (@{"$package\::SUBISA"}) {
                return 1 if $_->isa($class);
            }
            return;
        };

        *{"$PACKAGE\::can"} = sub {
            my ($self, $method) = @_;
            if (my $code = *{"$package\::$method"}{CODE}) {
                return $code;
            }
            else {
                for my $pack (@{"$package\::SUBISA"}) {
                    my $packobj = ${"$package\::SUBOBJ"}{$pack};
                    my $can = "$pack\::can";
                    if (my $code = $pack->can($method)) {
                        return *{"$package\::$method"} = sub { 
                            @_ = ($packobj, @_[1..$#_]);
                            goto &$code;
                        };
                    }
                }
            }
            return;            
        };

        *{"$PACKAGE\::AUTOLOAD"} = sub {
            $AUTOLOAD =~ s/.*:://;
            if (my $code = $_[0]->can($AUTOLOAD)) {
                goto &$code;
            }
            elsif (my $fallback = $_[0]->can('FALLBACK')) {
                local *{"$base\::AUTOLOAD"} = \$AUTOLOAD;
                goto &$fallback;
            }
            else {
                croak "Method $AUTOLOAD not found in class $base";
            }
        };

        $code->(@_);

        $VTABLE->can('BUILD') && $VTABLE->BUILD(@_[1..$#_]);

        $VTABLE;
    };
}

{
my $counter = 0;
sub _make_package {
    "Class::Declare::_package_" . $counter++;
}
}

sub has($\$) : lvalue {
    my ($name, $var) = @_;
    *{"$PACKAGE\::$name"} = sub ($) { $$var };
    $$var;
}

sub public($\$) : lvalue {
    my ($name, $var) = @_;
    eval <<EOC;
        package $PACKAGE;
        sub $name (\$) : lvalue { \$\$var }
EOC
    $$var;
}

sub method($&) {
    my ($name, $code) = @_;
    *{"$PACKAGE\::$name"} = $code;
    return;
}

sub accessor($@) {
    my ($name, %pairs) = @_;
    croak "accessor needs 'get' and 'set' attributes" unless $pairs{get} && $pairs{set};
    eval <<EOC;
        package $PACKAGE;
        sub $name (\$) : lvalue { 
            tie my \$del => Class::Declare::LValueDelegate, 
                    \$_[0], \$pairs{get}, \$pairs{set};
            \$del;
        }
EOC
    return;
}

sub extends($) {
    my ($var) = @_;
    
    unless (ref $var) {
        $var = $var->new;
    }

    my $pack = ref $var;
    bless $var => $PACKAGE;  # Rebless for virtual behavior
    push @{"$PACKAGE\::REBLESSED"}, [ $var => $pack ];  # bookkeeping for DESTROY

    push @{"$PACKAGE\::SUBISA"}, $pack;
    ${"$PACKAGE\::SUBOBJ"}{$pack} = $var;

    return;
}

sub destroy(&) {
    ${"$PACKAGE\::DESTROY"} = Class::Declare::DestroyDelegate->new($_[0]);
}

CHECK {
    for my $package (@SCAN) {
        *{"$package\::new"} = _make_new(\&{"$package\::CLASS"});
    }
}

package Class::Declare::DestroyDelegate;

sub new {
    my ($class, $code) = @_;
    bless $code => ref $class || $class;
}

sub DESTROY {
    goto &{$_[0]};
}

package Class::Declare::LValueDelegate;

sub TIESCALAR {
    my ($class, $ref, $get, $set) = @_;
    bless { ref => $ref, get => $get, set => $set } => $class;
}

sub FETCH {
    $_[0]->{get}->($ref);
}

sub STORE {
    $_[0]->{set}->($ref, $_[1]);
}

1;

=head1 NAME

Class::Declare - Encapsulated, declarative class style

=head1 SYNOPSIS

    package Dog;

    use Class::Declare;

    sub CLASS {
        extends Foo::Bar;           # Inherit from another class
        
        extends $some_object;       # Inherit from a single object (classless)
        
        my $hungry;                 # private
        
        has face => my $face;       # read-only
        
        public leash => my $leash;  # public
        
        accessor 'food',            # magical variable-like function
            get => sub { 'None' },
            set => sub { $hungry = 0; };
        
        method bark => sub { print "Woof!" };   # method (note the semicolon)
        
        method BUILD => sub { print "A new dog is born" };  # constructor

        destroy { print "Short is the life of a dog" };  # destructor

        method AUTOLOAD => sub { print "Huh?" };  # AUTOLOAD is allowed, too
    }

    my $fido = Dog->new;   # "A new dog is born"
    $fido->face;           # Get a read-only attribute
    $fido->leash = 'red';  # public attributes look like variables
    $fido->food = 20;      # This calls the food set accessor

=head1 DESCRIPTION

Class::Declare is a package that makes creating Perl classes less 
cumbersome. You can think of it as a more featureful Class::Struct.

To declare a class using Class::Declare, enter a new package, use 
Class::Declare, and define a sub called CLASS.  Inside this sub lie
the declarations for the attributes and methods (and subclasses)
for this class.

=head2 Variables

To declare variables, you mark them as lexicals within the sub.  You may
prefix them with C<has> and a name to make them read-only or C<public>
and a name to make them fully read-write public.

    sub CLASS {
        my $x;             # private
        has y => my $y;    # read-only
        public z => my $z; # public
    }

It's not necessary that their "external" name (the one before the C<< =>
>>) be the same as the variable's name, but it is recommended.
Presently only scalars are handled by C<has> and C<public>; you have to
define an L<accessor|/Accessors> to specify the semantics you want.

You can give the variables a default value by assigning to the whole
declaration.  For simple private variables this is easy, for read-only
and public variables, it requires extra parentheses:

    sub CLASS {
        my $x = 1;
        has(y => my $y) = 2;
        public(z => my $z) = 3;
    }

To use these variables within the class, use their plain lexical name
with the sigil.  To use them outside the class, call them as methods.
Given the class above:

    $obj->x;      # Illegal; private
    $obj->y;      # Ok, 2.
    $obj->z;      # Ok, 3.
    $obj->z = 32; # Write to $z.

This may be a little different from the usual C<< $obj->z(32) >> syntax
you might be used to.  Trust me, this will grow on you.

=head2 Methods

To declare methods, use the C<method> keyword and pass a name and a
reference to a sub:

    sub CLASS {
        method bark => sub {
            print "Woof!\n";
        };
    }

The invocant is still passed in as the first argument as in old-style
OO.  The fact is, though, that many times you won't need it, since you
can reference the member variables without it.  You still need it to
call functions on yourself, though.

    sub CLASS {
        method chase_tail => sub {
            my ($self) = @_;
            $self->chase($self->find_tail);
        };
    }

=head2 Accessors

Sometimes a change of interface goes from using a public variable to a function
with extra behavior.  Some would say that's why you never make a member
variable public.  I disagree, since you can just fake one with the C<accessor>
keyword:

    sub CLASS {
        accessor 'number',
                get { print "Getting the number";  42; },
                set { print "Setting the number";  $_[0]->send($_[1]) };
    }
    print $obj->number;  # "Getting the number"  "42"
    $obj->number = 314;  # "Setting the number" ...

=head2 Inheritance

Unlike the standard Perl 5 object model, Class::Declare can inherit from both
classes and variables (like Class::Classless).  Also, it keeps their respective
namespaces separate, so they don't accidentally stomp on each other's member
variables, even if they're implemented with the standard object model. 

To inherit, use the C<extends> keyword.  It can take as an argument either a
class name (make sure you quote it lest you confuse Perl) or an object.  If you
need to pass construction parameters to your superclass, just inherit from it
as an object:

    sub CLASS {
        extends MySuperClass->new(@params);
    }

=head2 Constructors and Destructors

The special method BUILD is called whenever a new object is created, with the
blessed object in the first argument and the rest of the construction
parameters in the remaining arguments.

Destructors are a little different.  Because of the magic that Class::Declare
has to do to get them to work with inheritance, they have a special syntax:

    sub CLASS {
        destroy { print "Destructing object"; }
    }

Yep, that's all.  And you heard me correctly, they work right with inheritance,
unlike the standard C<DESTROY> method.

=head2 FALLBACK

Class::Declare supports an C<AUTOLOAD> feature.  But because it uses
C<AUTOLOAD> internally, it has to call it something else.  It's called
C<FALLBACK>, and it works just like C<AUTOLOAD> in every way (the name of the
current sub is still even in C<$AUTOLOAD>).

=head2 How does it work?

If you really want to get scary power out of this module, you have to
understand how it works. 

The C<CLASS> sub that you defined in your package is actually called every time
an object is created.  That's right, so there's no need for a C<BUILD> at all
(but it makes things look cleaner).  Class::Declare exports each one of these
"keywords" into your namespace, and they are used right on the spot to
construct the object each time.

This way each object's member hash is actually a lexical scratchpad, and it
keeps track of where it is, so you don't have to reference C<$self> all the
time.  It has the added plus that each object in an inheritance heirarchy has
it's own scratchpad, so you don't get variable name conflicts.

In more detail, when you call new on your package, it derives a new anonymous
package for only that object.  Then when you use C<method> (or C<has> or
C<public> or C<attribute>, which are really just wrappers around the same
thing), it installs the sub you give into the symbol table position.  These
closure's aren't "cloned", but just referenced, so this doesn't take up the
horrible amount of memory you might be thinking it does.

Then when all references to the object disappear, it uses L<Symbol>'s
C<delete_package> to clean out the anonymous package and free memory (and more
importantly, call C<DESTROY>s) associated with the object.

What does this all mean for you, the user?  Since you understand that these
"declarations" are just sub calls at object construction time, you can create
your objects based on a dynamic template:

    sub CLASS {
        my ($class, $mode) = @_;

        if ($mode == 1) {
            method foo => sub { ... };
            method bar => sub { ... };
        }
        else {
            method foo => sub { ... };
            method bar => sub { ... };
        }
    }

That avoids a run-time check on each of the method calls, and makes things a
little easier to read.  There's all kinds of other fun stuff you can do.

=head2 Technical Notes / Bugs / Caveats / Etc.

The benchmarks say that Class::Declare has 50% less overhead than the
traditional object model.  Yes, that's right, Class::Declare, in addition to
being super-cool, encapsulated, and easy to read, is I<faster> than what you'd
get if you did it the traditional way!  It surprised me too.  On the other
hand, you sacrifice quite a lot of object construction time for this trade-off.

You might get in trouble if you try to define method names the same as the
exported keyword names.

There are certainly more bugs, since this is complex, subtle, scary code.  Bug
reports/patches welcome.

=head1 SEE ALSO

L<Class::Struct>, L<Class::Classless>

=head1 AUTHOR

Luke Palmer - luke at luqui dot org

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself. 
 
=cut
