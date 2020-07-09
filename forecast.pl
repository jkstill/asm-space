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

Getopt::Long::GetOptions(
	\%optctl,
	"database=s" => \$db,
	"username=s" => \$username,
	"password=s" => \$password,
	"sysdba!",
	"sysoper!",
	"z","h","help");


$connectionMode = 0;
if ( $optctl{sysoper} ) { $connectionMode = 4 }
if ( $optctl{sysdba} ) { $connectionMode = 2 }

if ( ! defined($db) ) {
	usage(1);
}

if ( ! defined($username) ) {
	usage(2);
}

#print "USERNAME: $username\n";
#print "DATABASE: $db\n";
#print "PASSWORD: $password\n";
#exit;

my $dbh = DBI->connect(
	'dbi:Oracle:' . $db,
	$username, $password,
	{
		RaiseError => 1,
		AutoCommit => 0,
		ora_session_mode => $connectionMode
	}
	);

die "Connect to  $db failed \n" unless $dbh;

# apparently not a database handle attribute
# but IS a prepare handle attribute
#$dbh->{ora_check_sql} = 0;
$dbh->{RowCacheSize} = 100;

my $sql=q{
-- space-consumed.sql
-- interested in reporting on those
-- where space_consumed > 0
with min_space as (
	select
		dg.name
		, dg.usable_file_mb usable_mb
		, s.snap_timestamp snap_time
	from diskgroups dg
	join snapspace s on s.snap_id = dg.snap_id
	join (
		select name, min(snap_id) snap_id
		from diskgroups
		group by name
	) ms on ms.name = dg.name and ms.snap_id = dg.snap_id
),
max_space as (
	select
		dg.name
		, dg.usable_file_mb usable_mb
		, s.snap_timestamp snap_time
	from diskgroups dg
	join snapspace s on s.snap_id = dg.snap_id
	join (
		select name, max(snap_id) snap_id
		from diskgroups
		group by name
	) ms on ms.name = dg.name and ms.snap_id = dg.snap_id
)
select
	min.name
	, min.usable_mb past_usable_mb
	, max.usable_mb curr_usable_mb
	-- space consumed since the first snapshot
	, ( min.usable_mb - max.usable_mb ) space_consumed
from min_space min
	join max_space max on  max.name = min.name
where ( min.usable_mb - max.usable_mb ) > 0
order by name};

my $sth = $dbh->prepare($sql,{ora_check_sql => 0});

$sth->execute;

$sql = getForecastSql();
my $sthForecast = $dbh->prepare($sql,{ora_check_sql => 0});

while( my $ary = $sth->fetchrow_arrayref ) {
	#print "\t\t$ary->[0]\n";

	$sthForecast->execute($ary->[0]);

	my $fh = IO::File->new;

	my $csvFile = "$ary->[0].csv";

	$fh->open($csvFile,'w') or die "could not create $csvFile - $!\n";


	print	 $fh join(',',@{$sthForecast->{NAME}}),"\n";

	while( my $forecast = $sthForecast->fetchrow_arrayref ) {

		print $fh join(',',@{$forecast}), "\n";
	}
}

$dbh->disconnect;

sub usage {
	my $exitVal = shift;
	$exitVal = 0 unless defined $exitVal;
	use File::Basename;
	my $basename = basename($0);
	print qq/

usage: $basename

  -database		  target instance
  -username		  target instance account name
  -password		  target instance account password
  -sysdba		  logon as sysdba
  -sysoper		  logon as sysoper

  example:

  $basename -database dv07 -username scott -password tiger -sysdba
/;
	exit $exitVal;
};

