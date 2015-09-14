
@@config

set serveroutput on size unlimited

create or replace package body &&asmspc_owner..asm_space
is

	v_date_format varchar2(30) := '&&date_format';
	
	type v_tabtyp_v is table of varchar2(2000) index by varchar2(30);
	type v_tabtyp_n is table of varchar2(2000) index by pls_integer;
	v_tab_sql v_tabtyp_v;
	v_ind_sql v_tabtyp_v;
	v_con_sql v_tabtyp_v;

	v_constraint_names v_tabtyp_v;

	v_table_name varchar2(30);
	v_index_name varchar2(30);
	v_constraint_name varchar2(30);


function get_next_snap_id return number
is
	n_max_snap_id number(12,0) := 0;
	v_sql varchar2(100) := 'select nvl(max(snap_id),0)+1 max_snap_id from snapspace';
begin
	execute immediate v_sql into n_max_snap_id;
	return n_max_snap_id;
end;


procedure insert_diskgroups( n_snap_id_in number )
is
	v_sql varchar2(2100);

	type diskgroups_rectype is record (
		group_number diskgroups.group_number%type,
		name diskgroups.name%type,
		sector_size diskgroups.sector_size%type,
		snap_id diskgroups.snap_id%type,
		block_size diskgroups.block_size%type,
		allocation_unit_size diskgroups.allocation_unit_size%type,
		type diskgroups.type%type,
		total_mb diskgroups.total_mb%type,
		free_mb diskgroups.free_mb%type,
		required_mirror_free_mb diskgroups.required_mirror_free_mb%type,
		usable_file_mb diskgroups.usable_file_mb%type
	);

	type dg_tab_type is table of diskgroups_rectype;

	dg_tab dg_tab_type;

begin

	select 
		group_number           
		, name                   
		, sector_size            
		, 1 snap_id                
		, block_size             
		, allocation_unit_size   
		, type                   
		, total_mb               
		, free_mb                
		, required_mirror_free_mb
		, usable_file_mb         
	bulk collect into dg_tab
	from v$asm_diskgroup;

	for i in dg_tab.First..dg_tab.Last
	loop
		dg_tab(i).snap_id := n_snap_id_in;
	end loop;
			
	forall x in dg_tab.First..dg_tab.Last
	insert into diskgroups values dg_tab(x);

end;

procedure insert_snapspace( n_snap_id_in number, t_timestamp_in timestamp)
is
	v_sql varchar2(2100);
begin
	v_sql := 'insert into snapspace(snap_id, snap_timestamp) values(:1, :2)';
	execute immediate v_sql using n_snap_id_in, t_timestamp_in;

end;

--/*

procedure insert_asmfiles( n_snap_id_in number)
is
	v_sql varchar2(2100);

	-- table:  asmfiles
	type asmfiles_rectype is record (
		group_number asmfiles.group_number%type,
		file_number asmfiles.file_number%type,
		incarnation asmfiles.incarnation%type,
		snap_id asmfiles.snap_id%type,
		db_name asmfiles.db_name%type,
		full_path asmfiles.full_path%type,
		block_size asmfiles.block_size%type,
		blocks asmfiles.blocks%type,
		bytes asmfiles.bytes%type,
		space_allocated asmfiles.space_allocated%type,
		file_type asmfiles.file_type%type
	);

	type f_tab_type is table of asmfiles_rectype;

	f_tab f_tab_type;

begin

	select
		f.group_number
		, f.file_number
		, f.incarnation
		, 1 snap_id
		, lower(substr(f.full_path,
			instr(full_path,'/',1,1)+1,
			instr(full_path,'/',1,2) - instr(full_path,'/',1,1)-1
		)) db_name
		, f.full_path
		, f.block_size
		, f.blocks
		, f.bytes
		, f.space_allocated
		, f.file_type
	bulk collect into f_tab
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
		, incarnation
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
			, c.incarnation
			, to_char(c.creation_date,v_date_format) creation_date
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
	order by creation_date;

	
	for i in f_tab.First..f_tab.Last
	loop
		f_tab(i).snap_id := n_snap_id_in;
	end loop;
			
	forall x in f_tab.First..f_tab.Last
	insert into asmfiles values f_tab(x) ;

end;

--*/

procedure run
is
	t_current_timestamp timestamp;
	n_snap_id number;
begin

	n_snap_id := get_next_snap_id;
	t_current_timestamp := systimestamp;

	insert_snapspace(n_snap_id, t_current_timestamp);

	dbms_output.put_line('snap_id: ' || to_char(n_snap_id));

	insert_diskgroups(n_snap_id);
	insert_asmfiles(n_snap_id);

	commit;

end;

end;
/

show errors package body &&asmspc_owner..asm_space

