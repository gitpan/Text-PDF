package Text::PDF::TTFont;

=head1 NAME

Text::PDF::TTFont - Inherits from L<Text::PDF::Dict> and represents a TrueType
font within a PDF file.

=head1 DESCRIPTION

A font consists of two primary parts in a PDF file: the header and the font
descriptor. Whilst two fonts may share font descriptors, they will have their
own header dictionaries including encoding and widhth information.

=head1 INSTANCE VARIABLES

There are no instance variables beyond the variables which directly correspond
to entries in the appropriate PDF dictionaries.

=head1 METHODS

=cut

use strict;
use vars qw(@ISA);

use Text::PDF::Dict;
use Text::PDF::Utils;
@ISA = qw(Text::PDF::Dict);

use Font::TTF::Font;


=head2 Text::PDF::TTFont->new($parent, $fontfname. $pdfname)

Creates a new font resource for the given fontfile. This includes the font
descriptor and the font stream. The $pdfname is the name by which this font
resource will be known throught a particular PDF file.

All font resources are full PDF objects.

=cut

sub new
{
    my ($class, $parent, $fontname, $pdfname) = @_;
    my ($self) = $class->SUPER::new;
    my ($f, $flags, $name, $subf, $s, $upem);
    my ($font);

    $self->{' outto'} = $parent;                    # only one host for a font
    if (ref($fontname))                             # $fontname is a font object
    { $font = $fontname; }
    else
    { $font = Font::TTF::Font->open($fontname) || return undef; }

    $self->{' font'} = $font;
    
    $self->{'Type'} = PDFName("Font");
    $self->{'Subtype'} = PDFName("TrueType");
    $name = $font->{'name'}->read->{'strings'}[4][1][0]{0};     # Try Mac string full name first
    $subf = $font->{'name'}{'strings'}[2][1][0]{0};
    if ($name eq "")                                            # Now Windows Unicode
    {
        $name = $font->{'name'}{'strings'}[4][3][1]{1033};
        $name =~ s/(.)(.)/$2/oig if ($name ne "");              # lazy 1252 conversion
    }
    if ($subf eq "")
    {
        $subf = $font->{'name'}{'strings'}[2][3][1]{1033};
        $subf =~ s/(.)(.)/$2/oig if ($subf ne "");
    }
    return undef if ($name eq "");
    $name =~ s/\s//oig;
    $name .= $subf if ($subf =~ m/^Regular$/oi);
    $self->{'BaseFont'} = PDFName($name);
    $self->{'Name'} = PDFName($pdfname);
    $parent->new_obj($self);
# leave the encoding & widths, etc. until we know the glyph list

    $f = PDFDict();
    $parent->new_obj($f);                      # make this thing a true object
    $self->{'FontDescriptor'} = $f;
    $f->{'Type'} = PDFName("FontDescriptor");
    $upem = $font->{'head'}->read->{'unitsPerEm'};
    $f->{'Ascent'} = PDFNum(int($font->{'hhea'}->read->{'Ascender'} * 1000 / $upem));
    $f->{'Descent'} = PDFNum(int($font->{'hhea'}{'Descender'} * 1000 / $upem));

# find the top of an H or the null box! Or maybe we should just duck and say 0?
    $f->{'CapHeight'} = PDFNum(0);
#            int($font->{'loca'}->read->{'glyphs'}[$font->{'post'}{'STRINGS'}{"H"}]->read->{'yMax'}
#            * 1000 / $upem));
    $f->{'StemV'} = PDFNum(0);                       # no way!
    $f->{'FontName'} = PDFName($name);
    $f->{'ItalicAngle'} = PDFNum($font->{'post'}->read->{'italicAngle'});
    $f->{'FontBBox'} = PDFArray(
            PDFNum(int($font->{'head'}{'xMin'} * 1000 / $upem)),
            PDFNum(int($font->{'head'}{'yMin'} * 1000 / $upem)),
            PDFNum(int($font->{'head'}{'xMax'} * 1000 / $upem)),
            PDFNum(int($font->{'head'}{'yMax'} * 1000 / $upem)));

    $flags = 4;
if (0) {
    $flags = 0;
    $flags |= 1 if ($font->{'OS/2'}->read->{'bProportion'} == 9);
    $flags |= 2 unless ($font->{'OS/2'}{'bSerifStyle'} > 10 && $font->{'OS/2'}{'bSerifStyle'} < 14);
    $flags |= 32; # if ($font->{'OS/2'}{'bFamilyType'} > 3);
    $flags |= 8 if ($font->{'OS/2'}{'bFamilyType'} == 2);
    $flags |= 64 if ($font->{'OS/2'}{'bLetterform'} > 8);
}
    $f->{'Flags'} = PDFNum($flags);
    
#    $f->{'MaxWidth'} = PDFNum(int($font->{'hhea'}{'advanceWidthMax'} * 1000 / $upem));
#    $f->{'MissingWidth'} = PDFNum($f->{'MaxWidth'}->val - 1);
    $f->{' notdef'} = PDFNum(".notdef");

    $s = PDFDict();
    $parent->new_obj($s);
    $f->{'FontFile2'} = $s;
    $s->{'Length1'} = PDFNum(-s $font->{' fname'});
    $s->{'Filter'} = PDFArray(PDFName("FlateDecode"));
    $s->{' streamfile'} = $font->{' fname'};
    
    $self;
}

