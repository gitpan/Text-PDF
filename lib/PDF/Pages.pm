package PDF::Pages;

use strict;
use vars qw(@ISA);
@ISA = qw(PDF::Dict);

use PDF::Dict;

=head1 NAME

PDF::Pages - a PDF pages hierarchical element. Inherits from L<PDF::Dict>

=head1 DESCRIPTION

A Pages object is the parent to other pages objects or to page objects 
themselves.

=head1 METHODS

=head2 PDF::Pages->new($parent)

This creates a new Pages object. Notice that $parent here is not the file
context for the object but the parent pages object for this pages. If we
are using this class to create a root node, then $parent should point to the
file context, which is identified by not having a Type of Pages.

=cut

sub new
{
    my ($class, $parent) = @_;
    my ($self, $pere);

    unless (defined $parent->{'Type'} && $parent->{'Type'}->val eq "Pages")
    {
        $pere = $parent;
        undef $parent;
    } else
    { $pere = $parent->{' parent'}; }

    $self = $class->SUPER::new($pere);
    $self->{'Type'} = PDF::Name->new($pere, "Pages");
    $self->{'Parent'} = $parent if defined $parent;
    $pere->{'Root'}{'Pages'} = $self unless defined $parent;
    $self->{'Count'} = PDF::Number->new($pere, 0);
    $self->{'Kids'} = PDF::Array->new($pere);

    $pere->new_obj($self);
    $self;
}


=head2 $p->add_page($page)

Adds a page to this pages object.

=cut

sub add_page
{
    my ($self, $page) = @_;

    $self->{'Count'}{'val'}++;
    $self->{'Kids'}->add_elements($page);
    $self;
}


=head2 $p->find_prop($key)

Searches up through the inheritance tree to find a property.

=cut

sub find_prop
{ defined $_[0]->{$_[1]} && $_[0]->{$_[1]} or
        defined $_[0]->{'Parent'} && $_[0]->{'Parent'}->find_prop($_[1]); }


=head2 $p->add_font($font)

Creates or edits the resource dictionary at this level in the hierarchy. If
the font is already supported even through the hierarchy, then it is not added.

=cut

sub add_font
{
    my ($self, $font) = @_;
    my ($name) = $font->{'Name'}->val;
    my ($dict) = $self->find_prop('Resources');
    my ($parent) = $self->{' parent'};

    return $self if ($dict ne "" && defined $dict->{'Font'} && defined $dict->{'Font'}{$name});
    unless (defined $self->{'Resources'})
    { $self->{'Resources'} = $dict ne ""? $dict->copy : PDF::Dict->new($parent); }
    $self->{'Resources'}{'Font'} = PDF::Dict->new($parent)
            unless defined $self->{'Resources'}{'Font'};
    $self->{'Resources'}{'Font'}{$name} = $font;
    $self;
}


=head2 $p->bbox($xmin, $ymin, $xmax, $ymax)

Specifies the bounding box for this and all child pages. If the values are
identical to those inherited then no change is made.

=cut

sub bbox
{
    my ($self, @bbox) = @_;
    my ($inh) = $self->find_prop('MediaBox');
    my ($test, $i, $e);

    if ($inh ne "")
    {
        $test = 1; $i = 0;
        foreach $e ($inh->elementsof)
        { $test &= $e->val == $bbox[$i++]; }
        return $self if $test && $i == 4;
    }

    $inh = PDF::Array->new($self->{' parent'});
    foreach $e (@bbox)
    { $inh->add_elements(PDF::Number->new($self->{' parent'}, $e)); }
    $self->{'MediaBox'} = $inh;
    $self;
}


=head2 $p->proc_set(@entries)

Ensures that the current resource contains all the entries in the proc_sets
listed. If necessary it creates a local resource dictionary to achieve this.

=cut

sub proc_set
{
    my ($self, @entries) = @_;
    my (@temp) = @entries;
    my ($parent) = $self->{' parent'};
    my ($dict, $e);

    $dict = $self->find_prop('Resource');
    if ($dict ne "" && defined $dict->{'ProcSet'})
    {
        foreach $e ($dict->{'ProcSet'}->elementsof)
        { @temp = grep($_ ne $e, @temp); }
        return $self if $#temp < 0;
        @entries = @temp if defined $self->{'Resources'};
    }

    unless (defined $self->{'Resources'})
    { $self->{'Resources'} = $dict ne "" ? $dict->copy : PDF::Dict->new($parent); }

    $self->{'Resources'}{'ProcSet'} = PDF::Array->new($parent)
            unless defined $self->{'ProcSet'};

    foreach $e (@entries)
    { $self->{'Resources'}{'ProcSet'}->add_elements(PDF::Name->new($parent, $e)); }
    $self;
}

