package PDF::Page;

use strict;
use vars qw(@ISA);
@ISA = qw(PDF::Pages);
use PDF::Pages;

=head1 NAME

PDF::Page - Represents a PDF page, inherits from L<PDF::Pages>

=head1 DESCRIPTION

Represents a page of output in PDF. It also keeps track of the content stream,
any resources (such as fonts) being switched, etc.

Page inherits from Pages due to a number of shared methods. They are really
structurally quite different.

=head1 INSTANCE VARIABLES

A page has various working variables:

=item curstrm

The currently open stream

=head1 METHODS

=head2 PDF::Page->new($parent)

Creates a new page based on a pages object (perhaps the root object). Notice
that here $parent is not the file context but the parent pages object. The
file context is stored, as normal, in the ' parent' field.

The page is also added to the parent at this point, so pages are ordered in
a PDF document in the order in which they are created rather than in the order
they are closed.

Only the essential elements in the page dictionary are created here, all others
are either optional or can be inherited.

=cut

sub new
{
    my ($class, $parent) = @_;
    my ($pere) = $parent->{' parent'};
    my ($self) = {' parent' => $pere};

    bless $self, $class;
    $self->{'Type'} = PDF::Name->new($pere, "Page");
    $self->{'Parent'} = $parent;
    $pere->new_obj($self);
    $parent->add_page($self);
    $self;
}


=head2 $p->add($str)

Adds the string to the currently active stream for this page. If no stream
exists, then one is created and added to the list of streams for this page.

The slightly cryptic name is an aim to keep it short given the number of times
people are likely to have to type it.

=cut

sub add
{
    my ($self, $str) = @_;
    my ($strm) = $self->{' curstrm'};

    if (!defined $strm)
    {
        $strm = PDF::Dict->new($self->{' parent'});
        $self->{' parent'}->new_obj($strm);
        $self->{'Contents'} = PDF::Array->new($self->{' parent'})
                unless defined $self->{'Contents'};
        $self->{'Contents'}->add_elements($strm);
        $self->{' curstrm'} = $strm;
    }

    $strm->{' stream'} .= $str;
    $self;
}


