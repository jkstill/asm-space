
@@config

grant select on v_$asm_alias to &&asmspc_owner;
grant select on v_$asm_diskgroup to &&asmspc_owner;
grant select on v_$asm_file to &&asmspc_owner;

grant select on gv_$asm_alias to &&asmspc_owner;
grant select on gv_$asm_diskgroup to &&asmspc_owner;
grant select on gv_$asm_file to &&asmspc_owner;

grant connect, resource, create session to &&asmspc_owner;

grant create job to &&asmspc_owner;



