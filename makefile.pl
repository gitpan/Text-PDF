use ExtUtils::MakeMaker;

@scripts = glob("scripts/*.*");

WriteMakefile (
        NAME => "PDF",
        VERSION => "0.01",
        EXE_FILES => \@scripts
    );
    
