# $Id: Accessor.pm,v 1.1 2004/02/16 19:24:38 daniel Exp $

package Class::Accessor;

require 5.00502;

use strict;

# Using Carp::Assert adds noticably to the load time, and it seemed silly
# for such a small module.
# use Carp::Assert

use vars qw($VERSION);
$VERSION = '0.18';

=pod

=head1 NAME

  Class::Accessor - Automated accessor generation


=head1 SYNOPSIS

  package Foo;

  use base qw(Class::Accessor);
  Foo->mk_accessors(qw(this that whatever));

  # Meanwhile, in a nearby piece of code!
  # Class::Accessor provides new().
  my $foo = Foo->new;

  my $whatever = $foo->whatever;    # gets $foo->{whatever}
  $foo->this('likmi');              # sets $foo->{this} = 'likmi'
  
  # Similar to @values = @{$foo}{qw(that whatever)}
  @values = $foo->get(qw(that whatever));
  
  # sets $foo->{that} = 'crazy thing'
  $foo->set('that', 'crazy thing');


=head1 DESCRIPTION

This module automagically generates accessor/mutators for your class.

Most of the time, writing accessors is an exercise in cutting and
pasting.  You usually wind up with a series of methods like this:

  # accessor for $obj->{foo}
  sub foo {
      my($self) = shift;

      if(@_ == 1) {
          $self->{foo} = shift;
      }
      elsif(@_ > 1) {
          $self->{foo} = [@_];
      }

      return $self->{foo};
  }


  # accessor for $obj->{bar}
  sub bar {
      my($self) = shift;

      if(@_ == 1) {
          $self->{bar} = shift;
      }
      elsif(@_ > 1) {
          $self->{bar} = [@_];
      }

      return $self->{bar};
  }

  # etc...

One for each piece of data in your object.  While some will be unique,
doing value checks and special storage tricks, most will simply be
exercises in repetition.  Not only is it Bad Style to have a bunch of
repetitious code, but its also simply not Lazy, which is the real
tragedy.

If you make your module a subclass of Class::Accessor and declare your
accessor fields with mk_accessors() then you'll find yourself with a
set of automatically generated accessors which can even be
customized!

The basic set up is very simple:

    package My::Class;
    use base qw(Class::Accessor);
    My::Class->mk_accessors( qw(foo bar car) );

Done.  My::Class now has simple foo(), bar() and car() accessors
defined.

=head2 What Makes This Different?

What makes this module special compared to all the other method
generating modules (L<"SEE ALSO">)?  By overriding the get() and set()
methods you can alter the behavior of the accessors class-wide.  Also,
the accessors are implemented as closures which should cost a bit less
memory than most other solutions which generate a new method for each
accessor.


=head2 Methods

=over 4

=item B<new>

    my $obj = Class->new;
    my $obj = $other_obj->new;

    my $obj = Class->new(\%fields);
    my $obj = $other_obj->new(\%fields);

Class::Accessor provides a basic constructor.  It generates a
hash-based object and can be called as either a class method or an
object method.  

It takes an optional %fields hash which is used to initialize the
object (handy if you use read-only accessors).  The fields of the hash
correspond to the names of your accessors, so...

    package Foo;
    use base qw(Class::Accessor);
    Foo->mk_accessors('foo');

    my $obj = Class->new({ foo => 42 });
    print $obj->foo;    # 42

however %fields can contain anything, new() will shove them all into
your object.  Don't like it?  Override it.

=cut

sub new {
    my($proto, $fields) = @_;
    my($class) = ref $proto || $proto;

    $fields = {} unless defined $fields;

    # make a copy of $fields.
    bless {%$fields}, $class;
}

=pod

=item B<mk_accessors>

    Class->mk_accessors(@fields);

This creates accessor/mutator methods for each named field given in
@fields.  Foreach field in @fields it will generate two accessors.
One called "field()" and the other called "_field_accessor()".  For
example:

    # Generates foo(), _foo_accessor(), bar() and _bar_accessor().
    Class->mk_accessors(qw(foo bar));

See L<CAVEATS AND TRICKS/"Overriding autogenerated accessors">
for details.

