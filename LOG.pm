#! /usr/bin/perl
#
#	LOG.pm
#
$logIndent = "    ";

sub logOpen
{
	my ($logFile) = @_;
	if ($logFile !~ /^>/) {
		$logFile = ">$logFile";
	}
	open (LOG, "$logFile") || die "Unable to open $logFile";
}

###################################################################
#
#	Print the given message to the log file, prefixed
#	by the timestamp.  If the message contains newlines,
#	each line will be prefixed by the timestamp.
#
sub logMsg
{
    my  ( $msg ) = @_;

    my ( $mon,$day,$year,$hour,$min,$sec ) = (localtime())[4,3,5,2,1,0];
    $mon += 1; $year += 1900;
    my $timestamp = sprintf ("%04d-%02d-%02d %02d:%02d:%02d",
				$year, $mon, $day, $hour, $min, $sec);

    for my $line ( (split(/\n/,$msg)) ) {
        next if ( $line eq "" );
        print LOG "$timestamp $line\n";
    }
}

###################################################################
#
#	Log the given message and print it on STDOUT
#
sub logInfo
{
        my($cmd) = @_;
        logMsg($cmd);
        print STDOUT "$cmd\n";
}

###################################################################
#
#	Log the given message, print it on STDOUT and exit
#
sub logAbort
{
        my($msg) = @_;
        logInfo("\n*** $msg ***\n");
	exit -1;
}

###################################################################
#
#	Log the given command, execute it, log and print all
#	output lines and check the status.  If the status is
#	non-zero, abort.
#
sub logCmd
{
        my($cmd,$ignore) = @_;
	logMsg ($logIndent . $cmd);
	if ($cmd !~ /2>&1/) {
		$cmd = "$cmd 2>&1";
	}
	open (CMD, "$cmd |") || logAbort ("Unable to Execute Command");
	my $cmdFailed = 0;
	while (<CMD>) {
		$line = $_;
		chop($line);
		$cmdFailed = 1 if ( $line =~ /rake aborted/ );
		logInfo($logIndent . $line);
	}
	close (CMD);
	my $status = $?;
	if ($status != 0 || $cmdFailed) {
		if ( !$ignore ) {
			logAbort ("Command Failed, status = $status");
			exit -1;
		}
	}
}

1;

#
#	End of Script
#
