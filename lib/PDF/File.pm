package PDF::File;

=head1 NAME

PDF::File - Holds the trailers and cross-reference tables for a PDF file

=head1 SYNOPSIS

 $p = PDF::File->open("filename.pdf", 1);
 $p->newobj($obj_ref);
 $p->freeobj($obj_ref);
 $p->appendfile;
 $p->addchanges;
 $p->close;

=head1 DESCRIPTION

This class keeps track of the directory aspects of a PDF file. There are two
parts to the directory: the main directory object which is the parent to all
other objects and a chain of cross-reference tables and corresponding trailer
dictionaries starting with the main directory object.

=head1 INSTANCE VARIABLES

Within this class hierarchy, rather than making everything visible via methods,
which would be a lot of work, there are various instance variables which are
accessible via associative array referencing. To distinguish instance variables
from content variables (which may come from the PDF content itself), each such
variable will start with a space.

Variables which do not start with a space directly reflect elements in a PDF
dictionary. In the case of a PDF::File, the elements reflect those in the
trailer dictionary.

Since some variables are not designed for class users to access, variables are
marked in the documentation with (R) to indicate that such an entry should only
be used as read-only information. (P) indicates that the information is private
and not designed for user use at all, but is included in the documentation for
completeness and to ensure that nobody else tries to use it.

=over

=item newroot

This variable allows the user to create a new root entry to occur in the trailer
dictionary which is output when the file is written or appended. If you wish to
over-ride the root element in the dictionary you have, use this entry to indicate
that without losing the current Root entry. Notice that newroot should point to
a PDF level object and not just to a dictionary which does not have object status.

=item INFILE (R)

Contains the filehandle used to read this information into this PDF directory.

=item fname (R)

This is the filename which is reflected by INFILE.

=item update (R)

This indicates that the read file has been opened for update and that at some
point, $p->appendfile() can be called to update the file with the changes that
have been made to the memory representation.

=item maxobj (R)

Contains the first useable object number above any that have already appeared
in the file so far.

=item outlist (P)

This is a list of Objind which are to be output when the next appendfile or outfile
occurs.

=item firstfree (P)

Contains the first free object in the free object list. Free objects are removed
from the front of the list and added to the end.

=item lastfree (P)

Contains the last free object in the free list. It may be the same as the firstfree
if there is only one free object.

=item objcache (P)

All objects are held in the cache to ensure that a system only has one occurrence of
each object. In effect, the objind class acts as a container type class to hold the
PDF object structure and it would be unfortunate if there were two identical
place-holders floating around a system.

=item epos (P)

The end location of the read-file.

=back

Each trailer dictionary contains a number of private instance variables which
hold the chain together.

=over

=item loc (P)

Contains the location of the start of the cross-reference table preceding the
trailer.

=item xref (P)

Contains an anonymous array of each cross-reference table entry.

=item prev (P)

A reference to the previous table. Note this differs from the Prev entry which
is in PDF which contains the location of the previous cross-reference table.

=back

=head1 METHODS

=cut

use strict;
no strict "refs";
use vars qw($cr %types $version);
use Symbol();

# Now for the basic PDF types
use PDF::Array;
use PDF::Bool;
use PDF::Dict;
use PDF::Name;
use PDF::Number;
use PDF::Objind;
use PDF::String;

$version = "1.001";     # MJPH  13-OCT-1998     Return objind from read_obj

BEGIN
{
    my ($t, $type);
    
    $cr = '\s*(?:\r|\n|(?:\r\n))';
    %types = (
            'Page' => 'PDF::Page',
            'Pages' => 'PDF::Pages'
    );
    
    foreach $type (keys %types)
    {
        $t = $types{$type};
        $t =~ s|::|/|oig;
        require "$t.pm";
    }
}
            

=head2 PDF::File->new

Creates a new, empty file object which can act as the host to other PDF objects.
Since there is no file associated with this object, it is assumed that the
object is created in readiness for creating a new PDF file.

=cut

sub new
{
    my ($class) = @_;
    my ($self) = $class->_new;
    my ($root);

    $root = PDF::Dict->new($self);
    $root->{'Type'} = PDF::Name->new($self, "Catalog");
    $self->new_obj($root);
    $self->{'Root'} = $root;
    $self;
}


=head2 $p = PDF::File->open($filename, $update)

Opens the file and reads all the trailers and cross reference tables to build
a complete directory of objects.

$update specifies whether this file is being opened for updating and editing,
or simply to be read.

