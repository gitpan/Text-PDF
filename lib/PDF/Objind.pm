package PDF::Objind;

=head1 NAME

PDF::Objind - PDF indirect object reference. Also acts as an abstract
superclass for all elements in a PDF file.

=head1 INSTANCE VARIABLES

Instance variables differ from content variables in that they all start with
a space.

=over

=item parent

The file context for this object. That is the object that keeps track of all
the objects in the file (whether reading or writing).

=item objnum (R)

The object number

=item objgen (R)

The object generation

There are other instance variables which are used by the parent for file control.

=item loc (P)

This holds the read and then the write location of the actual object in the file.

=item isfree

This marks whether the object is in the free list and available for re-use as
another object elsewhere in the file.

=item nextfree

Holds a direct reference to the next free object in the free list.

=back

=head1 METHODS

=cut

use strict;
use vars qw(@inst %inst);

# protected keys during emptying and copying, etc.
@inst = qw(objnum objgen isfree nextfree);

BEGIN
{
    map {$inst{" $_"} = 1} @inst;
}

=head2 PDF::Objind->new($parent, $number, $generation)

Creates a new object reference with given parent, number and generation.
Note that subclasses do not necessarily have the same creation parameters.
This may seem naughty, but allows subclasses to be sub-objects of another
object, or objects in their own right (with their own number and generation).

=cut

sub new
{
    my ($class, $par, $num, $gen) = @_;

    my ($self);

    $self->{' parent'} = $self;
    $self->{' objnum'} = $num;
    $self->{' objgen'} = $gen;
    bless $self, $class;
}


=head2 $r->val

Returns (number, generation) which if used in a scalar context results in just
the number.

=cut

sub val
{ return ($_[0]->{' objnum'}, $_[0]->{' objgen'}); }


=head2 $r->outobjdeep($fh)

If this is a real object rather than just a sub-object, then output this object
with its object header to filehandle. Notice that it is up to the subclass to
output the endobj at the end.

=cut

sub outobjdeep
{
    my ($self, $fh) = @_;

    if (defined $self->{' objnum'})
    {
        $self->{' loc'} = tell($fh);
        print $fh "$self->{' objnum'} $self->{' objgen'} obj\n";
    }
#    print $fh "\nendobj\n";
}


=head2 $r->outobj($fh)

If this is a full object then outputs a reference to the object, otherwise calls
outobjdeep to output the contents of the object at this point.

=cut

sub outobj
{
    my ($self, $fh) = @_;

    if (defined $self->{' objnum'})
    { print $fh "$self->{' objnum'} $self->{' objgen'} R"; }
    else
    { $self->outobjdeep($fh); }
}


=head2 $r->outxref($fh)

Outputs cross-reference information for this object (if it has any) to the
cross-reference table.

=cut

sub outxref
{
    my ($self, $fh) = @_;

    return undef unless defined $self->{' objnum'};
    if ($self->{' isfree'})
    {
        print $fh pack("A10AA5A4", sprintf("%010d", $self->{' nextfree'}{' objnum'}), " ",
                sprintf("%05d", $self->{' objgen'} + 1), " f \n");
    } else
    {
        print $fh pack("A10AA5A4", sprintf("%010d", $self->{' loc'}), " ",
                sprintf("%05d", $self->{' objgen'}), " n \n");
    }
}


=head2 $r->elementsof

Abstract superclass function filler. Returns self here but should return
something more useful if an array.

=cut

sub elementsof
{ ($_[0]); }


=head2 $r->isobj($number, $generation)

Marks this simple object (sub-object) as a full object in its own right.
Involves informing the parent that this thing is now a full object, and to
make sure that it is output next time.

=cut

sub isobj
{
    my ($self, $num, $gen) = @_;

    $self->{' objnum'} = $num;
    $self->{' objgen'} = $gen;
    $self->{' parent'}->add_obj($self);
    $self->{' parent'}->out_obj($self);
    return $self;
}


=head2 $r->empty

Empties all content from this object to free up memory or to be read to pass
the object into the free list. Simplistically undefs all instance variables
other than object number and generation.

=cut

sub empty
{
    my ($self) = @_;
    my ($k);

    for $k (keys %$self)
    { undef $self->{$k} unless $inst{$k}; }
    $self;
}


=head2 $r->merge($objind)

This merges content information into an object reference place-holder.
This occurs when an object reference is read before the object definition
and the information in the read data needs to be merged into the object
place-holder

=cut

sub merge
{
    my ($self, $other) = @_;
    my ($k);

    for $k (keys %$other)
    { $self->{$k} = $other->{$k} unless $inst{$k}; }
    bless $self, ref($other);
}


=head2 $r->is_obj($parent)

Returns whether this object is a full object with its own object number or
whether it is purely a sub-object. $parent may optionally be set to a different
parent than the object thinks it is. I'm not sure about this.

=cut

sub is_obj
{
    my ($self, $parent) = @_;

    return 0 unless defined $self->{' objnum'};
    $parent = $self->{' parent'} unless defined $parent;
    return $self->{' parent'}{' objcache'}{$self->{' objnum'}, $self->{' objgen'}} eq $self;
}


=head2 $r->copy($res)

Returns a new copy of this object. The object is assumed to be some kind of
associative array and the copy is a deep copy for elements
which are not PDF objects, and shallow copy for those that are. Notice that
calling C<copy> on an object forces at least a one level copy even if it is
a PDF object. The returned object loses its PDF object status though.

If $res is defined then the copy goes into that object rather than creating a
new one. It is up to the caller to bless $res, etc. Notice that elements from
$self are not copied into $res if there is already an entry for them existing
in $res.

=cut

sub copy
{
    my ($self, $res) = @_;
    my ($k);

    unless (defined $res)
    {
        $res = {};
        bless $res, ref($self);
    }
    foreach $k (keys %$self)
    {
        next if $inst{$k};
        next if defined $res->{$k};
        if (UNIVERSAL::can($self->{$k}, "is_obj") && !$self->{$k}->is_obj)
        { $res->{$k} = $self->{$k}->copy; }
        else
        { $res->{$k} = $self->{$k}; }
    }
    $res;
}