=head2 $t->add_glyphs($font, $first, \@glyphs)

This function allows you to add glyphs to a PDF font based on glyphs in the
TrueType font. $first contains the 8-bit codepoint of the first glyph. The
rest of the glyphs follow on sequentially.

It is possible to add sets of glyphs in different calls to this function, but
it is strongly recommended that they be added in monotonic, non-overlapping
order. The function will trim the incoming list if it overlaps the existing
list, which cannot contain gaps.

=cut

sub add_glyphs
{
    my ($self, $first, $ref) = @_;
    my ($last) = $first + $#{$ref};
    my ($i, $upem, @widths, @encs);
    my ($oldfirst, $oldlast, $font);
    my ($miss) = $self->{'FontDescriptor'}{'MissingWidth'};
    my ($notdef) = $self->{'FontDescriptor'}{' notdef'};

    $font = $self->{' font'};
    $oldfirst = $self->{'FirstChar'}->val if $self->{'FirstChar'} ne "";
    $oldlast = $self->{'LastChar'}->val if $self->{'LastChar'} ne "";
    $upem = $font->{'head'}{'unitsPerEm'};


# This assumes that $first < $oldfirst && $last > $oldlast
    if ($first < $oldfirst && $last > $oldfirst)
    {
        splice(@$ref, $oldfirst - $first);
        $last = $oldfirst - 1;
    } elsif ($first < $oldlast && $last > $oldlast)
    {
        splice(@$ref, 0, $oldlast - $first + 1);
        $first = $oldlast + 1;
    }

    unless ($self->{'Widths'} ne "")
    {
        $self->{'Widths'} = PDFArray();
        $self->{' outto'}->new_obj($self->{'Widths'});
        $self->{'Encoding'} = PDFArray();
    }

    if ($last < $oldfirst - 1)
    {
        unshift(@{$self->{'Widths'}->val}, ($miss) x ($oldfirst - $last - 1));
        splice(@{$self->{'Encoding'}->val}, 0, 1, ($notdef) x ($oldfirst - $last - 1));
        $oldfirst = $last + 1;
    }
    elsif ($first < $oldfirst)
    { shift(@{$self->{'Encoding'}->val}); }
        
    if ($first > $oldlast + 1 && $oldlast > 0)
    {
        push(@{$self->{'Widths'}->val}, ($miss) x ($first - $oldlast - 1));
        push(@{$self->{'Encoding'}->val}, ($notdef) x ($first - $oldlast - 1));
        $oldlast = $first - 1;
    }

    $font->{'hmtx'}->read;
    $font->{'post'}->read;
    for ($i = 0; $i < $last - $first; $i++)
    {
        push(@widths, defined $ref->[$i] ?
                PDFNum(int($font->{'hmtx'}{'advance'}[$ref->[$i]] * 1000 / $upem))
                : $miss);
        push(@encs, defined $ref->[$i] && $font->{'post'}{'VAL'}[$ref->[$i]] ne ".notdef" ?
                PDFName($font->{'post'}{'VAL'}[$ref->[$i]])
                : $notdef);
    }

    if ($last > $oldlast)
    {
        push (@{$self->{'Widths'}->val}, @widths);
        push (@{$self->{'Encoding'}->val}, @encs);
    } else
    {
        unshift(@{$self->{'Widths'}->val}, @widths);
        splice(@{$self->{'Encoding'}->val}, 0, 1, @encs);
    }
    $oldfirst = $first;
    $oldlast = $last;
    unshift(@{$self->{'Encoding'}->val}, PDFNum($oldfirst));
    $self->{'FirstChar'} = PDFNum(0) unless $self->{'FirstChar'} ne "";
    $self->{'LastChar'} = PDFNum(0) unless $self->{'LastChar'} ne "";
    $self->{'FirstChar'}{'val'} = $oldfirst;
    $self->{'LastChar'}{'val'} = $oldlast;
    $self;
}


