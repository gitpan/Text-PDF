package Text::PDF::SFont;

# use strict;
use vars qw(@ISA %widths @encodings);
@ISA = qw(Text::PDF::Dict);

use Text::PDF::Utils;

=head1 NAME

Text::PDF::SFont - PDF Standard inbuilt font resource object. Inherits from
L<Text::PDF::Dict>

=head1 METHODS

=head2 Text::PDF::SFont->new($parent, $name, $pdfname)

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

BEGIN
{
    @encodings = ('WinAnsiEncoding', 'MacRomanEncoding', 'MacExpertEncoding');
}

sub new
{
    my ($class, $parent, $name, $pdfname, $encoding) = @_;
    my ($self) = $class->SUPER::new;

    $self->{'Type'} = PDFName("Font");
    $self->{'Subtype'} = PDFName("Type1");
    $self->{'BaseFont'} = PDFName($name);
    $self->{'Name'} = PDFName($pdfname);
    $self->{'Encoding'} = PDFName($encodings[$encoding-1]) if ($encoding);
    $parent->new_obj($self);
    $self;
}

=head2 $f->width($text)

Returns the width of the text in em.

=cut

sub getBase
{
    my ($self) = @_;

    unless (defined $widths{$self->{'BaseFont'}->val})
    {
    	my ($str, $str1);
    	$str = $self->{'BaseFont'}->val;
    	$str =~ s/\-//oig;
    	$str1 = $str;
    	$str = "Font/Metrics/$str.pm";
    	require $str;            #
    	$widths{$self->{'BaseFont'}->val} = \@{"Font::Metrics::$str1\::wx"};
    }
    $self;
}

sub width
{
    my ($self, $text) = @_;
    my ($width);
    
    $self->getBase;
    foreach (unpack("C*", $text))
    { $width += $widths{$self->{'BaseFont'}->val}[$_]; }
    $width;
}

=head2 $f->trim($text, $len)

Trims the given text to the given length (in per mille em) returning the trimmed
text

=cut

sub trim
{
    my ($self, $text, $len) = @_;
    my ($width, $i);
    
    $self->getBase;
    
    foreach (unpack("C*", $text))
    {
        $width += $widths{$self->{'BaseFont'}->val}[$_];
        last if ($width > $len);
        $i++;
    }
    return substr($text, 0, $i);
}

1;

