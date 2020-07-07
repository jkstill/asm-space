select name
	|| ','  || snap_timestamp
 	|| ',' || (total_mb - usable_file_mb) 
from diskgroups_space
where name = 'DATA'
order by snap_timestamp
/
