package PDF::Bool;

use strict;
use vars qw(@ISA);

use PDF::String;
@ISA = qw(PDF::String);

=head1 NAME

PDF::Bool - A special form of L<PDF::String> which holds the strings
B<true> or B<false>

=head1 METHODS

=head2 $b->convert($str)

Converts a string into the string which will be stored.

=cut

sub convert
{ return $_[1]; }


=head2 $b->outobjdeep($fh)

Outputs 'true' or 'false' depending on the boolean state as perceived by Perl.

=cut

sub outobjdeep
{
    my ($self, $fh) = @_;
    
    if ($self->is_obj)
    {
        $self->{' loc'} = tell($fh);
        print $fh "$self->{' objnum'} $self->{' objgen'} obj\n";
    }
    print $fh $self->{'val'} ? "true" : "false";
    print $fh "\nendobj\n" if $self->is_obj;
    $self;
}

