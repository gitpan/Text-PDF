package PDF::Number;

=head1 NAME

PDF::Number - Numbers in PDF. Inherits from L<PDF::String>

=head1 METHODS

=cut

use strict;
use vars qw(@ISA);

use PDF::String;
@ISA = qw(PDF::String);


=head2 $n->convert($str)

Converts a string from PDF to internal, by doing nothing

=cut

sub convert
{ return $_[1]; }


=head2 $n->outobjdeep($fh)

Outputs a number in PDF format.

=cut

sub outobjdeep
{
    my ($self, $fh) = @_;

    if ($self->is_obj)
    {
        $self->{' loc'} = tell($fh);
        print $fh "$self->{' objnum'} $self->{' objgen'} obj\n";
    }
    print $fh $self->{'val'};
    print $fh "\nendobj\n" if $self->is_obj;
    $self;
}


