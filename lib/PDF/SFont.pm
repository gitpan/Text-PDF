package PDF::SFont;

use strict;
use vars qw(@ISA);
@ISA = qw(PDF::Dict);

=head1 NAME

PDF::SFont - PDF Standard inbuilt font resource object. Inherits from
L<PDF::Dict>

=head1 METHODS

=head2 PDF::SFont->new($parent, $name, $pdfname)

Creates a new font object with given parent and name. The name must be from
one of the core 14 base fonts included with PDF. These are:

    Courier,     Courier-Bold,   Courier-Oblique,   Courier-BoldOblique
    Times-Roman, Times-Bold,     Times-Italic,      Times-BoldItalic
    Helvetica,   Helvetica-Bold, Helvetica-Oblique, Helvetica-BoldOblique
    Symbol,      ZapfDingbats

The $pdfname is the name that this particular font object will be referenced
by throughout the PDF file. If you want to play silly games with naming, then
you can write the code to do it!

All fonts in this system are full PDF objects.

=cut

sub new
{
    my ($class, $parent, $name, $pdfname) = @_;
    my ($self) = $class->SUPER::new($parent);

    $self->{'Type'} = PDF::Name->new($parent, "Font");
    $self->{'Subtype'} = PDF::Name->new($parent, "Type1");
    $self->{'BaseFont'} = PDF::Name->new($parent, $name);
    $self->{'Name'} = PDF::Name->new($parent, $pdfname);
#    $self->{'Encoding'} = PDF::Name->new($parent, "WinAnsiEncoding");
    $parent->new_obj($self);
    $self;
}

    
