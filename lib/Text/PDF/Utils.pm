package Text::PDF::Utils;

=head1 NAME

Text::PDF::Utils - Utility functions for PDF library

=head1 DESCRIPTION

A set of utility functions to save the fingers of the PDF library users!

=head1 FUNCTIONS

=cut

use strict;

use Text::PDF::Array;
use Text::PDF::Bool;
use Text::PDF::Dict;
use Text::PDF::Name;
use Text::PDF::Number;
use Text::PDF::String;

use Exporter;
use vars qw(@EXPORT @ISA);
@ISA = qw(Exporter);
@EXPORT = qw(PDFBool PDFArray PDFDict PDFName PDFNum PDFStr
             asPDFBool asPDFName asPDFNum asPDFStr);


=head2 PDFBool

Creates a Bool via Text::PDF::Bool->new

=cut

sub PDFBool
{ Text::PDF::Bool->new(@_); }


=head2 PDFArray

Creates an array via Text::PDF::Array->new

=cut

sub PDFArray
{ Text::PDF::Array->new(@_); }


=head2 PDFDict

Creates a dict via Text::PDF::Dict->new

=cut

sub PDFDict
{ Text::PDF::Dict->new(@_); }


=head2 PDFName

Creates a name via Text::PDF::Name->new

=cut

sub PDFName
{ Text::PDF::Name->new(@_); }


=head2 PDFNum

Creates a number via Text::PDF::Number->new

=cut

sub PDFNum
{ Text::PDF::Number->new(@_); }


=head2 PDFStr

Creates a string via Text::PDF::String->new

=cut

sub PDFStr
{ Text::PDF::String->new(@_); }


=head2 asPDFBool

Returns a boolean value in PDF output form

=cut

sub asPDFBool
{ Text::PDF::Bool->new(@_)->as_pdf; }


=head2 asPDFStr

Returns a string in PDF output form (including () or <>)

=cut

sub asPDFStr
{ Text::PDF::String->new(@_)->as_pdf; }


=head2 asPDFName

Returns a Name in PDF Output form (including /)

=cut

sub asPDFName
{ Text::PDF::Name->new(@_)->as_pdf; }


=head2 asPDFNum

Returns a number in PDF output form

=cut

sub asPDFNum
{ $_[0]; }          # no translation needed

1;

