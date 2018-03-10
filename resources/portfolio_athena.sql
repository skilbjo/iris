with now as (
  select cast(current_timestamp at time zone 'America/Los_Angeles' as date) as now
), date as (
  select
    (select now from now) today,
    case day_of_week(current_timestamp at time zone 'America/Los_Angeles') % 7
      when 1 then (select now from now) - interval '3' day
      when 0 then (select now from now) - interval '2' day
      else        (select now from now) - interval '1' day
    end as yesterday
), _equities as (
  select
    dataset,
    ticker,
    cast(date as date)                 as date,
    cast(open as decimal(10,2))        as open,
    cast(close as decimal(10,2))       as close,
    cast(low as decimal(10,2))         as low,
    cast(high as decimal(10,2))        as high,
    cast(volume as decimal(20,2))      as volume,
    cast(split_ratio as decimal(10,2)) as split_ratio,
    cast(adj_open as decimal(10,2))    as adj_open,
    cast(adj_close as decimal(10,2))   as adj_close,
    cast(adj_low as decimal(10,2))     as adj_low,
    cast(adj_volume as decimal(20,2))  as adj_volume,
    cast(ex_dividend as decimal(10,2)) as ex_dividend
  from
    dw.equities
), today as (
  select
    *
  from
    _equities
)
select * from today limit 50
