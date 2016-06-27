

-- set this to '' for CSV output, and '--' for standard output
define CSVOUT=''

@@config.sql

col total_mb format &&space_size_format head 'Total MB'
col free_mb format &&space_size_format head 'Free MB'
col required_mirror_free_mb format &&space_size_format head 'Required Mirror|Free MB'
col usable_file_mb format &&space_size_format head 'Usable File MB'
col diskgroup format a20
col snaptime format a22 head 'SnapTime'

set linesize 200 trimspool on


col u_pagesize new_value u_pagesize noprint
col u_feedstate new_value u_feedstate noprint
col u_spoolcmd new_value u_spoolcmd noprint
col RPTOUT new_value RPTOUT noprint

set term off feed off

select decode('&&CSVOUT','--',60,50000) u_pagesize from dual;
select decode('&&CSVOUT','--','on','off') u_feedstate from dual;
select decode('&&CSVOUT','--','off','asm-dg-space-rpt.csv') u_spoolcmd from dual;
select decode('&&CSVOUT','--','','--') RPTOUT from dual;

set pagesize &&u_pagesize

set head off term on timing off

spool &&u_spoolcmd

select  null
	&&CSVOUT , q'[DISKGROUP,SnapTime,Total MB,Free MB,Required Mirror Free MB,Usable File MB]'
from dual;

spool off

set feed &&u_feedstate head &&u_feedstate

spool &&u_spoolcmd append

with max_snaps as (
	-- get the max snap per day for purposes of this report,
	-- as snapshots can be taken at any frequency
	select distinct max(snap_id) over (partition by trunc(snap_timestamp)) snap_id
	from &&asmspc_owner..SNAPSPACE
)
select 
	&&RPTOUT d.name diskgroup
	&&RPTOUT , to_char(s.snap_timestamp,'&&date_format') snaptime
	&&RPTOUT , d.total_mb
	&&RPTOUT , d.free_mb
	&&RPTOUT , d.required_mirror_free_mb
	&&RPTOUT , d.usable_file_mb
	&&CSVOUT d.name
	&&CSVOUT || ',' || to_char(s.snap_timestamp,'&&date_format')
	&&CSVOUT || ',' || d.total_mb
	&&CSVOUT || ',' || d.free_mb
	&&CSVOUT || ',' || d.required_mirror_free_mb
	&&CSVOUT || ',' || d.usable_file_mb
from max_snaps mx
join &&asmspc_owner..SNAPSPACE s on s.snap_id = mx.snap_id
join &&asmspc_owner..DISKGROUPS d on d.snap_id = mx.snap_id
order by 
	&&RPTOUT diskgroup, d.snap_id
	&&CSVOUT 1
/

set pagesize 60 feed on

spool off



