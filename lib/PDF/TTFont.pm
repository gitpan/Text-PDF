package PDF::TTFont;

=head1 NAME

PDF::TTFont - Inherits from L<PDF::Dict> and represents a TrueType
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

use PDF::Dict;
@ISA = qw(PDF::Dict);

use TTF::Font;


=head2 PDF::TTFont->new($parent, $fontfname. $pdfname)

Creates a new font resource for the given fontfile. This includes the font
descriptor and the font stream. The $pdfname is the name by which this font
resource will be known throught a particular PDF file.

All font resources are full PDF objects.

=cut

sub new
{
    my ($class, $parent, $fontname, $pdfname) = @_;
    my ($self) = $class->SUPER::new($parent);
    my ($f, $flags, $name, $s, $upem);
    my ($font);

    if (ref($fontname))                             # $fontname is a font object
    { $font = $fontname; }
    else
    { $font = TTF::Font->open($fontname) || return undef; }

    $self->{' font'} = $font;
    
    $self->{'Type'} = PDF::Name->new($parent, "Font");
    $self->{'Subtype'} = PDF::Name->new($parent, "TrueType");
    $name = $font->{'name'}->read->{'strings'}[4][1][0]{0};     # Try Mac string full name first
    if ($name eq "")                                            # Now Windows Unicode
    {
        $name = $font->{'name'}[4][3][1]{1033};
        $name =~ s/(.)(.)/$2/oig if ($name ne "");              # lazy 1252 conversion
    }
    return undef if ($name eq "");
    $name =~ s/\s//oig;
    $self->{'BaseFont'} = PDF::Name->new($parent, $name);
    $self->{'Name'} = PDF::Name->new($parent, $pdfname);
    $parent->new_obj($self);
# leave the encoding & widths, etc. until we know the glyph list

    $f = PDF::Dict->new($parent);
    $parent->new_obj($f);                      # make this thing a true object
    $self->{'FontDescriptor'} = $f;
    $f->{'Type'} = PDF::Name->new($parent, "FontDescriptor");
    $upem = $font->{'head'}->read->{'unitsPerEm'};
    $f->{'Ascent'} = PDF::Number->new($parent, int($font->{'hhea'}->read->{'Ascender'} * 1000 / $upem));
    $f->{'Descent'} = PDF::Number->new($parent, int($font->{'hhea'}{'Descender'} * 1000 / $upem));

# find the top of an H or the null box! Or maybe we should just duck and say 0?
    $f->{'CapHeight'} = PDF::Number->new($parent, 
            int($font->{'loca'}->read->{'glyphs'}[$font->{'post'}{'STRINGS'}{"H"}]->read->{'yMax'}
            * 1000 / $upem));
    $f->{'StemV'} = PDF::Number->new($parent, 0);                       # no way!
    $f->{'FontName'} = PDF::Name->new($parent, $name);
    $f->{'ItalicAngle'} = PDF::Number->new($parent, $font->{'post'}->read->{'italicAngle'});
    $f->{'FontBBox'} = PDF::Array->new($parent,
            PDF::Number->new($parent, int($font->{'head'}{'xMin'} * 1000 / $upem)),
            PDF::Number->new($parent, int($font->{'head'}{'yMin'} * 1000 / $upem)),
            PDF::Number->new($parent, int($font->{'head'}{'xMax'} * 1000 / $upem)),
            PDF::Number->new($parent, int($font->{'head'}{'yMax'} * 1000 / $upem)));

    $flags = 0;
    $flags |= 2 if ($font->{'OS/2'}->read->{'bProportion'} == 9);
    $flags |= 4 unless ($font->{'OS/2'}{'bSerifStyle'} > 10 && $font->{'OS/2'}{'bSerifStyle'} < 14);
    $flags |= 8 if ($font->{'OS/2'}{'bFamilyType'} > 3);
    $flags |= 16 if ($font->{'OS/2'}{'bFamilyType'} == 2);
    $flags |= 128 if ($font->{'OS/2'}{'bLetterform'} > 8);
    $f->{'Flags'} = PDF::Number->new($parent, $flags);
    
    $f->{'MaxWidth'} = PDF::Number->new($parent, int($font->{'hhea'}{'advanceWidthMax'} * 1000 / $upem));
    $f->{'MissingWidth'} = PDF::Number->new($parent, $f->{'MaxWidth'}->val + 10);
    $f->{' notdef'} = PDF::Name->new($parent, ".notdef");

    $s = PDF::Dict->new($parent);
    $parent->new_obj($s);
    $f->{'FontFile2'} = $s;
    $s->{'Length1'} = PDF::Number->new($parent, -s $font->{' fname'});
#    $s->{'Filter'} = PDF::Array->new($parent, PDF::Name->new($parent, "ASCII85Decode"));
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
    my ($p) = $self->{' parent'};
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
        $self->{'Widths'} = PDF::Array->new($p);
        $p->new_obj($self->{'Widths'});
        $self->{'Encoding'} = PDF::Array->new($p);
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
                PDF::Number->new($p, int($font->{'hmtx'}{'advance'}[$ref->[$i]] * 1000 / $upem))
                : $miss);
        push(@encs, defined $ref->[$i] && $font->{'post'}{'VAL'}[$ref->[$i]] ne ".notdef" ?
                PDF::Name->new($p, $font->{'post'}{'VAL'}[$ref->[$i]])
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
    unshift(@{$self->{'Encoding'}->val}, PDF::Number->new($p, $oldfirst));
    $self->{'FirstChar'} = PDF::Number->new($p, 0) unless $self->{'FirstChar'} ne "";
    $self->{'LastChar'} = PDF::Number->new($p, 0) unless $self->{'LastChar'} ne "";
    $self->{'FirstChar'}{'val'} = $oldfirst;
    $self->{'LastChar'}{'val'} = $oldlast;
    $self;
}


=head2 $f->copy

Copies the font object excluding the name, widths and encoding, etc.

=cut

sub copy
{
    my ($self) = @_;
    my ($res) = {};
    my ($k);

    bless $res, ref($self);
    foreach $k ('Name', 'Widths', 'Encoding', 'FirstChar', 'LastChar')
    { $res->{$k} = ""; }
    return $self->SUPER::copy($res);
}

