package Text::PDF::Pages;

use strict;
use vars qw(@ISA);
@ISA = qw(Text::PDF::Dict);

use Text::PDF::Dict;
use Text::PDF::Utils;

=head1 NAME

Text::PDF::Pages - a PDF pages hierarchical element. Inherits from L<Text::PDF::Dict>

=head1 DESCRIPTION

A Pages object is the parent to other pages objects or to page objects 
themselves.

=head1 METHODS

=head2 Text::PDF::Pages->new($parent)

This creates a new Pages object. Notice that $parent here is not the file
context for the object but the parent pages object for this pages. If we
are using this class to create a root node, then $parent should point to the
file context, which is identified by not having a Type of Pages.

=cut

sub new
{
    my ($class, $pdf, $parent) = @_;
    my ($self);

    $self = $class->SUPER::new;
    $self->{'Type'} = PDFName("Pages");
    $self->{'Parent'} = $parent if defined $parent;
    $pdf->{'Root'}{'Pages'} = $self unless defined $parent;
    $self->{'Count'} = PDFNum(0);
    $self->{'Kids'} = Text::PDF::Array->new;

    $pdf->new_obj($self);
    $self;
}


=head2 $p->add_page($page, $index)

Appends a page to this pages object or if defined $index then inserts the page
at that index in the elements array of this pages object (note that does not
equal the page number)

=cut

sub add_page
{
    my ($self, $page, $index) = @_;
    my ($t, $p);

    for ($t = $self; $t->{'Type'}{'val'} =~ m/^Pages$/oi; $t = $t->{'Parent'})
    {
        $t->{'Count'}{'val'}++;
        foreach $p (@{$page->{' outto'}})
        { $p->out_obj($t) if $t->is_obj($p); }
    }
    if (defined $index)
    { splice(@{$self->{'Kids'}->val}, $index, 0, $page); }
    else
    { $self->{'Kids'}->add_elements($page); }
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

    return $self if ($dict ne "" && defined $dict->{'Font'} && defined $dict->{'Font'}{$name});
    unless (defined $self->{'Resources'})
    { $self->{'Resources'} = $dict ne ""? $dict->copy : PDFDict(); }
    $self->{'Resources'}{'Font'} = PDFDict() unless defined $self->{'Resources'}{'Font'};
    $self->{'Resources'}{'Font'}{$name} = $font;
    $self;
}


=head2 $p->bbox($xmin, $ymin, $xmax, $ymax, [$param])

Specifies the bounding box for this and all child pages. If the values are
identical to those inherited then no change is made. $param specifies the attribute
name so that other 'bounding box'es can be set with this method.

=cut

sub bbox
{
    my ($self, @bbox) = @_;
    my ($str) = $bbox[4] || 'MediaBox';
    my ($inh) = $self->find_prop($str);
    my ($test, $i, $e);

    if ($inh ne "")
    {
        $test = 1; $i = 0;
        foreach $e ($inh->elementsof)
        { $test &= $e->val == $bbox[$i++]; }
        return $self if $test && $i == 4;
    }

    $inh = Text::PDF::Array->new;
    foreach $e (@bbox[0..3])
    { $inh->add_elements(PDFNum($e)); }
    $self->{$str} = $inh;
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
    { $self->{'Resources'} = $dict ne "" ? $dict->copy : PDFDict(); }

    $self->{'Resources'}{'ProcSet'} = PDFArray() unless defined $self->{'ProcSet'};

    foreach $e (@entries)
    { $self->{'Resources'}{'ProcSet'}->add_elements(PDFName($e)); }
    $self;
}

