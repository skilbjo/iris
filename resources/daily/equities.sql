with date as (
  select (now() at time zone 'pst')::date now
)
select
  _t.*
from
  dw.equities_fact _t
where
  _t.date in ( select now from date )
