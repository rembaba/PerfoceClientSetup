
my $encrypted = 0;
if (-e "/p") {
	#use Crypt::CBC;
	use MIME::Base64;
	$encrypted = 1;

        ### do a check sum on the encryption perl modules
        ### exit out if they have been tampered with
        doCheck("/usr/lib/perl5/site_perl/5.8.0/Crypt/CBC.pm", 11672);
        doCheck("/usr/lib/perl5/site_perl/5.8.0/i386-linux-thread-multi/Crypt/OpenSSL/AES.pm", 27575);
}

sub abortt
{
        my($msg) = @_;
        print "\n*** $msg ***\n\n";
        exit -1;
}

sub loadCfgFile
{
        my ($cfgFile) = @_;

	local $/;
        open (CFG, "<$cfgFile") || &abortt("Unable To Open $cfgFile");
	$cfgContent = <CFG>;
	close (CFG);

	if ($encrypted) { $cfgContent = decryptCfg( $cfgContent ); }
	@cfgList = split(/\n/, $cfgContent);

	foreach $cfgLine (@cfgList) {
		eval($cfgLine."\n");
	}

	return $cfgContent;
}

sub writeCfgFile
{
	my ($cfgFile, $cfgContent) = @_;

	if ($encrypted) { $cfgContent = encryptCfg( $cfgContent ); }
	
	open (CFG, ">$cfgFile") || &abortt("Unable to Open $cfgFile");
	flock CFG, LOCK_EX;
	print CFG $cfgContent;
	flock CFG, LOCK_UN;
	close ( CFG );
}
	
sub writeToCfg
{
	my ($cfgFile, $attrName, $attrValue) = @_;
	
	local $/;
	open (CFG, "$cfgFile") || &abortt("Unable To Open $cfgFile");
	$cfgContent = <CFG>;
	close ( CFG );
	

	if ($encrypted) { $cfgContent = decryptCfg( $cfgContent ); }
	$cfgContent .= "\$".$attrName." = \"$attrValue\";\n";
	if ($encrypted) { $cfgContent = encryptCfg( $cfgContent ); }

	open (CFG, ">$cfgFile") || &abortt("Unable To Open $cfgFile");
	flock CFG, LOCK_EX;
	print CFG $cfgContent;
	flock CFG, LOCK_UN;
	close ( CFG );
}

sub writeHashToCfg
{
        my ($cfgFile, %cfgHash) = @_;

	$cfgContent = "";

	foreach $key (sort keys %cfgHash) {
		$val = $cfgHash{$key};
		$cfgContent .= "$key = ".perlString($val).";\n";
	}

        if ($encrypted) { $cfgContent = encryptCfg( $cfgContent ); }

        open (CFG, ">>$cfgFile") || &abortt("Unable To Open $cfgFile");
	flock CFG, LOCK_EX;
        print CFG $cfgContent;
	flock CFG, LOCK_UN;
        close ( CFG );
}


sub writeLineToCfg
{
	my ($cfgFile, $cfgLine) = @_;

        local $/;
        open (CFG, "$cfgFile") || &abortt("Unable To Open $cfgFile");
        $cfgContent = <CFG>;
        close ( CFG );

        if ($encrypted) { $cfgContent = decryptCfg( $cfgContent ); }
	$cfgContent .= $cfgLine;
        if ($encrypted) { $cfgContent = encryptCfg( $cfgContent ); }

        open (CFG, ">$cfgFile") || &abortt("Unable To Open $cfgFile");
	flock CFG, LOCK_EX;
        print CFG $cfgContent;
	flock CFG, LOCK_UN;
        close ( CFG );
}

sub decryptCfg
{
	my ($cfgContent) = @_;

	$decodedCfgContent = decode_base64( $cfgContent );

	$key = "4j\@Kz&l!Cq^7U)pV";
	my $cipher = Crypt::CBC->new(
			-key	=> $key,
			-cipher => "Crypt::OpenSSL::AES"
	);
	
	$decryptCfgContent = $cipher->decrypt($decodedCfgContent);

	return $decryptCfgContent;
}

sub encryptCfg
{
	my ($cfgContent) = @_;

	my $key = "4j\@Kz&l!Cq^7U)pV";
	my $cipher = Crypt::CBC->new(
                        -key    => $key,
                        -cipher => "Crypt::OpenSSL::AES"
        );

	$encryptCfgContent = $cipher->encrypt($cfgContent);

	$encodedCfgContent = encode_base64( $encryptCfgContent );	
	return $encodedCfgContent;
}

sub encryptCfgFile
{
	
	my ($cfgFile) = @_;

        local $/;
        open (CFG, "$cfgFile") || &abortt("Unable To Open $cfgFile");
        $cfgContent = <CFG>;
        close ( CFG );

	$cfgContent = encryptCfg( $cfgContent ); 

        open (CFG, ">$cfgFile") || &abortt("Unable To Open $cfgFile");
	flock CFG, LOCK_EX;
        print CFG $cfgContent;
	flock CFG, LOCK_UN;
        close ( CFG );
}


sub decryptCfgFile
{

        my ($cfgFile) = @_;

        local $/;
        open (CFG, "$cfgFile") || &abortt("Unable To Open $cfgFile");
        $cfgContent = <CFG>;
        close ( CFG );

        $cfgContent = decryptCfg( $cfgContent );

        open (CFG, ">$cfgFile") || &abortt("Unable To Open $cfgFile");
	flock CFG, LOCK_EX;
        print CFG $cfgContent;
	flock CFG, LOCK_UN;
        close ( CFG );
}

sub perlString
{
        my $val = shift(@_);

        $val =~ s/([^\\])\"/\1\\"/g;   # comment to close " to unconfuse emacs
        $val =~ s/\n/\\n/g;
        $val =~ s/@/\\@/g;
        $val =~ s/\$/\\\$/g;

        return '"' . $val . '"';
}

sub getCheckSum {
        my ($file) = @_;

        if(! -f "$file") {
                return(0);
        }

        my $sumStr = "/usr/bin/sum '$file'";
        my $sum = `$sumStr`;
        my $cs = 0;

        if($sum =~ /(\d+)\s+\d+/) {
                $cs = $1;
        }

        return($cs);
}

sub doCheck {
        my ($file, $origCS) = @_;

        my $currCS = getCheckSum($file);

        if($origCS ne $currCS) {
                print "*** NetMRI Has Been Tampered With '$file' ***\n";
                exit(1);
        }
}

1;

