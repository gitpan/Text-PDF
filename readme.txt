                        Text::PDF

There seem to be a growing plethora of Perl modules for creating and
manipulating PDF files. This module is no exception. Beyond the standard
features you would expect from a PDF manipulation module there are:

FEATURES

 .  Works with more than one PDF file open at once
 .  Supports TrueType fonts as well as the base 14 (requires Font::TTF module)
        including Type0 glyph based fonts (for Unicode)

UN-FEATURES (which may one day be fixed)

 .  No nice higher level interface for rendering and Page description insertion
 .  No support for Type1 or Type3 fonts
 .  No higher level support of annotations, bookmarks, hot-links, etc.
 .  This is Alpha code which works for my apps. but may not for yours :)
 .  No test code

In summary, this module provides a strong (IMO) base for working with PDF files
but lacks some finesse. Users should know their way around the PDF specification.


REQUIREMENTS

For the most part, this module set requires Compress::Zlib. It is used
for compressed streams and within the Standard Fonts.

INSTALLATION

If you want to have TrueType support in your application, then you will
need to install the Font::TTF module (available from CPAN) as well.

Installation is as per the standard module installation approach:

perl Makefile.PL
make
make install

CONTACT

Bugs, comments and offers of collaboration to: Martin_Hosken@sil.org

