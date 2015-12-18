#! /usr/bin/perl

##
##	BVTP4Setup.pl
##
##	This script is used to do a setup the perfoce on a Fedora OS based
##	

use Term::ReadKey;
use strict;
use lib '/usr/local/bin';
use File::Temp qw(tempfile tempdir);

require "COMMON.pm";
require "LOG.pm";

my @mnulist;

$| = 1;

&requireSuperUser();

my $options = &getOptions();

# checking the OS 
my $redhatVersion = `/bin/cat /etc/redhat-release`; chomp($redhatVersion);
if ( $redhatVersion !~ /Fedora release 15/ ) {
	&abort("This script is only meant to be run on a Fedora Core 15 ");
}

# getting user login name; 
my $user;
if ($$options{user}) {
	$user = $$options{user};
} else {
	print "Plese enter a username for your development user: ";
	$user = <STDIN>;
	chomp($user);
}

# getting user login password from '/etc/passwd';
if (!system("grep '^$user:' /etc/passwd")) {
	
	# If loging password is existst 
	unless ($$options{user}) {
		print "\nThe user $user already exists. Would you like to use this account? (y/n): ";
		my $answer = <STDIN>;
		chomp($answer);
		$answer =~ tr/A-Z/a-z/;
	
		if ($answer eq 'n' || $answer eq 'no') {
			&abort("Exiting...");
		}
	}
	
} else {
	my $pass = &getPassword();
	print "\nAdding user to system\n";
	&doCommand("useradd -d '/home/$user' -m $user");
	&doCommand("echo \"$pass\" | passwd --stdin $user");
	&doCommand("/usr/sbin/usermod -G users $user");
}

# creating softlink 
unless (-e "/home/$user/$user") {
	&doCommand("ln -s /home/$user /home/$user");
}

# adding to user to sudo user ;
unless (`grep '$user ALL=NOPASSWD:ALL' /etc/sudoers`) {
	print "Adding user to sudoers\n";
	&doCommand("echo '$user ALL=NOPASSWD:ALL' >> /etc/sudoers");
}

# adding to P4CONFIG to .bashrc file.
unless (`grep '.p4settings' /home/$user/.bashrc`) {
	&doCommand("echo 'export P4CONFIG=.p4settings' >> /home/$user/.bashrc");
}


my $p4 = '/usr/local/bin/p4';
my $p4user;
if ($$options{p4_user}) {
	$p4user = $$options{p4_user};
} else {
	$p4user = getInput('Please enter your p4 username', $user);
}
$ENV{P4USER} = $p4user;

my $hostname = `hostname -s`;
chomp($hostname);
my $p4server;
if (!(exists($ENV{P4PORT})) || ($ENV{P4PORT} eq '')) {
    $p4server='p4proxy.inmd.infoblox.com:1667';
    $ENV{P4PORT} = $p4server;
} else {
    $p4server = $ENV{P4PORT};
}

my $p4status=`/bin/su $user -c '$p4 -p $p4server login -s' 2>&1`;
if ($p4status =~ /invalid/) {
    print "--- Logging into p4 ---\n";
    &doCommand("/bin/su $user -c '$p4 login'");
}


my $devDir = "/home/$user/dev";

print "\nSetting permissions on /home/$user\n";
&doCommand("chmod 701 /home/$user");

unless ($$options{nondestructive}) {
	print "\nLooking for existing build tree in $devDir\n";

	if (-l $devDir) {
	    # Old dev is symlink, just remove the link
	    print "Old dev directory is a symlink, removing symlink\n";
	    unlink $devDir;
	} elsif (-d $devDir) {
	    # Old dev is real, move out of the way
	    my $renameDir = tempdir("${devDir}-oldXXXX");
	    print "Old dev directory being renamed to $renameDir\n";
	    rmdir $renameDir;
	    rename $devDir, $renameDir;
	} elsif (-f $devDir) {
	    my $renameFile = tempfile("${devDir}-oldXXXX");
	    print "Old dev file being renamed to $renameFile\n";
	    rmdir $renameFile;
	    rename $devDir, $renameFile;
	}


	my $dummy_client_name = 'dummyXXX';
	my $p4client= $dummy_client_name;
	my $p4status = $p4client;
	while ($p4status =~ /$p4client/) {
	    if ($p4client ne $dummy_client_name) {
		print "$p4client is already in use, must be unique";
	    }
	    $p4client = getInput('Please enter the p4 client name', "$p4user-$hostname");
	    $p4status=`/bin/su $user -c '$p4 workspaces' | awk '{print $2}' | grep -w $p4client 2>&1`;
	}

	my $perforcedir = "/home/$user/perforce";
	my $p4dir = "/$perforcedir/";
	if (-d $p4dir) {
	    &abort("Perforce directory $p4dir already exists, clean up and restart setup");
	}

	print "\nChecking out from perforce repository. This may take a few minutes\n";

	if (!-d $perforcedir) {
	    mkdir $perforcedir || &abort("Unable to create directory $perforcedir");
	    chown((getpwnam($user))[2,3], $perforcedir);
	}

	mkdir $p4dir || &abort("Unable to create directory $p4dir");
	chown((getpwnam($user))[2,3], $p4dir);

	# Create link to dev directory
	symlink $p4dir, $devDir || &abort("Unable to create symlink to $devDir");

	chdir $p4dir || &abort("Unable to cd to directory $p4dir");

	print "Checking out netmri repository in client '$p4client'\n";

	my $p4file = "/tmp/$p4client.tmpl";
	open (MYFILE, ">$p4file");
	print MYFILE <<EOF;
Client: $p4client
Owner: $p4user
Root: $p4dir
AltRoots: /home/$user/dev
View:
	//Netmri/qa/... //$p4client/qa/...
EOF
	close(MYFILE);

	my $p4settings = "$p4dir/.p4settings";
	open(MYFILE, ">$p4settings");
	print MYFILE <<EOF;
P4PORT=$p4server
P4CLIENT=$p4client
EOF
	close(MYFILE);
	chown((getpwnam($user))[2,3],$p4settings);

	$ENV{P4CLIENT} = $p4client;
	&doCommand("/bin/cat $p4file | /bin/su $user -c '$p4 client -i'");
	&doCommand("/bin/su $user -c '$p4 sync'");
}

print "\nPerforce setting completed successfully\n";

# get the option from command line;
sub getOptions {
	my %results;

	for (my $i=0;$i<=$#ARGV;$i++) {
		if ($ARGV[$i] eq '-u') {
			$results{user} = $ARGV[++$i];
		} elsif ($ARGV[$i] eq '-s') {
			$results{svn_user} = $ARGV[++$i];
		} elsif ($ARGV[$i] eq '-i') {
			$results{ip_addr} = $ARGV[++$i];
		} elsif ($ARGV[$i] eq '--nondestructive') {
			$results{nondestructive} = 1;
		}
	}

	return \%results;
}

# get the password from user  nad varify returns correct password
sub getPassword {
	print "\nPlease enter a password for your development user: ";
	ReadMode('noecho');
	my $pass = ReadLine(0);
	chomp($pass);

	print "\nPlease verify the password for your development user: ";
	ReadMode('noecho');
	my $verifypass = ReadLine(0);
	chomp($verifypass);

	if ($pass ne $verifypass) { 
		print "\nPasswords do not match!\n";
		$pass = &getPassword(); 
	}

	ReadMode('restore');
	return $pass;

}
