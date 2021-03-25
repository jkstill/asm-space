

@clear_for_spool

host mkdir csv

spool csv/diskgroup-data.csv

prompt diskgroup,timestamp,redundancy,total_mb,space_used,usable_file_mb

with diskgroups_space as (
			select
				name
				, to_char(snap_timestamp,'yyyy-mm-dd hh24:mi:ss') snap_timestamp
				, total_mb
				, free_mb
				, required_mirror_free_mb
				, usable_file_mb
				, type redundancy
			from diskgroups dg
			join snapspace s on s.snap_id = dg.snap_id
) 
select name
	|| ',' || snap_timestamp
 	|| ',' || redundancy
 	|| ',' || total_mb
 	|| ',' || (total_mb - usable_file_mb) 
 	|| ',' || usable_file_mb
from diskgroups_space
order by name, snap_timestamp
/


spool off

@clears

