#!/usr/bin/env perl

# template for DBI programs

use warnings;
use FileHandle;
use DBI;
use strict;
use IO::File;

use Getopt::Long;

my %optctl = ();

my($db, $username, $password, $connectionMode);

$connectionMode = 0;

$username='jkstill';
$password='grok';

#print "USERNAME: $username\n";
#print "DATABASE: $db\n";
#print "PASSWORD: $password\n";
#exit;


my $dbh = DBI->connect(
	'dbi:Oracle:ora192rac-scan/pdb1.jks.com',
	$username, $password, 
	{ 
		RaiseError => 1, 
		AutoCommit => 0
	} 
	);

die "Connect to  $db failed \n" unless $dbh;

# apparently not a database handle attribute
# but IS a prepare handle attribute
#$dbh->{ora_check_sql} = 0;
$dbh->{RowCacheSize} = 100;

my $sql=q{insert into diskgroups_space (name, snap_timestamp, total_mb, free_mb, required_mirror_free_mb, usable_file_mb) values(?,to_date(?,'yyyy-mm-dd hh24:mi:ss'),?,?,?,?)};

my $sth = $dbh->prepare($sql,{ora_check_sql => 0});

my $fh = IO::File->new();
my $dataFile = 'asm-dg-space-rpt.csv';
$fh->open($dataFile,'r') or die "Cannot open $dataFile - $!\n";

my $realData=0;
while (<$fh>) {

	if ( (! $realData ) && /^DATA/ ) {
		$realData = 1;
	}
	next unless $realData;

	# first real line starts with 'DATA'
	
	chomp;
	my @data=split(/,/);
	$sth->execute(@data);

}

$dbh->commit;

$dbh->disconnect;

sub usage {
	my $exitVal = shift;
	$exitVal = 0 unless defined $exitVal;
	use File::Basename;
	my $basename = basename($0);
	print qq/

usage: $basename

  -database      target instance
  -username      target instance account name
  -password      target instance account password
  -sysdba        logon as sysdba
  -sysoper       logon as sysoper

  example:

  $basename -database dv07 -username scott -password tiger -sysdba 
/;
   exit $exitVal;
};



