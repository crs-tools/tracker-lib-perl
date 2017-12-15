
package CRS::Fuse::TS;

use Math::Round;
use strict;
use parent qw(CRS::Fuse);

sub new {
    my ($class, @args) = @_; 
    my $self = $class->SUPER::new(@args);

    # set binary name
    $self->{fuse_binary} = 'fuse-ts';

    return bless($self);
}

sub getSourceFileLengthInSeconds {
	my $filepath = shift;
	my @files = qx ( ls $filepath* );
	my $filesecs = 0;
	my $files = 0;
	foreach (@files) {
		my $file = $_;
		chop $file;
		# Duration: 00:00:35.99
		my $size = qx ( ffprobe "$file" | grep Duration: );
		if ($size =~ /Duration:\ ([0-9]{2})\:([0-9]{2})\:([0-9]{2})\.([0-9]{2})/) {
			$size = $1 * 3600 + $2 * 60 + $3;
			$size++ if ($4 > 50);
			$filesecs += $size;
			$files++;
		}
	}
	return ($files,$filesecs);
}

sub checkCut {
	my ($self, $vid) = @_;
	$self->{'cutError'} = 'no VID given';
	return 0 unless defined($vid);
	my $p = $self->getMountPath($vid);
	print "checking mark IN of event $vid\n" if defined($self->{debug});
	$self->{'cutError'} = 'no inframe file';
	return 0 unless ( -r "$p/inframe" );
	my $t = qx ( cat "$p/inframe" );
	chop $t;
	$self->{'cutError'} = 'inframe unreadable or zero';
	return 0 unless defined($t) && ($t > 0);
	print "checking mark OUT of event $vid\n" if defined($self->{debug});
	$self->{'cutError'} = 'no outframe file';
	return 0 unless ( -r "$p/outframe" );
	$t = qx ( cat "$p/outframe" );
	chop $t;
	$self->{'cutError'} = 'outframe unreadable or zero';
	return 0 unless defined($t) && ($t > 0);
	print "checking virtual files of event $vid\n" if defined($self->{debug});
	$t = "$p/uncut.ts";
	$self->{'cutError'} = 'uncut.ts doesnt exist';
	return 0 unless (-f$t);
	### TODO verfuegbarkeit des quellmaterials pruefen -> erweiterung von fuse-ts
	$self->{'cutError'} = '';
	return 1;
}

# length in seconds
sub doFuseMount {
	my ($self, $vid, $room, $starttime, $length) = @_;
	
	return unless defined($starttime);
	if ($starttime =~ /^([0-9]{4}).([0-9]{2}).([0-9]{2}).([0-9]{2}).([0-9]{2}).([0-9]{2})/) {
		$starttime = "$1-$2-$3_$4-$5-$6";
	}

	$self->doFuseUnmount($vid) if $self->isVIDmounted($vid);
	my $files;
	if (defined($length)) {
		$files = int($length * $self->{fps} / $self->{defaultpieceframes}) + 1;
	} else {
		$files = $self->{defaultfiles};
		$length = $files * $self->{defaultpieceframes} / $self->{fps};
	}
	my $frames = $length * $self->{fps};
	my $prefix = $self->{'Processing.Path.CaptureFilePrefix'};
	$prefix = '' unless defined($prefix);
	$prefix .= $room;


	my $capdir = $self->getCapturePath($room);
	my $p = $self->getMountPath($vid);
	return 0 unless defined($p);
	print "creating mount path \"$p\"\n" if defined($self->{debug});
	my $log = join "\n", qx ( mkdir -p "$p" 2>&1 );
	my $fusecmd = " ".$self->{binpath}."/fuse-ts p=\"$prefix-\" c=\"$capdir\" st=\"$starttime\" numfiles=$files totalframes=$frames ";
	$fusecmd .= " fps=".$self->{fps} if (defined($self->{fps}) and $self->{fps} != 25);
	$fusecmd .= " -oallow_other,use_ino \"$p\" ";

	print "FUSE cmd: $fusecmd\n" if defined($self->{debug});
	$log .= join "\n", qx ( $fusecmd 2>&1 );
	return ($self->isVIDmounted($vid), $log, $fusecmd);
}

sub doFuseRepairMount {
	my ($self, $vid, $replacement, undef) = @_;

	print "doFuseRepairMount: $vid '$replacement'\n" if defined($self->{debug});
	return 0 unless defined($replacement);

	my $repairdir = $self->{'paths'}->getPath('Repair');
	die "ERROR: no Processing.Path.Repair specified!\n" unless defined $repairdir;

	my $replacementpath = "$repairdir/$replacement";
	return 0 unless -r $replacementpath;
	print "replacing FUSE with repaired file $replacementpath*\n" if defined($self->{debug});
	$self->doFuseUnmount($vid) if $self->isVIDmounted($vid);
	my $p = $self->getMountPath($vid);
	return 0 unless defined($p);
	my $log = qx ( mkdir -p \"$p\" );
	$log .= join "\n", qx ( ln -s "$replacementpath" \"$p/uncut.ts\" 2>&1 );
	return (1, $log, "ln -s \"$replacementpath\" \"$p/uncut.ts\" 2>&1");
}

sub getCutmarks {
	my ($self, $vid, undef) = @_;
	return undef unless defined($vid);
	my $p = $self->getMountPath($vid);
	print "getting mark IN of event $vid\n" if defined($self->{debug});
	my $i = qx ( cat \"$p/inframe\" );
	chomp($i);
	print "getting mark OUT of event $vid\n" if defined($self->{debug});
	my $o = qx ( cat \"$p/outframe\" );
	chomp($o);
	print "getting mark IN of event $vid\n" if defined($self->{debug});
	my $it = qx ( cat \"$p/intime\" );
	chomp($it);
	print "getting mark OUT of event $vid\n" if defined($self->{debug});
	my $ot = qx ( cat \"$p/outtime\" );
	chomp($ot);

	return ($i, $o, $it, $ot);
}

sub setCutmarks {
	my ($self, $in, $out, undef) = @_;
	my $vid = $self->{'Fahrplan.ID'};

	my $p = $self->getMountPath($vid);
	my $infile = "$p/inframe";
	my $outfile = "$p/outframe";

	if (defined($in)) {
		print "setting mark IN of event $vid to $in\n" if defined($self->{debug});
		open(INFILE, '>', $infile) and
			print INFILE $in and
			close INFILE;
	}
	if (defined($out)) {
		print "setting mark OUT of event $vid to $out\n" if defined($self->{debug});
		open(OUTFILE, '>', $outfile) and
			print OUTFILE $out and
			close OUTFILE;
	}
}
1;
