#!/usr/bin/env perl
## File: updater.pl
## Version: 1.6
## Date 2018-01-10
## License: GNU GPL v3 or greater
## Copyright (C) 2017-18 Harald Hope

use strict;
use warnings;
use 5.008;
use Data::Dumper qw(Dumper); # print_r

### START DEFAULT CODE ##

my $self_name='pinxi';
my $self_version='2.9.00';
my $self_date='2017-12-11';
my $self_patch='019-p';

sub error_handler {
	my ($err, $message, $alt1) = @_;
	print "$err: $message err: $alt1\n";
	exit;
}

my $start = '';
my $end = '';

### END DEFAULT CODE ##

my %dl = ( 'dl' => 'test' );

sub download_file {}

# arg 1: type to return
sub get_defaults {
	my ($type) = @_;
	my %defaults = (
	'ftp-upload' => 'ftp.techpatterns.com/incoming',
	# 'inxi-branch-1' => 'https://github.com/smxi/inxi/raw/one/',
	# 'inxi-branch-2' => 'https://github.com/smxi/inxi/raw/two/',
	'inxi-main' => 'https://github.com/smxi/inxi/raw/master/',
	'inxi-pinxi' => 'https://github.com/smxi/inxi/raw/inxi-perl/',
	'inxi-man' => "https://github.com/smxi/inxi/raw/master/$self_name.1.gz",
	);
	if ( exists $defaults{$type}){
		return $defaults{$type};
	}
	else {
		error_handler('bad-arg-int', $type);
	}
}

### START CODE REQUIRED BY THIS MODULE ##

### START MODULE CODE ##

# args: 1 - download url, not including file name; 2 - string to print out
# 3 - update type option
# note that 1 must end in / to properly construct the url path
sub update_me {
	eval $start if $b_log;
	my ( $self_download, $download_id ) = @_;
	my $downloader_error=1;
	my $file_contents='';
	my $output = '';
	my $b_man = 0;
	$self_path =~ s/\/$//; # dirname sometimes ends with /, sometimes not
	my $full_self_path = "$self_path/$self_name";
	
	if ( $b_irc ){
		error_handler('not-in-irc', "-U/--update" )
	}
	if ( ! -w $full_self_path ){
		error_handler('not-writable', "$self_name", '');
	}
	$output = "${output}Starting $self_name self updater.\n";
	$output = "${output}Using $dl{'dl'} as downloader.\n";
	$output = "${output}Currently running $self_name version number: $self_version\n";
	$output = "${output}Current version patch number: $self_patch\n";
	$output = "${output}Current version release date: $self_date\n";
	$output = "${output}Updating $self_name in $self_path using $download_id as download source...\n";
	print $output;
	$output = '';
	$self_download = "$self_download/$self_name";
	$file_contents=download_file('stdout', $self_download);
	
	# then do the actual download
	if (  $file_contents ){
		# make sure the whole file got downloaded and is in the variable
		if ( $file_contents =~ /###\*\*EOF\*\*###/ ){
			open(my $fh, '>', $full_self_path);
			print $fh $file_contents or error_handler('write', "$full_self_path", "$!" );
			close $fh;
			qx( chmod +x '$self_path/$self_name' );
			set_version_data();
			$output = "${output}Successfully updated to $download_id version: $self_version\n";
			$output = "${output}New $download_id version patch number: $self_patch\n";
			$output = "${output}New $download_id version release date: $self_date\n";
			$output = "${output}To run the new version, just start $self_name again.\n";
			$output = "${output}$line3\n";
			$output = "${output}Starting download of man page file now.\n";
			print $output;
			$output = '';
			if ($b_man && $download_id eq 'main branch' ){
				update_man();
			}
			else {
				print "Skipping man download because branch version is being used.\n";
			}
			exit 1;
		}
		else {
			error_handler('file-corrupt', "$self_name");
		}
	}
	# now run the error handlers on any downloader failure
	else {
		error_handler('download-error', $self_download, $download_id);
	}
	eval $end if $b_log;
}

sub update_man {
	my $man_file_url=get_defaults('inxi-man'); 
	my $man_file_location=set_man_location();
	my $man_file_path="$man_file_location/$self_name.1.gz" ;
	my $output = '';
	
	my $downloader_man_error=1;
	if ( ! -d $man_file_location ){
		print "The required man directory was not detected on your system.\n";
		print "Unable to continue: $man_file_location\n";
		return 0;
	}
	if ( -w $man_file_location ){
		print "Cannot write to $man_file_location! Are you root?\n";
		print "Unable to continue: $man_file_location\n";
		return 0;
	}
	if ( -f "/usr/share/man/man8/inxi.8.gz" ){
		print "Updating man page location to man1.\n";
		rename "/usr/share/man/man8/inxi.8.gz", "$man_file_location/inxi.1.gz";
		if ( check_program('mandb') ){
			system( 'mandb' );
		}
	}
	if ( $dl{'dl'} =~ /tiny|wget/){
		print "Checking Man page download URL...\n";
		download_file('spider', $man_file_url);
		$downloader_man_error = $?;
	}
	if ( $downloader_man_error == 1 ){
		if ( $dl{'dl'} =~ /tiny|wget/){
			print "Man file download URL verified: $man_file_url\n";
		}
		print "Downloading Man page file now.\n";
		download_file('file', $man_file_url,  $man_file_path );
		$downloader_man_error = $?;
		if ( $downloader_man_error == 0 ){
			print "Oh no! Something went wrong downloading the Man gz file at: $man_file_url\n";
			print "Check the error messages for what happened. Error: $downloader_man_error\n";
		}
		else {
			print "Download/install of man page successful. Check to make sure it works: man inxi\n";
		}
	}
	else {
		print "Man file download URL failed, unable to continue: $man_file_url\n";
	}
}

sub set_man_location {
	my $location='';
	my $default_location='/usr/share/man/man1';
	my $man_paths=qx(man --path 2>/dev/null);
	my $man_local='/usr/local/share/man';
	my $b_use_local=0;
	if ( $man_paths && $man_paths =~ /$man_local/ ){
		$b_use_local=1;
	}
	# for distro installs
	if ( -f "$default_location/inxi.1.gz" ){
		$location=$default_location;
	}
	else {
		if ( $b_use_local ){
			if ( ! -d "$man_local/man1" ){
				mkdir "$man_local/man1";
			}
			$location="$man_local/man1";
		}
	}
	if ( ! $location ){
		$location=$default_location;
	}
	return $location;
}

# update for updater output version info
# note, this is only now used for self updater function so it can get
# the values from the UPDATED file, NOT the running program!
sub set_version_data {
	open (my $fh, '<', "$self_path/$self_name");
	while( my $row = <$fh>){
		chomp $row;
		$row =~ s/'//g;
		if ($row =~ /^my \$self_name/ ){
			$self_name = (split /=/, $row)[1];
		}
		elsif ($row =~ /^my \$self_version/ ){
			$self_version = (split /=/, $row)[1];
		}
		elsif ($row =~ /^my \$self_date/ ){
			$self_date = (split /=/, $row)[1];
		}
		elsif ($row =~ /^my \$self_patch/ ){
			$self_patch = (split /=/, $row)[1];
		}
		elsif ($row =~ /^## END INXI INFO/){
			last;
		}
	}
	close $fh;
}


### END MODULE CODE ##

### START TEST CODE ##