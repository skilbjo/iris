with date as (
  -- select (now() at time zone 'pst')::date now
  select '2018-02-20'::date now
)
select
  _t.*
from
  dw.equities _t
where
  _t.date in ( select now from date )
