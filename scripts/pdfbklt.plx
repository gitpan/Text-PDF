
use Text::PDF::File;
use Text::PDF::Utils;
use Getopt::Std;

$version = "1.500";     # MJPH  26-JUL-2000     Correct positioning in some cases and add landscape sizes


# $version = "1.100";     # MJPH   3-AUG-1998     Support new PDF library
# $version = "1.101";     # MJPH  13-OCT-1998     Debug resource merging not being output
# $version = "1.200";     # MJPH   6-NOV-1998     Merging external resources and change -r
# $version = "1.201";     # MJPH  29-DEC-1998     Add test in merge_dict for $v2 not present
# $version = "1.300";     # MJPH  15-JUN-1999     Remove outlines, etc. when making booklet
# $version = "1.302";     # MJPH  30-NOV-1999     Update to use Text::PDF
# $version = "1.302";     # MJPH  11-DEC-1999     Make sure updated root output
# $version = "1.4";       # MJPH   1-FEB-2000     Add -l and preset paper sizes
# $version = "1.401";     # MJPH  28-JUN-2000     Debug content lists and -r

getopts("b:h:lp:qrs:");

if (!defined $ARGV[0])
{
    die <<"EOT";
    PDFBKLT [-b num/size] [-p num] [-q] [-r] [-s size] pdffile

 (c) M. Hosken.     Version: $version

    Converts a PDF file into a booklet. It edits the pdffile to add the
modifications at the end.

  -b num/size    Specifies which page contains the output page size details [1]
            or gives the dimensions of the page in pts (x;y) or A4,ltr,lgl,A5
  -l        Flag to indicate linear scaling
  -p num    Specifies the number of pages on the output page (1, 2, 4) [2]
  -q        Quiet (no on screen messages)
  -r        Rotates the output (-p 2 rotates automatically, -r rotates back)
  -s size   Specifies the the location of the actual text on a page:
                2   half page right and left (big gutter)
                2r  half page always on right
                2l  half page always on left
                4   1/4 page right and left bottom (very big gutter)
                4t  1/4 page right and left top (very big gutter)
                4r/4l/4rt/4lt   1/4 page always on right or left bottom or top
                location as a single string: minx;miny;maxx;maxy in pts
EOT
}

%sizes=(
    'a4' => '595;842',
    'a4l' => '842;595',
    'ltr' => '612;792',
    'ltrl' => '792;612',
    'lgl' => '612;1008',
    'lgll' => '1008;612',
    );

$opt_b = $sizes{lc($opt_b)} if defined $sizes{lc($opt_b)};
print "Reading file\n" unless $opt_q;
$p = Text::PDF::File->open($ARGV[0], 1) || die "Can't open $ARGV[0]";
$r = $p->read_obj($p->{'Root'});
$pgs = $p->read_obj($r->{'Pages'});
$pgcount = $pgs->{'Count'}->val;

foreach (qw(Outlines Dests Threads AcroForm PageLabels StructTreeRoot OpenAction PageMode))
{
    if (defined $r->{$_})
    {
        delete $r->{$_};
        $p->out_obj($r);
    }
}

$pcount = 0;
proc_pages($pgs);

$opt_p = 2 unless defined $opt_p;
$opt_r = !$opt_r if (($opt_p == 2 && $opt_s !~ /2/o) || ($opt_p != 2 && $opt_s =~ /2/o));

if ($opt_b =~ m/^([0-9]+)\;([0-9]+)/oi)
{ @pbox = (0, 0, $1, $2); }
else
{
    $opt_b = 1 unless defined $opt_b;
    $opt_b--;

    foreach $n ($pglist[$opt_b]->find_prop('MediaBox')->elementsof)
    { push(@pbox, $n->val); }
}

$fpgins = PDFDict(); $p->new_obj($fpgins);
$spgins = PDFDict(); $p->new_obj($spgins);
$fpgins->{' stream'} = "q";
$spgins->{' stream'} = "Q";

unless ($opt_q)
{
    print "\nThere are $pgcount pages\n";
    print "Page box (pt) = $pbox[0], $pbox[1], $pbox[2], $pbox[3]\n";
}
$rpc = int(($pgcount + 3) / 4) * 4;

