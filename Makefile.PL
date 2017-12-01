use 5.006;
use ExtUtils::MakeMaker;
WriteMakefile(
    NAME		=> 'C3TT',
    VERSION_FROM	=> 'C3TT/Client.pm',
    PREREQ_PM		=> {
			    File::Spec      => 0,
			    File::Which     => 0,
			    XML::Simple     => 0,
			    Encode          => 0,
			    XML::RPC::Fast  => 0,
			    Digest::SHA     => 0,
			    Net::Domain     => 0,
			    URI::Escape     => 0,
			    IO::Socket::SSL => 0,
			    Data::Dumper    => 0,
			   },
);
