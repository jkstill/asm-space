

drop table asmfiles purge;
drop table diskgroups purge;
drop table snapspace purge;


@@config

create table &&asmspc_owner..DISKGROUPS (
	group_number number,
	name                     varchar2(30),
	sector_size              number,
	snap_id                  number,
	block_size               number,
	allocation_unit_size     number,
	type                     varchar2(6),
	total_mb                 number,
	free_mb                  number,
	required_mirror_free_mb  number,
	usable_file_mb           number
)
/

create table &&asmspc_owner..ASMFILES ( 
	group_number number,
	file_number     number,
	incarnation     number,
	snap_id         number,
	db_name         varchar2(15),
	full_path       varchar2(200),
	block_size      number(5),
	blocks          number(12),
	bytes           number(18),
	space_allocated number(18),
	file_type       varchar2(20)
)
/


create table &&asmspc_owner..SNAPSPACE( 
	snap_id number,
	snap_timestamp timestamp
)
/

		