=cut

sub open
{
    my ($class, $fname, $update) = @_;
    my ($self, $buf, $xpos, $end, $tdict, $k);
    my ($fh) = Symbol->gensym();

    $self = $class->_new;
    $self->{' INFILE'} = $fh;
    $self->{' fname'} = $fname;
    $self->{' update'} = $update;
    open ($fh, ($update ? "+" : "") . "<$fname")
            || die "Can't ". ($update ? "update" : "read") . " $fname";
    binmode $fh;
    read($fh, $buf, 255);
    if ($buf !~ m/^\%pdf\-1\.[0-2]\s*$cr/moi)
    { die "$fname not a PDF file version 1.0-1.2"; }

    seek($fh, 0, 2);            # go to end of file
    $end = tell($fh);
    $self->{' epos'} = $end;
    seek ($fh, $end - 32, 0);
    read($fh, $buf, 32);
    if ($buf !~ m/startxref$cr([0-9]+)$cr\%\%eof/oi)
    { die "Malformed PDF file $fname"; }
    $xpos = $1;
    
    $tdict = $self->readxrtr($xpos, $self);
    foreach $k (keys %{$tdict})
    { $self->{$k} = $tdict->{$k}; }
    return $self;
}


=head2 $p->append_file()

Appends the objects for output to the read file and then appends the appropriate tale.

=cut

sub append_file
{
    my ($self) = @_;
    my ($tdict, $fh);
    
    return undef unless ($self->{' update'});
    $tdict = PDF::Dict->new($self);
    $tdict->{'Prev'} = PDF::Number->new($self, $self->{' loc'});
    $tdict->{'Info'} = $self->{'Info'};
    if (defined $self->{' newroot'})
    { $tdict->{'Root'} = $self->{' newroot'}; }
    else
    { $tdict->{'Root'} = $self->{'Root'}; }
    $tdict->{'Size'} = PDF::Number->new($self, $self->{'Size'}->val + $#{$self->{' outlist'}} + 1);
    $fh = $self->{' INFILE'};
    seek($fh, $self->{' epos'}, 0);
    $self->out_trailer($fh, $tdict);
}


=head2 $p->out_file($fname)

Writes a PDF file to a file of the given filename based on the current list of
objects to be output. It creates the trailer dictionary based on information
in $self.

=cut

sub out_file
{
    my ($self, $fname) = @_;
    my ($fh) = Symbol->gensym();
    my ($tdict);

    open($fh, ">$fname") || die "Unable to open $fname for writing";
    binmode $fh;

    $tdict = PDF::Dict->new($self);
    $tdict->{'Info'} = $self->{'Info'} if defined $self->{'Info'};
    $tdict->{'Root'} = $self->{' newroot'} ne "" ? $self->{' newroot'} : $self->{'Root'};

# remove all freed objects from the outlist
    @{$self->{' outlist'}} = grep(!$_->{' isfree'}, @{$self->{' outlist'}});
    $tdict->{'Size'} = PDF::Number->new($self, $#{$self->{' outlist'}} + 2);
    print $fh "%PDF-1.2\n";
    print $fh "%Çì¢\n";              # and some binary stuff in a comment
    $self->out_trailer($fh, $tdict);
    close($fh);
    $self;
}


=head2 ($value, $str) = $p->readval($str)

Reads a PDF value from the current position in the file. If $str is too short
then read some more from the current location in the file until the whole object
is read. This is a recursive call which may slurp in a whole big stream (unprocessed).

Returns the recursive data structure read and also the current $str that has been
read from the file.

=cut

sub readval
{
    my ($self, $str) = @_;
    my ($fh) = $self->{' INFILE'};
    my ($res, $key, $value, $k);

    $str = update($fh, $str);
    if ($str =~ m/^\<\<\s*$cr?/oi)                                      # dictionary
    {
        $str = $';
        $str = update($fh, $str);
        $res = PDF::Dict->new($self);
        while ($str !~ m/^\>\>$cr?/oi)
        {
            $str = update($fh, $str);
            if ($str =~ m|^/(\w+)$cr?|oi)
            {
                $k = $1; $str = $';
#                $key = PDF::Name->new($self, $k);
                ($value, $str) = $self->readval($str);
                $res->{$k} = $value;
            } else
            {
                $str =~ m/$cr/oi;
                $str = $';
            }
        }
        $str =~ s/^\>\>$cr?//oi;
        $str = update($fh, $str);
        if ($str =~ m/^stream$cr/oi && $res->{'Length'} != 0)           # stream
        {
            $str = $';
            $k = $res->{'Length'};
            if ($k > length($str))
            {
                $value = $str;
                $k -= length($str);
                read ($fh, $str, $k + 11);          # slurp the whole stream!
            } else
            { $value = ""; }
            $value .= substr($str, 0, $k);
            $res->{' stream'} = $value;
            $str = update($fh, $str);
            $str =~ m/^endstream$cr/oi;
            $str = $';
        }

        bless $res, $types{$res->{'Type'}->val}
                if (defined $res->{'Type'} && defined $types{$res->{'Type'}->val});
    } elsif ($str =~ m/^([0-9]+)\s+([0-9]+)\s+R$cr?/o)                  # objind
    {
        $k = $1;
        $value = $2;
        $str = $';
        $res = $self->test_obj($k, $value)
                || $self->add_obj(PDF::Objind->new($self, $k, $value));
    } elsif ($str =~ m/^([0-9]+)\s+([0-9]+)\s+obj$cr?/oi)               # object data
    {
        $k = $1;
        $value = $2;
        $str = $';
        ($res, $str) = $self->readval($str);
        $res->{' objnum'} = $k;
        $res->{' objgen'} = $value;
    } elsif ($str =~ m|^/(\w+)$cr?|oi)                                  # name
    {
        $value = $1;
        $str = $';
        $res = PDF::Name->new($self, $value);
    } elsif ($str =~ m/^\(/oi)                                          # string
    {
        $str = $';
        read($fh, $str, 255, length($str)) while ($str !~ m/\)/oi);
        $str =~ m/\)\s*$cr?/oi;
        $value = $`;
        $str = $';
        $res = PDF::String->new($self, $value);
    } elsif ($str =~ m/^\</oi)                                          # hex-string
    {
        $str = $';
        read($fh, $str, 255, length($str)) while ($str !~ m/\>/oi);
        $str =~ m/\>\s*$cr?/oi;
        $value = $`;
        $str = $';
        $res = PDF::String->new($self, "<" . $value . ">");
    } elsif ($str =~ m/^\[$cr?/oi)                                      # array
    {
        $str = $';
        $res = PDF::Array->new($self);
        while ($str !~ m/^\]$cr?/oi)
        {
            ($value, $str) = $self->readval($str);
            push (@{$res->{' val'}}, $value);
        }
        $str =~ s/^\]$cr?//oi;
    } elsif ($str =~ m/^((true)|(false))$cr?/oi)                        # boolean
    {
        $value = $1;
        $str = $';
        $res = PDF::Bool->new($self, $value eq "true");
    } elsif ($str =~ m/^([0-9]+)\s*$cr?/oi)                             # number
    {
        $value = $1;
        $str = $';
        $res = PDF::Number->new($self, $value);
    }
    return ($res, $str);
}

