
@@config

clear col

col file_type format a20
col full_path format a65
col bytes format 99999999999999
col dg_name format a15

set linesize 200 trimspool on
set pagesize 60

select 
	substr(f.full_path,2,instr(full_path,'/')-2) dg_name
	, f.group_number
	, f.file_number
	, f.full_path
	, f.block_size
	, f.bytes
	, f.space_allocated
	, f.system_created
	, f.file_type
	, f.creation_date
from (
select 
	 group_number
	, file_number
	, concat('+'||gname, sys_connect_by_path(aname, '/')) full_path
	, block_size
	, blocks
	, bytes
	, space_allocated
	, system_created
	, file_type
	, alias_directory
	, creation_date
from
(
	select
		b.name gname
		, a.parent_index pindex
		, a.name aname
		, a.reference_index rindex
		, a.system_created
		, a.alias_directory
		, c.group_number
		, c.file_number
		, c.block_size
		, c.blocks
		, c.bytes
		, c.space space_allocated
		, c.type file_type
		, to_char(c.creation_date,'&&date_format') creation_date
	from v$asm_alias a, v$asm_diskgroup b, v$asm_file c
	where a.group_number = b.group_number
	and a.group_number = c.group_number(+)
	and a.file_number = c.file_number(+)
	and a.file_incarnation = c.incarnation(+)
)
start with (mod(pindex, power(2, 24))) = 0
connect by prior rindex = pindex
) f
--join v$asm_diskgroup g on g.group_number = f.group_number
where alias_directory != 'Y'
order by creation_date
/
