package Text::PDF::Name;

use strict;
use vars qw(@ISA);
no warnings qw(uninitialized);

use Text::PDF::String;
@ISA = qw(Text::PDF::String);

=head1 NAME

Text::PDF::Name - Inherits from L<Text::PDF::String> and stores PDF names (things
beginning with /)

=head1 METHODS

=head2 Text::PDF::Name->from_pdf($string)

Creates a new string object (not a full object yet) from a given string.
The string is parsed according to input criteria with escaping working, particular
to Names.

=cut


sub from_pdf
{
    my ($class, $str) = @_;
    my ($self) = $class->SUPER::from_pdf($str);
    
    $self->{'val'} =~ s/\#([0-9A-F][0-9A-F])/chr(hex($1))/ge;   # thanks to rlandrum@capitoladvantage.com
    $self;
}

=head2 $n->convert

Converts a name into a string by removing the / and converting any hex munging

=cut

sub convert
{
    my ($self, $str) = @_;

    $str =~ s/^\\//o;
    $str =~ s/\#([0-9a-f]{2})/hex($1)/oige;
    return $str;
}


=head2 as_pdf

Returns a name formatted as PDF

=cut

sub as_pdf
{
    my ($self) = @_;
    my ($str) = $self->{'val'};
    
    $str =~ s|([\000-\020%()\[\]{}<>#/])|"#".sprintf("%02X", ord($1))|oge;
    return ("/" . $str);
}