=head2 $ref = $p->read_obj($objind)

Given an indirect object reference, locate it and read the object returning
the read in object.

=cut

sub read_obj
{
    my ($self, $objind) = @_;
    my ($loc, $res, $str);

    return ($objind, $objind->{' loc'}) if defined $objind->{'obj'};
    $loc = $self->locate_obj($objind->val);
    seek($self->{' INFILE'}, $loc, 0);
    ($res, $str) = $self->readval("");
    $objind->merge($res);
    $objind->{' loc'} = $loc;
    return $objind;
}

=head2 $objind = $p->new_obj($obj)

Creates a new, free object reference based on free space in the cross reference chain.
If nothing free then thinks up a new number. If $obj then turns that object into this
new object rather than returning a new object.


=cut

sub new_obj
{
    my ($self, $base) = @_;
    my ($res);
    my ($tdict, $i, $ni, $ng);

    if (defined $self->{' firstfree'})
    {
        $res = $self->{' firstfree'};
        $self->{' firstfree'} = $res->{' nextfree'};
        if (defined $base)
        {
            $self->remove_obj($res);
            return $base->isobj($res->{' objnum'}, $res->{' objgen'});
        }
        else
        {
            $res->{' nextfree'} = undef;
            $res->{' isfree'} = undef;
            return $res;
        }
    }

    $tdict = $self;
    while (defined $tdict)
    {
        $i = 0;
        while ($tdict->{' xref'}{$i}[0] != 0)
        {
            $ni = $tdict->{' xref'}{$i}[0];
            if (!defined $self->locate_obj($ni, $tdict->{' xref'}{$ni}[1]))
            {
                $ng = $tdict->{' xref'}{$ni}[1];
                if (defined $base)
                { return $base->isobj($ni, $ng); }
                else
                {
                    $res = $self->test_obj($ni, $ng)
                            || $self->add_obj(PDF::Objind->new($self, $ni, $ng));
                    $tdict->{' xref'}{$i}[0] = $tdict->{' xref'}{$ni}[0];
                    $self->out_obj($res);
                    return $res;
                }
            }
            $i = $ni;
        }
        $tdict = $tdict->{' prev'}
    }

    $i = $self->{' maxobj'}++;
    if (defined $base)
    { return $base->isobj($i, 0); }
    else
    {
        $res = $self->add_obj(PDF::Objind->new($self, $i, 0));
        $self->out_obj($res);
        return $self->add_obj($res);
    }
}