=cut

#'#
sub mk_accessors {
    my($self, @fields) = @_;

    $self->_mk_accessors('make_accessor', @fields);
}


{
    no strict 'refs';

    sub _mk_accessors {
        my($self, $maker, @fields) = @_;
        my $class = ref $self || $self;

        # So we don't have to do lots of lookups inside the loop.
        $maker = $self->can($maker) unless ref $maker;

        foreach my $field (@fields) {
            if( $field eq 'DESTROY' ) {
                require Carp;
                &Carp::carp("Having a data accessor named DESTROY  in ".
                             "'$class' is unwise.");
            }

            my $accessor = $self->$maker($field);
            my $alias = "_${field}_accessor";

            *{$class."\:\:$field"}  = $accessor
              unless defined &{$class."\:\:$field"};

            *{$class."\:\:$alias"}  = $accessor
              unless defined &{$class."\:\:$alias"};
        }
    }
}

=pod

=item B<mk_ro_accessors>

=item B<mk_readonly_accessors>

  Class->mk_ro_accessors(@read_only_fields);

Same as mk_accessors() except it will generate read-only accessors
(ie. true accessors).  If you attempt to set a value with these
accessors it will throw an exception.  It only uses get() and not
set().

    package Foo;
    use base qw(Class::Accessor);
    Class->mk_ro_accessors(qw(foo bar));

    # Let's assume we have an object $foo of class Foo...
    print $foo->foo;  # ok, prints whatever the value of $foo->{foo} is
    $foo->foo(42);    # BOOM!  Naughty you.


=cut

sub mk_ro_accessors {
    my($self, @fields) = @_;

    $self->_mk_accessors('make_ro_accessor', @fields);
}

=pod

=item B<mk_wo_accessors>

  Class->mk_wo_accessors(@write_only_fields);

Same as mk_accessors() except it will generate write-only accessors
(ie. mutators).  If you attempt to read a value with these accessors
it will throw an exception.  It only uses set() and not get().

B<NOTE> I'm not entirely sure why this is useful, but I'm sure someone
will need it.  If you've found a use, let me know.  Right now its here
for orthoginality and because its easy to implement.

    package Foo;
    use base qw(Class::Accessor);
    Class->mk_wo_accessors(qw(foo bar));

    # Let's assume we have an object $foo of class Foo...
    $foo->foo(42);      # OK.  Sets $self->{foo} = 42
    print $foo->foo;    # BOOM!  Can't read from this accessor.

=cut

sub mk_wo_accessors {
    my($self, @fields) = @_;

    $self->_mk_accessors('make_wo_accessor', @fields);
}

=pod

=back

The rest is details.

=head1 DETAILS

An accessor generated by Class::Accessor looks something like
this:

    # Your foo may vary.
    sub foo {
        my($self) = shift;
        if(@_) {    # set
            return $self->set('foo', @_);
        }
        else {
            return $self->get('foo');
        }
    }

Very simple.  All it does is determine if you're wanting to set a
value or get a value and calls the appropriate method.
Class::Accessor provides default get() and set() methods which
your class can override.  They're detailed later.

=head2 Modifying the behavior of the accessor

Rather than actually modifying the accessor itself, it is much more
sensible to simply override the two key methods which the accessor
calls.  Namely set() and get().

If you -really- want to, you can override make_accessor().

=over 4

=item B<set>

    $obj->set($key, $value);
    $obj->set($key, @values);

set() defines how generally one stores data in the object.

override this method to change how data is stored by your accessors.

=cut

sub set {
    my($self, $key) = splice(@_, 0, 2);

    if(@_ == 1) {
        $self->{$key} = $_[0];
    }
    elsif(@_ > 1) {
        $self->{$key} = [@_];
    }
    else {
        require Carp;
        &Carp::confess("Wrong number of arguments received");
    }
}


=pod

=item B<get>

    $value  = $obj->get($key);
    @values = $obj->get(@keys);

get() defines how data is retreived from your objects.

override this method to change how it is retreived.

=cut

