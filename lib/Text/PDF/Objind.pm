package Text::PDF::Objind;

=head1 NAME

Text::PDF::Objind - PDF indirect object reference. Also acts as an abstract
superclass for all elements in a PDF file.

=head1 INSTANCE VARIABLES

Instance variables differ from content variables in that they all start with
a space.

=over

=item parent

For an object which is a reference to an object in some source, this holds the
reference to the source object, so that should the reference have to be
de-referenced, then we know where to go and get the info.

=item objnum (R)

The object number in the source (only for object references)

=item objgen (R)

The object generation in the source

There are other instance variables which are used by the parent for file control.

=item isfree

This marks whether the object is in the free list and available for re-use as
another object elsewhere in the file.

=item nextfree

Holds a direct reference to the next free object in the free list.

=back

=head1 METHODS

=cut

use strict;
use vars qw(@inst %inst $uidc);

# protected keys during emptying and copying, etc.
@inst = qw(parent objnum objgen isfree nextfree);

BEGIN
{
    map {$inst{" $_"} = 1} @inst;
    $uidc = "pdf_uid000";
}


=head2 Text::PDF::Objind->new()

Creates a new indirect object

=cut

sub new
{
    my ($class) = @_;
    my ($self) = {};

    bless $self, $class;
}


=head2 uid

Returns a Unique id for this object, creating one if it didn't have one before

=cut

sub uid
{ $_[0]->{' uid'} || ($_[0]->{' uid'} = $uidc++); }

=head2 $r->val

Returns the val of this object or reads the object and then returns its value.

Note that all subclasses *must* make their own versions of this subroutine
otherwise we could be in for a very deep loop!

=cut

sub val
{
    my ($self) = @_;
    
    $self->{' parent'}->read_obj($self)->val;
}

=head2 $r->outobjdeep($fh, $pdf)

Does very little, just outputs the endobj if the subclass wants it

=cut

sub outobjdeep
{
    my ($self, $fh, $pdf) = @_;

    $fh->print("\nendobj\n");
}


=head2 $r->outobj($fh)

If this is a full object then outputs a reference to the object, otherwise calls
outobjdeep to output the contents of the object at this point.

=cut

sub outobj
{
    my ($self, $fh, $pdf) = @_;

    if (defined $pdf->{' objects'}{$self->uid})
    { $fh->printf("%d %d R", @{$pdf->{' objects'}{$self->uid}}[0..1]); }
    else
    { $self->outobjdeep($fh, $pdf); }
}


=head2 $r->elementsof

Abstract superclass function filler. Returns self here but should return
something more useful if an array.

=cut

sub elementsof
{ ($_[0]); }


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


=head2 $r->is_obj($pdf)

Returns whether this object is a full object with its own object number or
whether it is purely a sub-object. $pdf indicates which output file we are
concerned that the object is an object in.

=cut

sub is_obj
{ defined $_[1]->{' objects'}{$_[0]->uid}; }


=head2 $r->copy($pdf, $res)

Returns a new copy of this object. The object is assumed to be some kind
of associative array and the copy is a deep copy for elements which are
not PDF objects, according to $pdf, and shallow copy for those that are.
Notice that calling C<copy> on an object forces at least a one level
copy even if it is a PDF object. The returned object loses its PDF
object status though.

If $res is defined then the copy goes into that object rather than creating a
new one. It is up to the caller to bless $res, etc. Notice that elements from
$self are not copied into $res if there is already an entry for them existing
in $res.

=cut

sub copy
{
    my ($self, $pdf, $res) = @_;
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
        if (UNIVERSAL::can($self->{$k}, "is_obj") && !$self->{$k}->is_obj($pdf))
        { $res->{$k} = $self->{$k}->copy($pdf); }
        else
        { $res->{$k} = $self->{$k}; }
    }
    $res;
}
