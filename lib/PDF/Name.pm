package PDF::Name;

use strict;
use vars qw(@ISA);

use PDF::String;
@ISA = qw(PDF::String);

=head1 NAME

PDF::Name - Inherits from L<PDF::String> and stores PDF names (things
beginning with /)

=head1 METHODS

=head2 $n->convert

Converts a name into a string by removing the / and converting any hex munging

=cut

sub convert
{
    my ($self, $str) = @_;

    $str =~ s/^\\//oi;
    $str =~ s/\#([0-9a-f]{2})/hex($1)/oige;
    return $str;
}


=head2 $n->outobjdeep

Converts a string form of a name into PDF format

=cut

sub outobjdeep
{
    my ($self, $fh) = @_;
    my ($str) = $self->{'val'};
    
    if ($self->is_obj)
    {
        $self->{' loc'} = tell($fh);
        print $fh "$self->{' objnum'} $self->{' objgen'} obj\n";
    }

    $str =~ s|([\000-\020%()\[\]{}<>#/])|"#".sprintf("%02X", ord($1))|oige;
    print $fh "/" . $str;

    print $fh "\nendobj\n" if $self->is_obj;
}

