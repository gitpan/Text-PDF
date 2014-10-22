use Text::PDF::File;
use Text::PDF::SFont;
use Text::PDF::Utils;

use Getopt::Std;

getopts('f:l:s:t:');

unless (defined $ARGV[1] && -f $ARGV[0])
{
    die <<'EOT';
    pdfstamp [-f font] [-l locx,locy] [-s size] infile string
Adds the given string to the infile .pdf file at the given location, font and
size.

    -f font     Font name from the standard fonts [Helvetica]
    -l locx,locy    Location in points from bottom left of page [0,0]
    -s size     Font size to print at             [11]
    -t ttfile   TrueType font file to use (instead of -f)
EOT
}

require Text::PDF::TTFont if ($opt_t);

$opt_f = 'Helvetica' unless $opt_f;
$opt_s = 11 unless $opt_s;
$opt_l =~ s/,\s*/ /o;
$opt_l = "0 0" unless $opt_l;

$pdf = Text::PDF::File->open($ARGV[0], 1);
$root = $pdf->{'Root'}->realise;
$pgs = $root->{'Pages'}->realise;

@pglist = proc_pages($pdf, $pgs);

$max = 0;
foreach $p (@pglist)
{
    $dict = $p->find_prop('Resources');
    if (defined $dict && defined $dict->{'Font'})
    {
        foreach $k (keys %{$dict->{'Font'}})
        {
            next unless $k =~ m/^ap([0-9]+)/o;
            $val = $1;
            $max = $val if $val > $max;
        }
    }
}

$max++;
if ($opt_t)
{ $font = Text::PDF::TTFont->new($pdf, $opt_t, "ap$max", -subset => 1) || die "Can't work with font $opt_t"; }
else
{ $font = Text::PDF::SFont->new($pdf, $opt_f, "ap$max") || die "Can't create font $opt_f"; }
$stream = PDFDict();
$stream->{' stream'} = "BT 1 0 0 1 $opt_l Tm /ap$max $opt_s Tf " . $font->out_text($ARGV[1]) . " Tj ET";
$pdf->new_obj($stream);
foreach $p (@pglist)
{
    $p->add_font($font, $pdf);
    $p->{Contents} = PDFArray($stream, $p->{Contents}->elementsof);
    $pdf->out_obj($p);
}

$pdf->close_file;

sub proc_pages
{
    my ($pdf, $pgs) = @_;
    my ($pg, $pgref, @pglist);

    foreach $pgref ($pgs->{'Kids'}->elementsof)
    {
        $pg = $pdf->read_obj($pgref);
        if ($pg->{'Type'}->val =~ m/^Pages$/oi)
        { push(@pglist, proc_pages($pdf, $pg)); }
        else
        {
            $pgref->{' pnum'} = $pcount++;
            push (@pglist, $pgref);
        }
    }
    (@pglist);
}

