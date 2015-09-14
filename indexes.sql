
@@config

create index asmfiles_grp_file_idx on asmfiles(group_number, file_number, incarnation, snap_id);
create index asmfiles_snap_id_idx on asmfiles(snap_id);
create unique index diskgroups_pk_idx on diskgroups(group_number,snap_id);
create unique index diskgroups_name_idx on diskgroups(name,snap_id);
create index diskgroups_snap_id_idx on diskgroups(snap_id);
create unique index snapspace_pk_idx on snapspace(snap_id);
create index snapspace_date_idx on snapspace(snap_timestamp);


