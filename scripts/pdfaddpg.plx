
use Text::PDF::File;
use Text::PDF::Utils;
use Text::PDF::Page;
use Getopt::Std;

$version = "1.002";     # MJPH  10-DEC-1999     Fix page counts for pages objs.
# $version = "1.001";     # MJPH  30-NOV-1999     Original

getopts("b:h:p:qrs:");

if (!defined $ARGV[0])
{
    die <<"EOT";
    PDFADDPG [-b num/size] [-p num] [-q] pdffile

 (c) M. Hosken.     Version: $version

    Inserts a blank page of given or calculated size after the given page. The
new information is appended to pdffile and can be reverted.

  -b num/size    Specifies which page contains the output page size details
            or gives the dimensions of the page in pts (x,y). [inherited or 1]
  -p num    Specifies the page number after which to insert [last page]
  -q        Quiet (no on screen messages)
EOT
}

print "Reading file\n" unless $opt_q;
$p = Text::PDF::File->open($ARGV[0], 1);          # open file for appending
$r = $p->read_obj($p->{'Root'});            # read the page root
$pgs = $p->read_obj($r->{'Pages'});         # Get the pages tree
$pgcount = $pgs->{'Count'}->val;            # how many pages
$opt_p = -1 unless defined $opt_p;

if ($opt_b =~ m/^([0-9]+)\;([0-9]+)/oi)     # parse $opt_b making @pbox
{
    @pbox = (0, 0, $1, $2);
    $opt_b = 0;
}
else
{ $opt_b = -1 unless defined $opt_b; }

proc_pages($pgs, 0);                        # count recursively through and insert

# now set the page's bounding box if it needs setting
if ($opt_b != -1 || $newpage->find_prop('MediaBox') eq "")
{ $newpage->bbox(@pbox); }

$p->append_file;                            # update appended file


# note external references to $pgcount, @pbox, $newpage, $opt_b, $opt_p
sub proc_pages
{
    my ($pgs, $cur) = @_;
    my ($pg, $pgref, $i);

    foreach $pgref ($pgs->{'Kids'}->elementsof)
    {
        print STDERR "." unless $opt_q;
        $pg = $p->read_obj($pgref);
        if ($pg->{'Type'}->val =~ m/^Pages$/oi)
        { $cur = proc_pages($pg, $cur); }
        else
        {
            $cur++;
            if ($cur == $opt_b || ($cur == 1 && $opt_b == -1))
            {
                my ($n);
                
                foreach $n ($pg->find_prop('MediaBox')->elementsof)
                { push(@pbox, $n->val); }
            }
            if ($opt_p == -1 && $cur == $pgcount)
            {
                $i++;
                $opt_p = $cur - 1;
            }
            if ($opt_p == $cur - 1)
            { $newpage = Text::PDF::Page->new($p, $pgs, $i); }
        }
        $i++;
    }
    $cur;
}

print STDERR "\n" unless $opt_q;

