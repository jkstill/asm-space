


drop table diskgroups_space purge;


@@config

create table &&asmspc_owner..diskgroups_space (
	name                     varchar2(30),
	snap_timestamp timestamp,
	total_mb                 number,
	free_mb                  number,
	required_mirror_free_mb  number,
	usable_file_mb           number
)
/


		