=head2 $p->free_obj($objind)

Marks an object reference for output as being freed.

=cut

sub free_obj
{
    my ($self, $obj) = @_;

    if (!defined $self->{' firstfree'})
    { $self->{' firstfree'} = $self->{' lastfree'} = $obj; }
    else
    {
        $self->{' lastfree'}{' nextfree'} = $obj;
        $self->{' lastfree'} = $obj;
    }
    $obj->{' isfree'} = 1;
    $self->out_obj($obj);
}


=head2 $p->remove_obj($objind)

Removes the object from all places where we might remember it

=cut

sub remove_obj
{
    my ($self, $objind) = @_;

# who says it has to be fast
    @{$self->{' outlist'}} = grep($_ ne $objind, @{$self->{' outlist'}});
    $self->{' objcache'}{$objind->{' objnum'}, $objind->{' objgen'}} = undef
            if ($self->{' objcache'}{$objind->{' objnum'}, $objind->{' objgen'}} eq $objind);
    $self;
}

=head1 PRIVATE METHODS & FUNCTIONS

The following methods and functions are considered private to this class. This
does not mean you cannot use them if you have a need, just that they aren't really
designed for users of this class.

=head2 $offset = $p->locate_obj($num, $gen)

Returns a file offset to the object asked for by following the chain of cross
reference tables until it finds the one you want.

=cut

sub locate_obj
{
    my ($self, $num, $gen) = @_;
    my ($tdict, $ref);

    $tdict = $self;
    while (defined $tdict)
    {
        if (ref $tdict->{' xref'}{$num})
        {
            $ref = $tdict->{' xref'}{$num};
            if ($ref->[1] == $gen)
            {
                return $ref->[0] if ($ref->[2] eq "n");
                return undef;       # if $ref->[2] eq "f"
            }
        }
        $tdict = $tdict->{' prev'}
    }
    return undef;
}


=head2 update($fh, $str)

Keeps reading $fh for more data to ensure that $str has at least a line full
for C<readval> to work on. At this point we also take the opportunity to ignore
comments.

=cut