sub get {
    my($self) = shift;

    if(@_ == 1) {
        return $self->{$_[0]};
    }
    elsif( @_ > 1 ) {
        return @{$self}{@_};
    }
    else {
        require Carp;
        &Carp::confess("Wrong number of arguments received.");
    }
}

=item B<make_accessor>

    $accessor = Class->make_accessor($field);

Generates a subroutine reference which acts as an accessor for the given
$field.  It calls get() and set().

If you wish to change the behavior of your accessors, try overriding
get() and set() before you start mucking with make_accessor().

=cut

sub make_accessor {
    my($class, $field) = @_;

    # Build a closure around $field.
    return sub {
        my($self) = shift;

        if(@_) {
            return $self->set($field, @_);
        }
        else {
            return $self->get($field);
        }
    };
}

=pod

=item B<make_ro_accessor>

    $read_only_accessor = Class->make_ro_accessor($field);

Generates a subroutine refrence which acts as a read-only accessor for
the given $field.  It only calls get().

Override get() to change the behavior of your accessors.

=cut

sub make_ro_accessor {
    my($class, $field) = @_;

    return sub {
        my($self) = shift;

        if(@_) {
            my $caller = caller;
            require Carp;
            Carp::croak("'$caller' cannot alter the value of '$field' on ".
                        "objects of class '$class'");
        }
        else {
            return $self->get($field);
        }
    };
}

=pod

=item B<make_wo_accessor>

    $read_only_accessor = Class->make_wo_accessor($field);

Generates a subroutine refrence which acts as a write-only accessor
(mutator) for the given $field.  It only calls set().

Override set() to change the behavior of your accessors.

=cut

sub make_wo_accessor {
    my($class, $field) = @_;

    return sub {
        my($self) = shift;

        unless (@_) {
            my $caller = caller;
            require Carp;
            Carp::croak("'$caller' cannot access the value of '$field' on ".
                        "objects of class '$class'");
        }
        else {
            return $self->set($field, @_);
        }
    };
}

=pod

=back

=head1 EFFICIENCY

Class::Accessor does not employ an autoloder, thus it is much faster
than you'd think.  Its generated methods incur no special penalty over
ones you'd write yourself.

Here's the results of benchmarking Class::Accessor,
Class::Accessor::Fast, a hand-written accessor and direct hash access
(generated by examples/bench).

  Benchmark: timing 500000 iterations of By Hand - get, By Hand - set, 
    C::A - get, C::A - set, C::A::Fast - get, C::A::Fast - set, 
    Direct - get, Direct - set...

  By Hand - get:  4 wallclock secs ( 5.09 usr +  0.00 sys =  5.09 CPU) 
                  @ 98231.83/s (n=500000)
  By Hand - set:  5 wallclock secs ( 6.06 usr +  0.00 sys =  6.06 CPU) 
                  @ 82508.25/s (n=500000)
  C::A - get:  9 wallclock secs ( 9.83 usr +  0.01 sys =  9.84 CPU) 
               @ 50813.01/s (n=500000)
  C::A - set: 11 wallclock secs ( 9.95 usr +  0.00 sys =  9.95 CPU) 
               @ 50251.26/s (n=500000)
  C::A::Fast - get:  6 wallclock secs ( 4.88 usr +  0.00 sys =  4.88 CPU) 
                     @ 102459.02/s (n=500000)
  C::A::Fast - set:  6 wallclock secs ( 5.83 usr +  0.00 sys =  5.83 CPU) 
                     @ 85763.29/s (n=500000)
  Direct - get:  0 wallclock secs ( 0.89 usr +  0.00 sys =  0.89 CPU) 
                 @ 561797.75/s (n=500000)
  Direct - set:  2 wallclock secs ( 0.87 usr +  0.00 sys =  0.87 CPU) 
                 @ 574712.64/s (n=500000)

So Class::Accessor::Fast is just as fast as one you'd write yourself
while Class::Accessor is twice as slow, a price paid for flexibility.
Direct hash access is about six times faster, but provides no
encapsulation and no flexibility.

