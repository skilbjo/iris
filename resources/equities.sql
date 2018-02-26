with date as (
  select (now() at time zone 'pst' - interval '3 day')::date now
)
select
  _t.*
from
  dw.equities _t
where
  _t.date in ( select now from date )
