use 5.006;
use ExtUtils::MakeMaker;
WriteMakefile(
    NAME		=> 'CRS',
    VERSION_FROM	=> 'CRS/Tracker/Client.pm',
    PREREQ_PM		=> {
			    File::Spec      => 0,
			    File::Which     => 0,
			    XML::Simple     => 0,
			    XML::RPC::Fast  => 0,
			    Digest::SHA     => 0,
			    Net::Domain     => 0,
			    URI::Escape     => 0,
			    IO::Socket::SSL => 0,
			   },
);
