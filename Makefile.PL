use ExtUtils::MakeMaker;

@scripts = grep {-f } glob("scripts/*.*");

WriteMakefile (
        NAME => "Text::PDF",
        VERSION_FROM => "lib/Text/PDF/File.pm",
        EXE_FILES => \@scripts,
        AUTHOR => "martin_hosken\@sil.org",
        ABSTRACT => "PDF Manipulation and generation",
    );
    