sub getForecastSql {
return q{
with diskgroups_space as (
			select
				name
				, snap_timestamp
				, total_mb
				, free_mb
				, required_mirror_free_mb
				, usable_file_mb
			from diskgroups dg
			join snapspace s on s.snap_id = dg.snap_id
				and dg.name = ?
) ,
forecast as (
	select
		name,
		-- 3 month
		max(snap_timestamp) + interval '3' month forecast_3_month,
		regr_slope(space_used, snap_epoch)
		* (max(snap_epoch_future_3_month) )
		+ regr_intercept(space_used, snap_epoch) forecasted_space_3_month,
		-- 6 month
		max(snap_timestamp) + interval '6' month forecast_6_month,
		regr_slope(space_used, snap_epoch)
		* (max(snap_epoch_future_6_month) )
		+ regr_intercept(space_used, snap_epoch) forecasted_space_6_month,
		-- year
		max(snap_timestamp) + interval '1' year forecast_year,
		-- y = mx+b
		regr_slope(space_used, snap_epoch)
		* (max(snap_epoch_future_year) )
		+ regr_intercept(space_used, snap_epoch) forecasted_space_year
	from (
		select name
		, snap_timestamp
		-- epoch dates used to work with linear regression functions, which require a number, not a date
		, (
			(extract(day from(snap_timestamp - to_timestamp('1970-01-01', 'YYYY-MM-DD'))) * 86400)
			+ to_number(to_char(sys_extract_utc(snap_timestamp), 'SSSSS'))
		) snap_epoch
		, (
			(extract(day from((snap_timestamp + interval '3' month) - to_timestamp('1970-01-01', 'YYYY-MM-DD'))) * 86400)
			+ to_number(to_char(sys_extract_utc(snap_timestamp + interval '3' month), 'SSSSS'))
		) snap_epoch_future_3_month
		, (
			(extract(day from((snap_timestamp + interval '6' month) - to_timestamp('1970-01-01', 'YYYY-MM-DD'))) * 86400)
			+ to_number(to_char(sys_extract_utc(snap_timestamp + interval '6' month), 'SSSSS'))
		) snap_epoch_future_6_month
		, (
			(extract(day from((snap_timestamp + interval '1' year) - to_timestamp('1970-01-01', 'YYYY-MM-DD'))) * 86400)
			+ to_number(to_char(sys_extract_utc(snap_timestamp + interval '1' year), 'SSSSS'))
		) snap_epoch_future_year
		, (total_mb - usable_file_mb) space_used
		from diskgroups_space
		order by name, snap_timestamp
	)
	group by name
),
raw_data as (
	select
		name
		, snap_timestamp
		, (total_mb - usable_file_mb) space_used
	from diskgroups_space
	union all
	select
		name
		, forecast_year snap_timestamp
		, trunc(forecasted_space_year) space_used
	from forecast f
	union all
	select
		name
		, forecast_3_month snap_timestamp
		, trunc(forecasted_space_3_month) space_used
	from forecast f
	union all
	select
		name
		, forecast_6_month snap_timestamp
		, trunc(forecasted_space_6_month) space_used
	from forecast f
),
date_conform as (
	select
		name
		, snap_timestamp s_timestamp
		, min(snap_timestamp) over () min_timestamp
		, max(snap_timestamp) over () max_timestamp
		, space_used
	from raw_data d
	order by name, d.snap_timestamp
)
select
	name
	, to_char(d.s_timestamp,'yyyy-mm-dd') s_timestamp
	, to_char(d.min_timestamp,'yyyy-mm-dd') min_timestamp
	, to_char(d.max_timestamp,'yyyy-mm-dd') max_timestamp
	--, d.max_timestamp - d.min_timestamp days_to_forecast
	--, max_space.usable_file_mb space_avail
	, max_space.total_mb
	, max_space.total_mb - d.space_used space_avail
	, d.space_used
	-- make a prediction
	-- space per day avg
	-- usable space / ( space used currently - space used at start ) / ( days measured )
	--, (max_space.space_used - min_space.space_used) /  ( max_timestamp - min_timestamp ) avg_per_day
	, to_char(
		max_space.usable_file_mb /
		(
			(max_space.space_used - min_space.space_used )
			/ ( max_space.snap_timestamp - min_space.snap_timestamp	)
		) + max_space.snap_timestamp
		, 'yyyy-mm-dd'
	) filled_date
from date_conform d,
	(
		select to_date(to_char(snap_timestamp,'yyyy-mm-dd'),'yyyy-mm-dd') snap_timestamp, total_mb, usable_file_mb, total_mb - usable_file_mb space_used
		from diskgroups_space
			where snap_timestamp = (
				select min(snap_timestamp)
				from diskgroups_space
		)
	) min_space
	, (
		select to_date(to_char(snap_timestamp,'yyyy-mm-dd'),'yyyy-mm-dd') snap_timestamp, total_mb, usable_file_mb,	 total_mb - usable_file_mb space_used
		from diskgroups_space
			where snap_timestamp = (
				select max(snap_timestamp)
				from diskgroups_space
		)
	) max_space};

}
