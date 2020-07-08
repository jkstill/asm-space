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
				and dg.name = 'DATA'
) ,
forecast as (
	select
		name,
		max(snap_timestamp) + interval '1' year forecast_year,
		-- y = mx+b
		regr_slope(space_used, snap_epoch)
		* (max(snap_epoch_future_year) )
		+ regr_intercept(space_used, snap_epoch) forecasted_space
	from (
		select name
		, snap_timestamp
		-- epoch dates used to work with linear regression functions, which require a number, not a date
		, (
			(extract(day from(snap_timestamp - to_timestamp('1970-01-01', 'YYYY-MM-DD'))) * 86400)
			+ to_number(to_char(sys_extract_utc(snap_timestamp), 'SSSSS'))
		) snap_epoch
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
		, trunc(forecasted_space) space_used
	from forecast f
),
date_conform as (
	select
		name
		, to_date(to_char(snap_timestamp,'yyyy-mm-dd'),'yyyy-mm-dd') s_timestamp
		, to_date(to_char(min(snap_timestamp) over (),'yyyy-mm-dd'),'yyyy-mm-dd') min_timestamp
		, to_date(to_char(max(snap_timestamp) over (), 'yyyy-mm-dd'),'yyyy-mm-dd') max_timestamp
		, space_used
	from raw_data d
	order by name, d.snap_timestamp
)
select
	name
	, d.s_timestamp
	, d.min_timestamp
	, d.max_timestamp
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
	) max_space
/

