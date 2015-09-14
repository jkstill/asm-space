
@@config

set serveroutput on size unlimited

create or replace package body &&asmspc_owner..asm_space
is


	type v_tabtyp_v is table of varchar2(2000) index by varchar2(30);
	type v_tabtyp_n is table of varchar2(2000) index by pls_integer;
	v_tab_sql v_tabtyp_v;
	v_ind_sql v_tabtyp_v;
	v_con_sql v_tabtyp_v;

	v_constraint_names v_tabtyp_v;

	v_table_name varchar2(30);
	v_index_name varchar2(30);
	v_constraint_name varchar2(30);

	-- ORA-00955: already exists
	e_table_exists exception ;
	pragma exception_init(e_table_exists,-955);

	-- ORA-00942: table does not exist
	e_table_not_exists exception ;
	pragma exception_init(e_table_not_exists,-942);

	-- ORA-02260: table can have only one primary key
	e_pk_exists exception;
	pragma exception_init(e_pk_exists,-2260);

	-- ORA-02275: such a referential constraint already exists in the table
	e_ref_cons_exists exception ;
	pragma exception_init(e_ref_cons_exists,-2275);

	-- raised when index exists
	-- ORA-00955: name is already used by an existing object
	e_index_exists exception ;
	pragma exception_init(e_index_exists,-955);

	constraint_obj_type constant varchar2(10) := 'CONSTRAINT';

-- when checking constraints we are not doing a 100% validity test
-- this just checks the name of the constraint
-- sufficient for this package. 
function does_object_exist(v_object_name varchar2, v_object_type varchar2) return boolean
is
	cursor c1 ( cv_object_name_in varchar2, cv_object_type_in varchar2)
	is
	select count(*) tabcount 
	from user_objects 
	where object_name = cv_object_name_in
	and object_type = cv_object_type_in;

	cursor c2 (cv_constraint_name_in varchar2)
	is
	select count(*) conscount
	from user_constraints
	where constraint_name = (cv_constraint_name_in);

	i_objcount integer := 0;
begin
	if v_object_type = constraint_obj_type then
		--dbms_output.put_line('Constraint: ' || v_object_name);
		open c2(v_object_name);
		fetch c2 into i_objcount;
		close c2;
		--dbms_output.put_line('conscount: ' || to_char(i_objcount));
		if i_objcount >= 1 then
			return true;
		else 
			return false;
		end if;
	else
		open c1(v_object_name, v_object_type);
		fetch c1 into i_objcount;
		close c1;
		if i_objcount = 1 then
			return true;
		else 
			return false;
		end if;
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
	dbms_output.put_line('Backtrace:');
	dbms_output.put_line(substr(dbms_utility.format_error_backtrace,1,4000));
	dbms_output.put_line('SQL that failed: ' || v_sql);
	raise;
end;

-- expects full sql statement
function run_ddl ( v_sql_in varchar2) return boolean
is
	v_sql varchar2(2100);
begin
	execute immediate v_sql_in;
	return true;
exception
when e_index_exists then
	dbms_output.put_line('Backtrace:');
	dbms_output.put_line(substr(dbms_utility.format_error_backtrace,1,4000));
	dbms_output.put_line('INDEX Exists: ' || v_sql_in);
	return true;
when e_ref_cons_exists then
	dbms_output.put_line('Backtrace:');
	dbms_output.put_line(substr(dbms_utility.format_error_backtrace,1,4000));
	dbms_output.put_line('FK Exists: ' || v_sql_in);
	return true;
when e_pk_exists then
	dbms_output.put_line('Backtrace:');
	dbms_output.put_line(substr(dbms_utility.format_error_backtrace,1,4000));
	dbms_output.put_line('PK Exists: ' || v_sql_in);
	return true;
when others then
	dbms_output.put_line('Backtrace:');
	dbms_output.put_line(substr(dbms_utility.format_error_backtrace,1,4000));
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
		USABLE_FILE_MB           NUMBER';

	v_tab_sql('ASMFILES') := 'GROUP_NUMBER NUMBER,
		FILE_NUMBER     NUMBER,
		INCARNATION     NUMBER,
		FULL_PATH       VARCHAR2(200),
		BLOCK_SIZE      NUMBER(5),
		BLOCKS          NUMBER(12),
		BYTES           NUMBER(18),
		SPACE_ALLOCATED NUMBER(18),
		FILE_TYPE       VARCHAR2(20)';

	v_ind_sql('ASMFILES_PK') := 'create unique index asmfiles_pk on asmfiles(group_number, file_number, incarnation)';
	v_ind_sql('DISKGROUPS_PK') := 'create unique index diskgroups_pk on diskgroups(group_number)';
	v_ind_sql('DISKGROUPS_NAME') := 'create unique index diskgroups_name on diskgroups(name)';

	v_con_sql ('DISKGROUPS_PK') := 'alter table diskgroups add constraint diskgroups_pk  primary key(group_number)';
	v_con_sql ('ASMFILES_PK') := 'alter table asmfiles add constraint asmfiles_pk  primary key(group_number, file_number, incarnation)';
	v_con_sql ('ASMFILES_DISKGROUP_FK') := 'alter table asmfiles add constraint asmfiles_diskgroup_fk foreign key (group_number) references  diskgroups(group_number)';

	v_constraint_names(1) := 'DISKGROUPS_PK';
	v_constraint_names(2) := 'ASMFILES_PK';
	v_constraint_names(3) := 'ASMFILES_DISKGROUP_FK';

	v_table_name := v_tab_sql.first;
	while v_table_name is not null loop

		if not does_object_exist(v_table_name,'TABLE') then
			if create_table(v_table_name, v_tab_sql(v_table_name)) then
				dbms_output.put_line('created table ' || v_table_name);
			end if;
		end if;

		v_table_name := v_tab_sql.next(v_table_name);

	end loop;

--/*

	v_index_name := v_ind_sql.first;
	while v_index_name is not null loop
		if not does_object_exist(v_index_name,'INDEX') then
			if run_ddl(v_ind_sql(v_index_name)) then
				dbms_output.put_line('created index ' || v_index_name);
			end if;
		end if;
		v_index_name := v_ind_sql.next(v_index_name);
	end loop;

--/* 

	for i in v_constraint_names.first .. v_constraint_names.last
	loop
		v_constraint_name := v_constraint_names(i);

		if not does_object_exist(v_constraint_name,constraint_obj_type) then
			--dbms_output.put_line(v_constraint_name);
			if run_ddl(v_con_sql(v_constraint_name)) then
				dbms_output.put_line('created constraint ' || v_constraint_name);
			end if;
		end if;
	end loop;

--*/

end;


procedure run
is
begin
	init;
end;


end;
/

show errors package body &&asmspc_owner..asm_space