for ($i = 0; $i < $rpc / $opt_p; $i++)
{
    if ($opt_p == 1)
    {
        next if $i >= $pgcount;
        @pl = ($pglist[$i]);
        $m = $i + 1;
    }
    elsif ($opt_p == 2)
    {
        @pl = ($pglist[$i], $rpc - $i > $pgcount ? undef : $pglist[$rpc - $i - 1]);
        @pl = ($pl[1], $pl[0]) if ($i & 1);
        $m = ($i + 1) . ", " . ($rpc - $i);
    } else      # $opt_p == 4
    {
        @pl = ($pglist[2 * $i]);
# do these in a special order with increasing difficulty of passing if() requirement
        push (@pl, $pglist[2 * $i + 1]) if (2 * $i + 1 < $pgcount);
        push (@pl, $pglist[$rpc - 2 * $i - 2]) if ($rpc - 2 * $i - 2 < $pgcount);
        push (@pl, $pglist[$rpc - 2 * $i - 1]) if ($rpc - 2 * $i <= $pgcount);
        $m = (2 * $i + 1) . ", " . (2 * $i + 2) . ", " . ($rpc - 2 * $i - 1) . ", " . ($rpc - 2 * $i);
    }

    print "Merging " . $m . "\n" unless $opt_q;
    merge_pages(@pl);
}

$p->append_file;

sub proc_pages
{
    my ($pgs) = @_;
    my ($pg, $pgref);

    foreach $pgref ($pgs->{'Kids'}->elementsof)
    {
        print STDERR "." unless $opt_q;
        $pg = $p->read_obj($pgref);
        if ($pg->{'Type'}->val =~ m/^Pages$/oi)
        { proc_pages($pg); }
        else
        {
            $pgref->{' pnum'} = $pcount++;
            push (@pglist, $pgref);
        }
    }
}

