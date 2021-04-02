
-- forecast.sql
-- forecast when Diskgroup space will be exhausted, based on current usage
-- using linear regression, as space usage is typically linear over time


set pause off echo off verify off
set linesize 200 trimspool on
set pagesize 100

clear break
break on name skip 1

host mkdir -p reports 

spool reports/forecast.txt

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
				--and dg.name = 'DATA_PRDSOA'
) ,
forecast as (
	select
		name,
		-- 3 month
		max(add_months(snap_timestamp,3)) forecast_3_month,
		regr_slope(space_used, snap_epoch)
		* (max(snap_epoch_future_3_month) )
		+ regr_intercept(space_used, snap_epoch) forecasted_space_3_month,
		-- 6 month
		max(add_months(snap_timestamp,6)) forecast_6_month,
		regr_slope(space_used, snap_epoch)
		* (max(snap_epoch_future_6_month) )
		+ regr_intercept(space_used, snap_epoch) forecasted_space_6_month,
		-- year
		max(add_months(snap_timestamp,12)) forecast_year,
		-- y = mx+b
		regr_slope(space_used, snap_epoch)
		* (max(snap_epoch_future_year) )
		+ regr_intercept(space_used, snap_epoch) forecasted_space_year
	from (
		select name
		, snap_timestamp
		-- epoch - using UTC as exact time not necessary
		-- (cast (snap_timestamp at time zone 'UTC' as date) - date '1970-01-01') * 86400
		-- epoch dates used to work with linear regression functions, which require a number, not a date
		, (cast(snap_timestamp at time zone 'UTC' as date) - date '1970-01-01') * 86400 snap_epoch
		, (add_months(cast(snap_timestamp at time zone 'UTC' as date),3) - date '1970-01-01') * 86400 snap_epoch_future_3_month
		, (add_months(cast(snap_timestamp at time zone 'UTC' as date),6) - date '1970-01-01') * 86400 snap_epoch_future_6_month
		, (add_months(cast(snap_timestamp at time zone 'UTC' as date),12) - date '1970-01-01') * 86400 snap_epoch_future_year
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
		d.name
		, d.snap_timestamp s_timestamp
		, min(d.snap_timestamp) over () min_timestamp
		, max(d.snap_timestamp) over () max_timestamp
		, d.space_used
		, max_space.total_mb max_total_mb
		,
		max_space.usable_file_mb /
		(
			(
				(max_space.space_used - min_space.space_used )
				/ ( max_space.snap_timestamp - min_space.snap_timestamp	)
			) + 1
		)    + max_space.snap_timestamp date_add
	from raw_data d
	, (
		select name, to_date(to_char(snap_timestamp,'yyyy-mm-dd'),'yyyy-mm-dd') snap_timestamp, total_mb, usable_file_mb, total_mb - usable_file_mb space_used
		from diskgroups_space
			where snap_timestamp = (
				select min(snap_timestamp)
				from diskgroups_space
		)
	) min_space
	, (
		select name, to_date(to_char(snap_timestamp,'yyyy-mm-dd'),'yyyy-mm-dd') snap_timestamp, total_mb, usable_file_mb,	 total_mb - usable_file_mb space_used
		from diskgroups_space
			where snap_timestamp = (
				select max(snap_timestamp)
				from diskgroups_space
		)
	) max_space
where min_space.name = d.name
and max_space.name = d.name
	order by name, d.snap_timestamp
)
select distinct
	d.name
	, to_char(d.s_timestamp,'yyyy-mm-dd') s_timestamp
	, to_char(d.min_timestamp,'yyyy-mm-dd') min_timestamp
	, to_char(d.max_timestamp,'yyyy-mm-dd') max_timestamp
	--, d.max_timestamp - d.min_timestamp days_to_forecast
	--, max_space.usable_file_mb space_avail
	, d.max_total_mb
	, d.max_total_mb - d.space_used space_avail
	, d.space_used
	-- make a prediction
	-- space per day avg
	-- usable space / ( space used currently - space used at start ) / ( days measured )
	--, (max_space.space_used - min_space.space_used) /  ( max_timestamp - min_timestamp ) avg_per_day
	, to_char( d.date_add , 'yyyy-mm-dd') filled_date
from date_conform d
order by name, s_timestamp
/

spool off