sub update
{
    my ($fh, $str) = @_;

    read($fh, $str, 255, length($str)) while $str !~ m/$cr/oi;
    while ($str =~ /^\s*\%(.*?)$cr/oi)
    { $str = $'; read($fh, $str, 255, length($str)) while $str !~ m/$cr/oi; }
    $str;
}


=head2 $p->out_obj($objind)

Indicates that the given object reference should appear in the output xref
table whether with data or freed.

=cut

sub out_obj
{
    my ($self, $obj) = @_;

    push (@{$self->{' outlist'}}, $obj) unless (grep($_ eq $obj, @{$self->{' outlist'}}));
}


=head2 $objind = $p->test_obj($num, $gen)

Tests the cache to see whether an object reference (which may or may not have
been getobj()ed) has been cached. Returns it if it has.

=cut

sub test_obj
{ $_[0]->{' objcache'}{$_[1], $_[2]}; }


=head2 $p->add_obj($objind)

Adds the given object to the internal object cache.

=cut

sub add_obj
{
    my ($self, $obj) = @_;
    my ($num, $gen) = ($obj->{' objnum'}, $obj->{' objgen'});

    $self->{' objcache'}{$num, $gen} = $obj;
    return $obj;
}


=head2 $tdict = $p->readxrtr($xpos)

Recursive function which reads each of the cross-reference and trailer tables
in turn until there are no more.

Returns a dictionary corresponding to the trailer chain. Each trailer also
includes the corresponding cross-reference table.

The structure of the xref private element in a trailer dictionary is of an
anonymous hash of cross reference elements by object number. Each element
consists of an array of 3 elements corresponding to the three elements read
in [location, generation number, free or used]. See the PDF Specification
for details.

=cut

sub readxrtr
{
    my ($self, $xpos) = @_;
    my ($tdict, $xlist, $buf, $xmin, $xnum, $fh, $xdiff);

    $fh = $self->{' INFILE'};
    seek ($fh, $xpos, 0);
    read($fh, $buf, 22);
    if ($buf !~ m/^xref$cr/oi)
    { die "Malformed xref in PDF file $self->{' fname'}"; }
    $buf = $';

    $xlist = {};
    while ($buf =~ m/^([0-9]+)\s+([0-9]+)$cr/oi)
    {
        $xmin = $1;
        $xnum = $2;
        $buf = $';
        $xdiff = length($buf);
        
        read($fh, $buf, 20 * $xnum - $xdiff + 15, $xdiff);
        while ($xnum-- > 0 && $buf =~ s/^0*([0-9]*)\s+0*([0-9]+)\s+(\S)$cr//oi)
        { $xlist->{$xmin++} = [$1, $2, $3]; }
    }

    if ($buf !~ /^trailer$cr/oi)
    { die "Malformed trailer in PDF file $self->{' fname'} at " . (tell($fh) - length($buf)); }

    $buf = $';

    ($tdict, $buf) = $self->readval($buf);
    $tdict->{' loc'} = $xpos;
    $tdict->{' xref'} = $xlist;
    $self->{' maxobj'} = $xmin if $xmin > $self->{' maxobj'};
    $tdict->{' prev'} = $self->readxrtr($tdict->{'Prev'}->val)
                if (defined $tdict->{'Prev'} && $tdict->{'Prev'}->val != 0);
    return $tdict;
}


=head2 $p->out_trailer($fh, $tdict)

Outputs the body and trailer for a PDF file by outputting all the objects in
the ' outlist' and then outputting a xref table for those objects and any
freed ones. It then outputs the trailing dictionary and the trailer code.

=cut

sub out_trailer
{
    my ($self, $fh, $tdict) = @_;
    my ($objind, $j, $i, $iend, @xreflist, $first, $ff);
    my ($size) = $#{$self->{' outlist'}};
    
    foreach $objind (@{$self->{' outlist'}})
    { $objind->outobjdeep($fh) unless ($objind->{' isfree'}); }
    if ($#{$self->{' outlist'}} > $size)
    { $tdict->{'Size'}{'val'} += $#{$self->{' outlist'}} - $size; }
    $tdict->{' loc'} = tell($fh);
    print $fh "xref\n";

    @xreflist = sort byobjnum @{$self->{' outlist'}};

    $j = 0; $first = -1;
    $ff = defined $self->{' firstfree'} ? $self->{' firstfree'}{' objnum'} : 0;
    for ($i = 0; $i <= $#xreflist + 1; $i++)
    {
#        if ($i == 0)
#        {
#            $first = $i; $j = $xreflist[0]->{' objnum'};
#            printf $fh "0 1\n%010d 65535 f \n", $ff;
#        }
        if ($i > $#xreflist || $xreflist[$i]->{' objnum'} != $j + 1)
        {
            print $fh ($first == -1 ? "0 " : "$xreflist[$first]->{' objnum'} ") . ($i - $first) . "\n";
            if ($first == -1)
            {
                printf $fh "%010d 65535 f \n", $ff;
                $first = 0;
            }
            for ($j = $first; $j < $i; $j++)
            { $xreflist[$j]->outxref($fh); }
            $first = $i;
            $j = $xreflist[$i]->{' objnum'} if ($i <= $#xreflist);
        } else
        { $j++; }
    }
    print $fh "trailer\n";
    $tdict->outobjdeep($fh);
    print $fh "\nstartxref\n$tdict->{' loc'}\n" . '%%EOF' . "\n";
}

sub byobjnum
{ $a->{' objnum'} <=> $b->{' objnum'}; }


=head2 PDF::File->_new

Creates a very empty PDF file object (used by new and open)

=cut

sub _new
{
    my ($class) = @_;
    my ($self) = {};

    bless $self, $class;
    $self->{' outlist'} = [];
    $self->{' maxobj'} = 1;
    $self->{' objcache'} = {};
    $self;
}

1;