sub merge_pages
{
    my (@pr) = @_;
    my ($n, $is, $rl, $bt, $j, $xs, $ys, $scale, $scalestr, $scalestrr, $id, $i);
    my (@slist, @s, $s, $bp, $s1, $s2, $p2, $min, $k);

    $s = undef;
    for ($j = 0; $j <= $#pr; $j++)
    {
        next unless defined $pr[$j];
        @prbox = ();
        foreach $n ($pr[$j]->find_prop('MediaBox')->elementsof)
        { push(@prbox, $n->val); }
        if ($opt_s =~ m/^([0-9]+);([0-9]+);([0-9]+);([0-9]+)/o)
        { @prbox = ($1, $2, $3, $4); }
        elsif ($opt_s =~ m/^([0-9])(.?)(.?)/o)
        {
            $is = $1;
            $rl = lc($2);
            $bt = lc($3);
            $rl = ($pr[$j]->{' pnum'} & 1) ? "l" : "r" unless ($rl ne "");
            if ($rl eq "r")
            { $prbox[1] = $prbox[3] - (($prbox[3] - $prbox[1]) / $is); }
            elsif ($rl eq "l")
            { $prbox[3] = $prbox[1] + (($prbox[3] - $prbox[1]) / $is); }

            if ($bt eq "t")
            { $prbox[2] = $prbox[0] + (($prbox[2] - $prbox[0]) * 2 / $is); }
            elsif ($is == 4)
            { $prbox[0] = $prbox[2] - (($prbox[2] - $prbox[0]) * 2 / $is); }
        } else
        { $is = 1; }
        $id = join(',', @prbox) . ",$opt_p";
        if (!defined $scache{$id})
        {
            @slist = ();
            $xs = ($pbox[2] - $pbox[0]) / ($prbox[2] - $prbox[0]);
            $ys = ($pbox[3] - $pbox[1]) / ($prbox[3] - $prbox[1]);
            $scale = ($prbox[3] - $prbox[1]) / ($prbox[2] - $prbox[0]);
            $rot = (($opt_p == 1 || $opt_p == 4) && $is == 2)
                    || ($opt_p == 2 && $is != 2);

            if ($opt_l)
            {
                if ($xs < ($opt_p == 2 ? .5 : 1) * ($opt_r ? $scale * $scale : 1) * $ys)
                { $ys = $xs / ($opt_r ? $scale * $scale : 1) / ($opt_p == 2 ? .5 : 1); }
                else
                { $xs = $ys * ($opt_r ? $scale * $scale : 1) * ($opt_p == 2 ? .5 : 1); }
            }
            
            if ($opt_p == 1 && $is != 2)            # portrait to portrait
            {
                
                $slist[0] = cm($xs, 0, 0, $ys,
#                        $pbox[0] - ($xs * $prbox[0]), $pbox[1] - ($ys * $prbox[1]));
                        .5 * ($pbox[2] - $xs * ($prbox[2] - $prbox[0])) + $pbox[0],
                        .5 * ($pbox[3] - $ys * ($prbox[3] - $prbox[0])) + $pbox[1]);
            } elsif ($opt_p == 1)                   # landscape on portrait to portrait
            {
                $slist[0] = cm(0, -$scale * $ys, $xs / $scale, 0,
                        $pbox[0] - $xs * $prbox[1] / $scale, $pbox[1] + $scale * $ys * $prbox[2]);
            } elsif ($opt_p == 2 && $is != 2)       # portrait source on portrait
            {
                @scalestr = (0, 0.5 * $ys * $scale, -$xs / $scale, 0,
                        0.5 * ($xs * ($prbox[3] - $prbox[1]) / $scale + $pbox[2]));
                $slist[0] = cm(@scalestr,
#                        0.5 * (-$ys * $scale * $prbox[0] + $pbox[1] + $pbox[3]));
                         .25 * (3 * ($pbox[1] + $pbox[3]) - $ys * $scale * ($prbox[2] - $prbox[0])));
                $slist[1] = cm(@scalestr,
#                        -0.5 * $ys * $scale * $prbox[0] + $pbox[1]);
                         .25 * (3 * $pbox[1] + $pbox[3] - $ys * $scale * ($prbox[2] - $prbox[0])));
            } elsif ($opt_p == 2)                   # double page landscape on portrait
            {
                @scalestr = ($xs, 0, 0, 0.5 * $ys, .5 * ($pbox[2] - $xs * ($prbox[2] - $prbox[0])));
#                -$xs * $prbox[0] + $pbox[0]);
#                $slist[0] = cm(@scalestr, 0.5 * (-$ys * $prbox[1] + $pbox[1] + $pbox[3]));
#                $slist[1] = cm(@scalestr, -0.5 * $ys * $prbox[1] + $pbox[1]);
                $slist[0] = cm(@scalestr, .25 * (3 * $pbox[3] + $pbox[1] - $ys * ($prbox[3] - $prbox[1])) - $prbox[1]);
                $slist[1] = cm(@scalestr, .25 * (3 * $pbox[1] + $pbox[3] - $ys * ($prbox[3] - $prbox[1])) - $prbox[1]);
            } elsif ($opt_p == 4 && $is == 1)       # true portrait
            {
                $a = .5 * $xs; $b = .5 * $ys;
                $slist[0] = cm($a, 0, 0, $b,
                        -$a * $prbox[0] + 0.5 * ($pbox[0] + $pbox[2]), -$b * $prbox[1] + $pbox[1]);
                $slist[1] = cm(-$a, 0, 0, -$b,
                        $a * $prbox[0] + $pbox[2], $b * $prbox[1] + $pbox[3]);
                $slist[2] = cm(-$a, 0, 0, -$b,
                        $a * $prbox[0] + 0.5 * ($pbox[0] + $pbox[2]), $b * $prbox[1] + $pbox[3]);
                $slist[3] = cm($a, 0, 0, $b,
                        -$a * $prbox[0] + $pbox[0], -$b * $prbox[1] + $prbox[1]);
            } elsif ($opt_p == 4)
            {
                $a = .5 * $ys * $scale; $b = .5 * $xs / $scale;
                $slist[0] = cm(0, -$a, $b, 0,
                        -$b * $prbox[1] + 0.5 * ($pbox[0] + $pbox[2]), $a * $prbox[2] + $pbox[1]);
                $slist[1] = cm(0, $a, -$b, 0,
                        $b * $prbox[1] + $pbox[2], -$a * $prbox[2] + $pbox[3]);
                $slist[2] = cm(0, $a, -$b, 0,
                        $b * $prbox[1] + 0.5 * ($pbox[0] + $pbox[2]), -$a * $prbox[2] + $pbox[3]);
                $slist[3] = cm(0, -$a, $b, 0,
                        -$b * $prbox[1] + $pbox[0], $a * $prbox[2] + $pbox[1]);
            }
            $scache{$id} = [@slist];
        }
        @s = $pr[$j]->{'Contents'}->elementsof if (defined $pr[$j]->{'Contents'});
        if (!defined $s)
        {
            $min = 100000;
            for ($k = 0; $k <= $#pr; $k++)
            {
                next unless defined $pr[$k];
                if ($pr[$k]->{' pnum'} < $min)
                {
                    $bp = $pr[$k];
                    $min = $pr[$k]->{' pnum'};
                }
            }
            $s = PDFArray();
            $bp->{' Contents'} = $p->new_obj($s);
            $bp->{'Rotate'} = PDFNum(90) if ($opt_r);
        }
        next unless defined $pr[$j];
        $s->add_elements($fpgins) unless $j == $#pr;
        $s->add_elements($scache{$id}[$j]) unless ($opt_h == 17 && $j == $#pr);
        $s->add_elements(@s);
        $s->add_elements($spgins) unless $j == $#pr;

        if ($pr[$j] ne $bp)
        {
            $pr2 = $pr[$j];
            $s1 = $bp->find_prop('Resources');
            $s2 = $pr2->find_prop('Resources');
            $bp->{'Resources'} = merge_dict($s1, $s2) unless ($s1 eq $s2);

            $p->free_obj($pr2);
            while (defined $pr2->{'Parent'})
            {
                $temp = $pr2->{'Parent'};
                $temp->{'Kids'}->removeobj($pr2);
                $temp->{'Count'}{'val'}--;
                $p->out_obj($temp);
                if ($pr2->{'Parent'}{'Kids'}->elementsof <= 0)
                {
                    print "Killing a tree! $pr2->{'Parent'}{'num'}\n" unless $opt_q;
                    $pr2 = $pr2->{'Parent'};
                    $p->free_obj($pr2);
                } else
                {
                    $pr2 = $temp->{'Parent'};
                    while (defined $pr2)
                    {
                        $p->out_obj($pr2);
                        $pr2->{'Count'}{'val'}--;
                        $pr2 = $pr2->{'Parent'};
                    }
                }
            }
        }
    }
    return 1 unless defined $bp;
    $bp->{'Contents'} = $bp->{' Contents'};
    undef $bp->{' Contents'};
    foreach (qw(Annots Thumb Beeds CropBox))
    { delete $bp->{$_} if defined $bp->{$_}; }
    $bp->bbox(@pbox);
    $p->out_obj($bp);
}

sub merge_dict
{
    my ($p1, $p2) = @_;

    return $p1 if (ref $p1 eq "Text::PDF::Objind" && ref $p2 eq "Text::PDF::Objind"
            && $p->{' objects'}{$p1->uid}[0] eq $p->{' objects'}{$p2->uid}[0]);
    $p1 = $p->read_obj($p1) if (ref $p1 eq "Text::PDF::Objind");
    $p2 = $p->read_obj($p2) if (ref $p2 eq "Text::PDF::Objind");

    my ($k, $v1, $v2);
    my (@a1, @a2, %a1);

    foreach $k (keys %{$p1})
    {
        next if ($k =~ m/^\s/oi);
        $v1 = $p1->{$k};
        $v2 = $p2->{$k};
        next if $v1 eq $v2 || !defined $v2;     # !defined added v1.201
        if (ref $v1 eq "Text::PDF::Objind" || ref $v2 eq "Text::PDF::Objind")
        {
            $v1 = $p->read_obj($v1) if (ref $v1 eq "Text::PDF::Objind");
            $v2 = $p->read_obj($v2) if (ref $v2 eq "Text::PDF::Objind");
        }
        next unless defined $v2;
        
# assume $v1 & $v2 are of the same type
        if (ref $v1 eq "Text::PDF::Array")
        {
# merge contents of array uniquely (the array is a set)
            @a1 = $v1->elementsof;
            @a2 = $v2->elementsof;
            map { $a1{$_} = 1; } @a1;
            push (@a1, grep (!$a1{$_}, @a2));
            $p1->{$k} = PDFArray(@a1);
        } elsif (ref $v1 eq "Text::PDF::Dict")
#        { $p1->{$k} = merge_dict($v1->val, $v2->val); }
        { $p1->{$k} = merge_dict($v1, $v2); }
        elsif ($v1->val ne $v2->val)
        { warn "Inconsistent dictionaries at $k with " . $v1->val . " and " . $v2->val; }
    }

    foreach $k (grep (!defined $p1->{$_} && $_ !~ m/^\s/oi, keys %{$p2}))
    { $p1->{$k} = $p2->{$k}; }
    $p->out_obj($p1) if $p1->is_obj($p);
    return $p1;
}


sub cm
{
    my (@a) = @_;
    my ($res, $r);

    foreach $r (@a)
    { $r = int($r) if (abs($r - int($r)) < 1e-6); }
    return undef if ($a[0] == 1 && $a[1] == 0 && $a[2] == 0 && $a[3] == 1 && $a[4] == 0 && $a[5] == 0);

    $res = PDFDict();
    $p->new_obj($res);
    $res->{' stream'} = "$a[0] $a[1] $a[2] $a[3] $a[4] $a[5] cm";
    $res;
}

