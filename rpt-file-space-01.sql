

-- set this to '' for CSV output, and '--' for standard output
define CSVOUT=''

@@config.sql

-- setup your column formats
col full_path format a60 head 'Full Path'
col file_number head 'File#' format 99999
col block_size head 'Block|Size' format 99999
col blocks format 999,999,999 
col bytes format &&space_size_format
col space_allocated head 'Space Alloc' format &&space_size_format


-- do not edit below here --
set linesize 400 trimspool on

col u_pagesize new_value u_pagesize noprint
col u_feedstate new_value u_feedstate noprint
col u_spoolcmd new_value u_spoolcmd noprint
col RPTOUT new_value RPTOUT noprint

set term off feed off timing off

select decode('&&CSVOUT','--',60,50000) u_pagesize from dual;
select decode('&&CSVOUT','--','on','off') u_feedstate from dual;
select decode('&&CSVOUT','--','off','asm-file-space-rpt.csv') u_spoolcmd from dual;
select decode('&&CSVOUT','--','','--') RPTOUT from dual;

set pagesize &&u_pagesize

set head off term on 

spool &&u_spoolcmd

select  null
	&&CSVOUT , q'[DB Name,File#,FullPath,SnapTime,File Type,Block Size,Blocks,Bytes,Space Allocated]'
from dual;

spool off

set feed &&u_feedstate head &&u_feedstate

spool &&u_spoolcmd append

-- do not edit above here --

-- example query 
with max_snaps as (
	-- get the max snap per day for purposes of this report,
	-- as snapshots can be taken at any frequency
	select distinct max(snap_id) over (partition by trunc(snap_timestamp)) snap_id
	from &&asmspc_owner..SNAPSPACE
	--where rownum <= 2000
),
data as (
	select
	-- Standard Report Output
	nvl(f.db_name,'Unknown') db_name
	, f.file_number
	, f.full_path
	, to_char(s.snap_timestamp,'&&date_format') snap_timestamp
	, f.file_type
	, f.block_size
	, f.blocks
	, f.bytes
	, f.space_allocated
from max_snaps mx
join &&asmspc_owner..SNAPSPACE s on s.snap_id = mx.snap_id
join &&asmspc_owner..ASMFILES f on f.snap_id = mx.snap_id
order by f.db_name
	, f.file_number
	, f.snap_id
)
select 
	-- Standard Report Output
	&&RPTOUT nvl(db_name,'Unknown') db_name
	&&RPTOUT , file_number
	&&RPTOUT , full_path
	&&RPTOUT , to_char(snap_timestamp,'&&date_format') snaptime
	&&RPTOUT , file_type
	&&RPTOUT , block_size
	&&RPTOUT , blocks
	&&RPTOUT , bytes
	&&RPTOUT , space_allocated
	-- CSV Output
	-- removing the '+' from leading character of full path
	-- as MS Excel simply cannot handle it, even if quoted
	&&CSVOUT nvl(db_name,'Unknown') 
	&&CSVOUT || ',' || file_number
	&&CSVOUT || ',"' || decode(substr(full_path,1,1),'+',substr(full_path,2),full_path) || '"'
	&&CSVOUT || ',' || snap_timestamp
	&&CSVOUT || ',' || file_type
	&&CSVOUT || ',' || block_size
	&&CSVOUT || ',' || blocks
	&&CSVOUT || ',' || bytes
	&&CSVOUT || ',' || space_allocated
from data d
/

set pagesize 60 feed on

spool off