=head2 $f->copy

Copies the font object excluding the name, widths and encoding, etc.

=cut

sub copy
{
    my ($self, $pdf) = @_;
    my ($res) = {};
    my ($k);

    bless $res, ref($self);
    foreach $k ('Name', 'Widths', 'Encoding', 'FirstChar', 'LastChar')
    { $res->{$k} = ""; }
    return $self->SUPER::copy($pdf, $res);
}

package Text::PDF::TTIOString;

=head1 TITLE

Text::PDF::TTIOString - internal IO type handle for string output for font
embedding. This code is ripped out of IO::Scalar, to save the direct dependence
for so little. See IO::Scalar for details

=cut

sub new {
    my $self = bless {}, shift;
    $self->open(@_) if @_;
    $self;
}

sub DESTROY { 
    shift->close;
}


sub open {
    my ($self, $sref) = @_;

    # Sanity:
    defined($sref) or do {my $s = ''; $sref = \$s};
    (ref($sref) eq "SCALAR") or die "open() needs a ref to a scalar";

    # Setup:
    $self->{Pos} = 0;
    $self->{SR} = $sref;
    $self;
}

sub close {
    my $self = shift;
    %$self = ();
    1;
}

sub getc {
    my $self = shift;
    
    # Return undef right away if at EOF; else, move pos forward:
    return undef if $self->eof;  
    substr(${$self->{SR}}, $self->{Pos}++, 1);
}

if(0)
{
sub getline {
    my $self = shift;

    # Return undef right away if at EOF:
    return undef if $self->eof;

    # Get next line:
    pos(${$self->{SR}}) = $self->{Pos}; # start matching at this point
    ${$self->{SR}} =~ m/(.*?)(\n|\Z)/g; # match up to newline or EOS
    my $line = $1.$2;                   # save it
    $self->{Pos} += length($line);      # everybody remember where we parked!
    return $line; 
}

sub getlines {
    my $self = shift;
    wantarray or croak("Can't call getlines in scalar context!");
    my ($line, @lines);
    push @lines, $line while (defined($line = $self->getline));
    @lines;
}
}

sub print {
    my $self = shift;
    my $eofpos = length(${$self->{SR}});
    my $str = join('', @_);

    if ($self->{'Pos'} == $eofpos)
    {
        ${$self->{SR}} .= $str;
        $self->{Pos} = length(${$self->{SR}});
    } else
    {
        substr(${$self->{SR}}, $self->{Pos}, length($str)) = $str;
        $self->{Pos} += length($str);
    }
    1;
}

sub read {
    my ($self, $buf, $n, $off) = @_;
    die "OFFSET not yet supported" if defined($off);
    my $read = substr(${$self->{SR}}, $self->{Pos}, $n);
    $self->{Pos} += length($read);
    $_[1] = $read;
    return length($read);
}

sub eof {
    my $self = shift;
    ($self->{Pos} >= length(${$self->{SR}}));
}

sub seek {
    my ($self, $pos, $whence) = @_;
    my $eofpos = length(${$self->{SR}});

    # Seek:
    if    ($whence == 0) { $self->{Pos} = $pos }             # SEEK_SET
    elsif ($whence == 1) { $self->{Pos} += $pos }            # SEEK_CUR
    elsif ($whence == 2) { $self->{Pos} = $eofpos + $pos}    # SEEK_END
    else                 { die "bad seek whence ($whence)" }

    # Fixup:
    if ($self->{Pos} < 0)       { $self->{Pos} = 0 }
    if ($self->{Pos} > $eofpos) { $self->{Pos} = $eofpos }
    1;
}

sub tell { shift->{Pos} }

1;

