
@@config

alter table diskgroups add constraint diskgroups_pk  primary key(group_number,snap_id);
-- docs say this is the primary key - incorrect
-- controlfiles fail this test, maybe others
--alter table asmfiles add constraint asmfiles_pk  primary key(group_number, file_number, incarnation);
alter table snapspace add constraint snapspace_pk  primary key(snap_id);
alter table asmfiles add constraint asmfiles_diskgroup_fk foreign key (group_number,snap_id) references diskgroups(group_number,snap_id);
alter table diskgroups add constraint diskgroups_snap_id_fk  foreign key(snap_id) references snapspace(snap_id);
alter table asmfiles add constraint asmfiles_snap_id_fk foreign key (snap_id) references snapspace(snap_id);


