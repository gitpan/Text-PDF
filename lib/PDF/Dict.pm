package PDF::Dict;

use strict;
use vars qw(@ISA $mincache $tempbase);

use PDF::Objind;
@ISA = qw(PDF::Objind);

use PDF::Filter;

BEGIN
{
    my $temp_dir = -d '/tmp' ? '/tmp' : $ENV{TMP} || $ENV{TEMP};
    $tempbase = sprintf("%s/%d-%d-0000", $temp_dir, $$, time());
    $mincache = 32768;
}

=head1 NAME

PDF::Dict - PDF Dictionaries and Streams. Inherits from L<PDF::Objind>

=head1 INSTANCE VARIABLES

There are various special instance variables which are used to look after,
particularly, streams. Each begins with a space:

=item stream

Holds the stream contents for output

=item streamfile

Holds the stream contents in an external file rather than in memory. This is
not the same as a PDF file stream. The data is stored in its unfiltered form.

=item streamloc

If both ' stream' and ' streamfile' are empty, this indicates where in the
source PDF the stream starts.

=head1 METHODS

=head2 PDF::Dict->new($parent)

Creates a dictionary with the given storage parent (note this is not, for example
an owning dictionary, but the parent of that dictionary.)

=cut

sub new
{ return bless {' parent' => $_[1]}, $_[0]; }


=head2 $d->outobjdeep($fh)

Outputs the contents of the dictionary to a PDF file. This is a recursive call.

It also outputs a stream if the dictionary has a stream element. If this occurs
then this method will calculate the length of the stream and insert it into the
stream's dictionary.

=cut

sub outobjdeep
{
    my ($self, $fh) = @_;
    my ($key, $val, $f, @filts);
    my ($loc, $str);

    $self->SUPER::outobjdeep($fh);

    if (defined $self->{' stream'} or defined $self->{' streamfile'} or defined $self->{' streamloc'})
    {
        if ((defined $self->{'Filter'} && $self->{'Filter'} ne "") || !defined $self->{' stream'})
        {
            $self->{'Length'} = PDF::Number->new($self->{' parent'}, 0)
                    unless defined $self->{'Length'};
            $self->{' parent'}->new_obj($self->{'Length'}) unless $self->{'Length'}->is_obj;
        } else
        { $self->{'Length'} = PDF::Number->new($self->{' parent'}, length($self->{' stream'}) + 1); }
    }

    print $fh "<<\n";
    if (defined $self->{'Type'})
    {
        print $fh "/Type ";
        $self->{'Type'}->outobj($fh);
        print $fh "\n";
    }
    while (($key, $val) = each %{$self})
    {
        next if ($key =~ m/^\s/oi || $key eq "Type");
        next if $val eq "";
        $key =~ s|([\000-\020%()\[\]{}<>#/])|"#".sprintf("%02X", ord($1))|oige;
        print $fh "/$key ";
        $val->outobj($fh);
        print $fh "\n";
    }
    print $fh ">>";

#now handle the stream (if any)
    if (defined $self->{' streamloc'} && !defined $self->{' stream'})
    {                                   # read a stream if infile
        $loc = tell($fh);
        $self->read_stream;
        seek($fh, $loc, 0);
    }

    if (defined $self->{'Filter'})
    {
        foreach $f ($self->{'Filter'}->elementsof)
        {
            my ($temp) = "PDF::" . $f->val;
            push(@filts, $temp->new());
        }
    }

    if (defined $self->{' stream'})
    {
        print $fh "\nstream\n";
        $loc = tell($fh);
        $str = $self->{' stream'};
        foreach $f (reverse @filts)
        { $str = $f->outfilt($str, 1); }
        print $fh $str;
        $self->{'Length'}{'val'} = tell($fh) - $loc + 1 if $#filts >= 0;
        print $fh "\nendstream";
#        $self->{'Length'}->outobjdeep($fh);
    } elsif (defined $self->{' streamfile'})
    {
        open(DICTFH, $self->{' streamfile'}) || die "Unable to open $self->{' streamfile'}";
        binmode DICTFH;
        print $fh "\nstream\n";
        $loc = tell($fh);
        while (read(DICTFH, $str, 4096))
        {
            foreach $f (reverse @filts)
            { $str = $f->outfilt($str, 0); }
            print $fh $str;
        }
        close(DICTFH);
        $str = "";
        foreach $f (reverse @filts)
        { $str = $f->outfilt($str, 1); }
        print $fh $str;
        $self->{'Length'}{'val'} = tell($fh) - $loc + 1;
        print $fh "\nendstream\n";
#        $self->{'Length'}->outobjdeep($fh);
    }

    print $fh "\nendobj\n" if $self->is_obj;
}


=head2 $d->read_stream($force_memory)

Reads in a stream from a PDF file. If the stream is greater than
C<PDF::Dict::mincache> (defaults to 32768) bytes to be stored, then
the default action is to create a file for it somewhere and to use that
file as a data cache. If $force_memory is set, this caching will not
occur and the data will all be stored in the $self->{' stream'}
variable.

=cut

sub read_stream
{
    my ($self, $force_memory) = @_;
    my ($fh) = $self->{' parent'}{' INFILE'};
    my (@filts, $f, $last, $i, $dat);

    if (defined $self->{'Filter'})
    {
        foreach $f ($self->{'Filter'}->elementsof)
        { push(@filts, {"PDF::" . $f->val}->new); }
    }

    $last = 0;
    if (defined $self->{' streamfile'})
    {
        unlink ($self->{' streamfile'});
        $self->{' streamfile'} = undef;
    }
    seek ($fh, $self->{' streamloc'}, 0);
    for ($i = 0; $i < $self->{'Length'}; $i += 4096)
    {
        if ($i + 4096 > $self->{'Length'})
        {
            $last = 1;
            read($fh, $dat, $self->{'Length'} - $i);
        }
        else
        { read($fh, $dat, 4096); }

        foreach $f (@filts)
        { $dat = $f->infilt($dat, $last); }
        if (!defined $self->{' streamfile'} && length($dat) + length($dat) > $mincache)
        {
            open (DICTFH, ">$tempbase") || next;
            binmode DICTFH;
            $self->{' streamfile'} = $tempbase;
            $tempbase =~ s/-(\d+)$/"-" . ($1 + 1)/oe;        # prepare for next use
            print DICTFH $self->{' stream'};
            undef $self->{' stream'};
        }
        if (defined $self->{' streamfile'})
        { print DICTFH $dat; }
        else
        { $self->{' stream'} .= $dat; }
    }
    
    close DICTFH if (defined $self->{' streamfile'});
    $self;
}
        
=head2 $d->val

Returns the dictionary, which is itself.

=cut

sub val
{ $_[0]; }



