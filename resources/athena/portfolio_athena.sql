with now_ts as (
  select current_timestamp at time zone 'America/Los_Angeles' as now_ts
), now as (
  select cast((select now_ts from now_ts) as date) as now
), _user as (
  select ':user' as _user
), datasource as (
  select 'ALPHA-VANTAGE' as datasource
), date as (
  select
    (select now from now) today,
    case day_of_week((select now_ts from now_ts)) % 7
      when 1 then (select now from now) - interval '3' day
      when 0 then (select now from now) - interval '2' day
      else        (select now from now) - interval '1' day
    end as yesterday
), beginning_of_year as (
  select date_trunc('year', ( select now from now)) + interval '1' day beginning_of_year
), portfolio as (
  select
    markets.asset_type,
    markets.location,
    markets.capitalization,
    markets.investment_style,
    markets.description,
    portfolio.ticker,
    cast(portfolio.quantity as decimal(10,4))      as quantity,
    cast(portfolio.cost_per_share as decimal(6,2)) as cost_per_share
  from
    dw.portfolio_dim portfolio
    join dw.markets_dim markets on markets.ticker = portfolio.ticker
  where
    portfolio.dataset = ( select datasource from datasource )
    and user = ( select _user from _user )
  group by
    1,2,3,4,5,6,7,8
), max_known_date as (
  select
    max(cast(date as date)) max_known_date
  from (
    select date, dataset, count(*)
    from dw.equities_fact
    where
      s3uploaddate >= cast((select beginning_of_year from beginning_of_year ) as date)
      and s3uploaddate <> cast((select now from now) as date)
      and ticker in ( select distinct ticker from portfolio )
      and dataset <> 'ALPHA-VANTAGE'
    group by
      1,2
    having count(*) > 30
   ) src
), fx as (
  select
    currency, cast(rate as decimal(24,14)) rate
  from
    dw.currency_fact
  where
    currency = 'GBP'
    and ( s3uploaddate = cast((select today from date ) as date)
    or    s3uploaddate = cast((select yesterday from date ) as date ))
  order by date desc
  limit 1
), fx_backup as (
  select
    'GBP' currency, 1.30 rate
), fx_with_backup as (
  select
    coalesce(fx.currency,fx_backup.currency) currency,
    coalesce(fx.rate    ,fx_backup.rate)     rate
  from fx
    right join fx_backup on fx.currency = fx_backup.currency
), equities as (
  select
    ticker,
    cast(date as date)                     as date,
    avg(case when ticker = 'LON:FCH' then try_cast(close as decimal(10,2)) * (select rate from fx_with_backup where currency = 'GBP') / 100 else try_cast(close as decimal(10,2)) end) as close
  from
    dw.equities_fact equities
  where
    s3uploaddate    = cast((select today from date) as date)
    or s3uploaddate = cast((select yesterday from date) as date)
    or s3uploaddate = cast((select max_known_date from max_known_date) as date)
    or s3uploaddate = cast((select beginning_of_year from beginning_of_year) as date)
  group by
    1,2
), today as (
  select
    portfolio.asset_type,
    portfolio.location,
    portfolio.capitalization,
    portfolio.investment_style,
    portfolio.description,
    equities.ticker,
    sum((quantity * cost_per_share))                 cost_basis,
    sum((quantity * coalesce(close,cost_per_share))) market_value,
    sum(((quantity * coalesce(close,cost_per_share)) - (quantity * cost_per_share))) gain_loss
  from
    equities
    right join portfolio on portfolio.ticker = equities.ticker
  where
    date = ( select today from date )
    or (case when equities.ticker in ('VMMXX')
              and date = (select beginning_of_year from beginning_of_year) then 1 else 0 end)
       = 1
  group by
    1,2,3,4,5,6
), yesterday as (
  select
    portfolio.asset_type,
    portfolio.location,
    portfolio.capitalization,
    portfolio.investment_style,
    portfolio.description,
    equities.ticker,
    sum((quantity * coalesce(close,cost_per_share))) yesterday
  from
    equities
    right join portfolio on portfolio.ticker = equities.ticker
  where
    date in ( select yesterday from date ) or date is null
  group by
    1,2,3,4,5,6
), ytd as (
  select
    portfolio.asset_type,
    portfolio.location,
    portfolio.capitalization,
    portfolio.investment_style,
    portfolio.description,
    equities.ticker,
    sum((quantity * coalesce(close,cost_per_share))) market_value
  from
    equities
    right join portfolio on portfolio.ticker = equities.ticker
  where
    date = ( select beginning_of_year from beginning_of_year )
  group by
    1,2,3,4,5,6
), backup as (
  select
    portfolio.asset_type,
    portfolio.location,
    portfolio.capitalization,
    portfolio.investment_style,
    portfolio.description,
    equities.ticker,
    sum((quantity * cost_per_share))                 cost_basis,
    sum((quantity * coalesce(close,cost_per_share))) market_value,
    sum(((quantity * coalesce(close,cost_per_share)) - (quantity * cost_per_share))) gain_loss
  from
    equities
    right join portfolio on portfolio.ticker = equities.ticker
  where
    date in ( select max_known_date from max_known_date )
    or (case when equities.ticker in ('VMMXX')
              and date = (select beginning_of_year from beginning_of_year) then 1 else 0 end)
       = 1
  group by
    1,2,3,4,5,6
), detail as (
  select
    coalesce(today.asset_type,       yesterday.asset_type) asset_type,
    coalesce(today.location,         yesterday.location) as location,
    coalesce(today.capitalization,   yesterday.capitalization) capitalization,
    coalesce(today.investment_style, yesterday.investment_style) investment_style,
    coalesce(today.description,      yesterday.description) description,
    coalesce(today.ticker,           yesterday.ticker) ticker,
    today.cost_basis,
    today.market_value,
    today.gain_loss,
    today.market_value - ytd.market_value ytd_gain_loss,
    today.market_value - yesterday.yesterday today_gain_loss
  from
    today
    full outer join yesterday on today.ticker = yesterday.ticker
    full outer join ytd on yesterday.ticker = ytd.ticker
  order by today.market_value desc
), detail_with_backup as (
  select
    coalesce(detail.asset_type,       backup.asset_type) asset_type,
    coalesce(detail.location,         backup.location) as location,
    coalesce(detail.capitalization,   backup.capitalization) capitalization,
    coalesce(detail.investment_style, backup.investment_style) investment_style,
    coalesce(detail.description,      backup.description) description,
    coalesce(detail.ticker,           backup.ticker) ticker,
    coalesce(detail.cost_basis,       backup.cost_basis) cost_basis,
    coalesce(detail.market_value,     backup.market_value) market_value,
    coalesce(detail.gain_loss,        backup.gain_loss) gain_loss,
    coalesce(detail.ytd_gain_loss, backup.market_value - ytd.market_value, 0) ytd_gain_loss,
    coalesce(detail.today_gain_loss, 0) today_gain_loss
  from
    detail
    full outer join backup on detail.description = backup.description
    full outer join ytd on backup.description = ytd.description
), summary as (
  select
    'TOTAL'                 ticker,
    'Portfolio Total'       description,
    sum(cost_basis)         cost_basis,
    sum(market_value)       market_value,
    sum(gain_loss)          gain_loss,
    sum(ytd_gain_loss)      ytd_gain_loss,
    sum(today_gain_loss)    today_gain_loss
  from
    detail_with_backup
), benchmark as (
  select
    'Benchmark'             ticker,
    'Benchmark'             description,
    sum(cost_basis)         cost_basis,
    sum(market_value)       market_value,
    sum(gain_loss)          gain_loss,
    sum(ytd_gain_loss)      ytd_gain_loss,
    sum(today_gain_loss)    today_gain_loss
  from
    detail_with_backup
  where ticker = 'VTSAX'
  group by
    1,2
), results as (
  select
    ticker,
    description,
    sum(cost_basis)         cost_basis,
    sum(market_value)       market_value,
    sum(gain_loss)          gain_loss,
    sum(ytd_gain_loss)      ytd_gain_loss,
    sum(today_gain_loss)    today_gain_loss
  from
    detail_with_backup
  where ticker <> ''
  group by
    1,2
  order by market_value desc
), _union as (
  select * from summary
  union all
  select * from results
), report_pre as (
  select
    ticker,
    cast(cast((market_value / ( select market_value from summary ) * 100) as decimal(8,2)) as varchar) || '%' "mix_%",
    description,
    cast(cost_basis as integer) cost_basis,
    cast(market_value as integer) market_value,
    cast(today_gain_loss as integer) today_gain_loss,
    cast(cast((today_gain_loss / market_value * 100) as decimal(8,2)) as varchar) || '%'  "today_gain_loss_%",
    cast(ytd_gain_loss as integer) ytd_gain_loss,
    cast(cast((ytd_gain_loss / market_value * 100) as decimal(8,2)) as varchar)   || '%'  "ytd_gain_loss_%",
    cast(gain_loss as integer) total_gain_loss,
    cast(cast((gain_loss / cost_basis * 100) as decimal(8,2)) as varchar)         || '%'  "total_gain_loss_%"
  from
    _union
)
select * from report_pre
limit 5
