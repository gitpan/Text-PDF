package PDF::String;

=head1 NAME

PDF::String - PDF String type objects and superclass for simple objects
that are basically stringlike (Number, Name, etc.)

=head1 METHODS

=cut

use strict;
use vars qw(@ISA %trans %out_trans);

use PDF::Objind;
@ISA = qw(PDF::Objind);

%trans = (
    "n" => "\n",
    "r" => "\r",
    "t" => "\t",
    "b" => "\b",
    "f" => "\f",
    "\\" => "\\",
    "(" => "(",
    ")" => ")"
        );

%out_trans = (
    "\n" => "n",
    "\r" => "r",
    "\t" => "t",
    "\b" => "b",
    "\f" => "f",
    "\\" => "\\",
    "(" => "(",
    ")" => ")"
             );


=head2 PDF::String->new($parent, $string)

Creates a new string object (not a full object yet) from a given string.
The string is parsed according to input criteria with escaping working.
Since there is no clash between an escaped and final form of a character
in a string, strings can be passed in already converted.

=cut

sub new
{
    my ($class, $par, $str) = @_;
    my ($self);

    $self->{' parent'} = $par;
    
    bless $self, $class;
    $self->{'val'} = $self->convert($str);
    return $self;
}


=head2 $s->convert($str)

Returns $str converted as per criteria for input from PDF file

=cut

sub convert
{
    my ($self, $str) = @_;

    $str =~ s/\\([nrtbf\\()])/$trans{$1}/ogi;
    $str =~ s/\\([0-7]+)/oct($1)/oegi;
    1 while $str =~ s/\<([0-9a-f]{2})/hex($1)."\<"/oige;
    $str =~ s/\<([0-9a-f])\>/hex($1 . "0")/oige;
    $str =~ s/\<\>//oig;
    return $str;
}


=head2 $s->val

Returns the value of this string (the string itself).

=cut

sub val
{ $_[0]->{'val'}; }


=head2 $s->outobjdeep

Outputs the string in PDF format, complete with necessary conversions

=cut

sub outobjdeep
{
    my ($self, $fh) = @_;
    my ($str) = $self->{'val'};

    $self->SUPER::outobjdeep($fh);

    if ($str =~ m/[^\n\r\t\b\f\040-\176]/oi)
    {
        $str =~ s/./sprintf("%02X", ord($1))/oige;
        print $fh "<$str>";
    } else
    {
        $str =~ s/([\n\r\t\b\f\\()])/\\$out_trans{$1}/ogi;
        print $fh "($str)";
    }

    print $fh "\nendobj\n" if $self->is_obj;
}