Of course, its not as simple as saying "Class::Accessor is twice as
slow as one you write yourself".  These are benchmarks for the
simplest possible accessor, if your accessors do any sort of
complicated work (such as talking to a database or writing to a file)
the time spent doing that work will quickly swamp the time spend just
calling the accessor.  In that case, Class::Accessor and the ones you
write will tend to be just as fast.


=head1 EXAMPLES

Here's an example of generating an accessor for every public field of
your class.

    package Altoids;
    
    use base qw(Class::Accessor Class::Fields);
    use fields qw(curiously strong mints);
    Altoids->mk_accessors( Altoids->show_fields('Public') );

    sub new {
        my $proto = shift;
        my $class = ref $proto || $proto;
        return fields::new($class);
    }

    my Altoids $tin = Altoids->new;

    $tin->curiously('Curiouser and curiouser');
    print $tin->{curiously};    # prints 'Curiouser and curiouser'

    
    # Subclassing works, too.
    package Mint::Snuff;
    use base qw(Altoids);

    my Mint::Snuff $pouch = Mint::Snuff->new;
    $pouch->strong('Fuck you up strong!');
    print $pouch->{strong};     # prints 'Fuck you up strong!'


Here's a simple example of altering the behavior of your accessors.

    package Foo;
    use base qw(Class::Accessor);
    Foo->mk_accessor(qw(this that up down));

    sub get {
        my($self, @keys) = @_;

        # Note every time someone gets some data.
        print STDERR "Getting @keys\n";

        $self->SUPER::get(@keys);
    }

    sub set {
        my($self, $key, @values) = @_;

        # Note every time someone sets some data.
        print STDERR "Setting $key to @values\n";

        $self->SUPER::set($key, @values);
    }


=head1 CAVEATS AND TRICKS

Class::Accessor has to do some internal wackiness to get its
job done quickly and efficiently.  Because of this, there's a few
tricks and traps one must know about.

Hey, nothing's perfect.

=head2 Don't make a field called DESTROY

This is bad.  Since DESTROY is a magical method it would be bad for us
to define an accessor using that name.  Class::Accessor will
carp if you try to use it with a field named "DESTROY".

=head2 Overriding autogenerated accessors

You may want to override the autogenerated accessor with your own, yet
have your custom accessor call the default one.  For instance, maybe
you want to have an accessor which checks its input.  Normally, one
would expect this to work:

    package Foo;
    use base qw(Class::Accessor);
    Foo->mk_accessors(qw(email this that whatever));

    # Only accept addresses which look valid.
    sub email {
        my($self) = shift;
        my($email) = @_;

        if( @_ ) {  # Setting
            require Email::Valid;
            unless( Email::Valid->address($email) ) {
                carp("$email doesn't look like a valid address.");
                return;
            }
        }

        return $self->SUPER::email(@_);
    }

There's a subtle problem in the last example, and its in this line:

    return $self->SUPER::email(@_);

If we look at how Foo was defined, it called mk_accessors() which
stuck email() right into Foo's namespace.  There *is* no
SUPER::email() to delegate to!  Two ways around this... first is to
make a "pure" base class for Foo.  This pure class will generate the
accessors and provide the necessary super class for Foo to use:

    package Pure::Organic::Foo;
    use base qw(Class::Accessor);
    Pure::Organic::Foo->mk_accessors(qw(email this that whatever));

    package Foo;
    use base qw(Pure::Organic::Foo);

And now Foo::email() can override the generated
Pure::Organic::Foo::email() and use it as SUPER::email().

This is probably the most obvious solution to everyone but me.
Instead, what first made sense to me was for mk_accessors() to define
an alias of email(), _email_accessor().  Using this solution,
Foo::email() would be written with:

    return $self->_email_accessor(@_);

instead of the expected SUPER::email().


=head1 AUTHOR

Michael G Schwern <schwern@pobox.com>


=head1 THANKS

Thanks to Tels for his big feature request/bug report.


=head1 SEE ALSO

L<Class::Accessor::Fast>

These are some modules which do similar things in different ways
L<Class::Struct>, L<Class::Methodmaker>, L<Class::Generate>,
L<Class::Class>, L<Class::Contract>

L<Class::DBI> for an example of this module in use.

=cut

1;
