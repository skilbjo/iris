with dates as (
  select
    '2018-07-20'::date as _start,
    '2018-10-31'::date as _end
)
select * from crosstab (
  'select date,device,count(*)
   from dw.log
   group by 1,2
   order by 1,2',
  'select distinct device from dw.log order by 1'
)  as ct (date date,firewall int, pfsense int, pfsense2 int, router int)
where date between (select _start from dates)
               and (select _end   from dates)
order by 1 desc;
