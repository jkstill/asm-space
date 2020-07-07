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
/
