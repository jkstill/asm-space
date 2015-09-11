
@@config

set serveroutput on size unlimited

create or replace package body &&asmspc_owner..asm_space
is


	type v_tabtyp_v is table of varchar2(2000) index by varchar2(30);
	v_tab_sql v_tabtyp_v;

	v_table_name varchar2(30);

	-- ORA-00955 already exists
	e_table_exists exception ;
	pragma exception_init(e_table_exists,-955);

	-- ORA-00942 table does not exist
	e_table_not_exists exception ;
	pragma exception_init(e_table_not_exists,-942);


function does_table_exist(v_table_name_in varchar2) return boolean
is
	cursor c1 ( cv_table_name_in varchar2)
	is
	select count(*) tabcount 
	from user_tables 
	where table_name = cv_table_name_in;

	i_tabcount integer := 0;
begin
	open c1(v_table_name_in);
	fetch c1 into i_tabcount;
	close c1;
	if i_tabcount = 1 then
		return true;
	else 
		return false;
	end if;
end;

function create_table ( v_table_name_in varchar2, v_sql_in varchar2 ) return boolean
is
	v_sql varchar2(2100);
begin
	v_sql := 'create table ' || v_table_name_in || '( ' || v_sql_in || ')';
	--dbms_output.put_line('SQL : ' || v_sql);
	execute immediate v_sql;
	return true;
exception
when e_table_exists then
	return true;
when others then
	dbms_output.put_line('SQL that failed: ' || v_sql);
	raise;
end;

procedure init 
is
begin

	v_tab_sql('DISKGROUPS') := ' GROUP_NUMBER NUMBER,
		NAME                     VARCHAR2(30),
		SECTOR_SIZE              NUMBER,
		BLOCK_SIZE               NUMBER,
		ALLOCATION_UNIT_SIZE     NUMBER,
		TYPE                     VARCHAR2(6),
		TOTAL_MB                 NUMBER,
		FREE_MB                  NUMBER,
		REQUIRED_MIRROR_FREE_MB  NUMBER,
		USABLE_FILE_MB                                                 NUMBER';

	v_tab_sql('ASMFILES') := 'GROUP_NUMBER NUMBER,
		FILE_NUMBER     NUMBER,
		FULL_PATH       VARCHAR2(200),
		BLOCK_SIZE      NUMBER(5),
		BLOCKS          NUMBER(12),
		BYTES           NUMBER(18),
		SPACE_ALLOCATED NUMBER(18),
		FILE_TYPE       VARCHAR2(20)';

	v_table_name := v_tab_sql.first;

	while v_table_name is not null loop

		if not does_table_exist(v_table_name) then
			if create_table(v_table_name, v_tab_sql(v_table_name)) then
				dbms_output.put_line('created ' || v_table_name);
			end if;
		end if;

		v_table_name := v_tab_sql.next(v_table_name);

	end loop;
end;


procedure run
is
begin
	init;
end;


end;
/

show errors package body &&asmspc_owner..asm_space

