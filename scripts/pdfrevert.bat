@rem = ('--*-Perl-*--
@echo off
if not exist %0 goto n1
perl %0 %1 %2 %3 %4 %5 %6 %7 %8 %9
goto endofperl
:n1
if not exist %0.bat goto n2
perl %0.bat %1 %2 %3 %4 %5 %6 %7 %8 %9
goto endofperl
:n2
perl -S %0.bat %1 %2 %3 %4 %5 %6 %7 %8 %9
goto endofperl
@rem ') if 0;

require PDF::File;

$cr = '\s*(?:\r|\n|(?:\r\n))';
$VERSION = "1.000";         # MJPH   6-NOV-1998     Original

$f = PDF::File->open($ARGV[0], 1);
exit unless defined $f->{'Prev'};
$loc = $f->{'Prev'}->val;
$fd = $f->{' INFILE'};
seek($fd, $loc, 0);
$rest = "";
while ($len = read($fd, $dat, 1024))
{
    $len += length($rest);
    $_ = $rest . $dat;
    if (m/(?:\r|\n|(?:\r\n))%%EOF$cr/oi)
    {
        $loc += length($` . $&);
        last;
    }
    elsif (m/$cr(.*?)$/oi)
    {
        $rest = $1;
        $loc += $len - length($rest);
    }
}

if ($len != 0)
{
    truncate($fd, $loc) || die "Can't truncate";
}
__END__
:endofperl
