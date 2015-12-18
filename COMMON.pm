
require "COMMON-CFG.pm";

#
#	Gets the next command line argument or prompts the user using
#	the given prompt and initial value
#
sub getArg
{
	my($prompt, $val) = @_;
	my($cnt);
	$cnt = @ARGV;
	if ($cnt > 0) {
		$val = shift(@ARGV);
	} else {
		$val = &getInput ($prompt, $val);
	}
	$val;
}

#
#	Prompts the user for an input value, using the given prompt
#	and default value
#
sub getInput
{
	my($prompt, $val) = @_;
	print "\n$prompt [$val]: ";
	my($resp);
	$resp = <STDIN>;
	chop($resp);
	if ($resp ne "") {
		$val = $resp;
	}
	$val;
}

#
#	Executes the given system command and aborts if the command fails
#
sub doCommand
{
	my($cmd) = @_;
	if ($debugCmd) {
		print "    $cmd\n";
	}
	system ($cmd);
	if ($?) {
		&abort ("Script Aborted");
	}
}

#
#	Prints the given message and exits the script
#
sub abort
{
	my($msg) = @_;
	print "\n*** $msg ***\n\n";
	exit -1;
}

#
#	Checks to make sure that the root is running this script
#
sub requireSuperUser
{
	if ($> != 0) {
		&abort ("This Script Can Only Be Executed By The Super-User");
	}
}

#
#	Creates the given directory if it doesn't already exist
#
sub createDir
{
	my($dir) = @_;

	if (! -d $dir) {
		print "+++ Creating $dir ...\n";
		&doCommand ("/bin/mkdir -p $dir");
	}
}

#
#	Creates the given directory if it doesn't already exist
#	and sets the permissions
#
sub createDirMod
{
	my($dir,$mod) = @_;

	if (! -d $dir) {
		print "+++ Creating $dir ...\n";
		&doCommand ("/bin/mkdir -p $dir; /bin/chmod $mod $dir");
	}
}

#
#	Gets the application directory
#
sub getAppDir
{
	my ($AppDir) = "/var/local/netmri";
	my ($cfgFile) = "$skipjack/conf/server.cfg";

	if (-f $cfgFile) {
		&loadCfgFile ($cfgFile);
	}

	$AppDir = &getArg ("Enter the NetMRI application directory",
				$AppDir);

# strip any trailing slash

	$AppDir =~ s/\/$//;

	return $AppDir;
}

#
#       Returns the Perl version as a string
#
sub getPerlVersion
{
        return  (ord(substr($^V,0,1)) + '0')
                . "."
                . (ord(substr($^V,1,1)) + '0')
                . "."
                . (ord(substr($^V,2,1)) + '0');
}

sub getServerCfg
{
	$serverCfg = "$skipjack/conf/server.cfg";

	&loadCfgFile ($serverCfg);
}


########################################################################
#
#	Returns a tuple containing the major, minor and revision
#	values for the given Version string
#
sub getVersionNumbers
{
	my ($version) = @_;
	my ($major, $minor, $rev) = split ( /[.a-zA-Z]+/, $version );

	if ($version =~ /b/) { $rev -= 50; }
	if ($rev eq "") { $rev = 0; }

	($major, $minor, $rev);
}

########################################################################
#
#	Returns the latest version from the list of given package
#	filenames (.tar.gz or .gpg)
#
sub getLatestVersion
{
	my @fileList = @_;

	my $version = "0.0";
	foreach $file (@fileList) {
		$file =~ /[^-]+-(.+)\.(tar\.gz|gpg)/;
		$curVersion = $1;

		($cMajor, $cMinor, $cRev) = getVersionNumbers ($curVersion);
		($vMajor, $vMinor, $vRev) = getVersionNumbers ($version);

		if ($cMajor > $vMajor
		|| ($cMajor == $vMajor && $cMinor > $vMinor)
		|| ($cMajor == $vMajor && $cMinor == $vMinor && $cRev>$vRev)) {
			$version = $curVersion;
		}
	}

	$version;
}

1;
