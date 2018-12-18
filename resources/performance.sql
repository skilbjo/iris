with now as (
  select (now() at time zone 'pst')::date now
), datasource as (
  select 'ALPHA-VANTAGE'::text as datasource
), date as (
  select
    (select now from now) today,
    case (extract(isodow from (select now from now))::integer) % 7
      when 1 then (select now from now) - 3
      when 0 then (select now from now) - 2
      else        (select now from now) - 1
    end as yesterday
), max_known_date as (
  select
    max(cast(date as date)) max_known_date
  from (
    select date, dataset, count(*)
    from dw.equities_fact
    where
      ticker in ( select distinct ticker from dw.portfolio_dim where dataset = ( select datasource from datasource ) )
      and date <> ( select now from now )
    group by
      1,2
    having count(*) > 33
   ) src
), beginning_of_year as (
  select date_trunc('year', ( select now from now)) + interval '1 day' beginning_of_year
    --  select '2018-01-02' beginning_of_year
), fx as (
  select
    currency, rate
  from
    dw.currency_fact
  where
    currency = 'GBP'
    and ( date = ( select today from date )
    or    date = ( select yesterday from date ) )
  order by date desc
  limit 1
), fx_backup as (
  select
    'GBP'::text currency, 1.30 rate
), fx_with_backup as (
  select
    coalesce(fx.currency,fx_backup.currency) currency,
    coalesce(fx.rate    ,fx_backup.rate) rate
  from fx
    right join fx_backup on fx.currency = fx_backup.currency
), equities as (
  select
    ticker,
    date,
    avg(case when ticker = 'LON:FCH' then close * (select rate from fx_with_backup where currency = 'GBP') / 100 else close end) as close
  from
    dw.equities_fact
  where
    date    = ( select today from date )
    or date = ( select yesterday from date )
    or date = ( select max_known_date from max_known_date )
    or date = ( select beginning_of_year from beginning_of_year )
    or date is null
  group by
    1,2
), classification as (
  select 'Mutual Fund' _type, 'VEMAX' _ticker union all
  select 'Mutual Fund',       'VEURX' union all
  select 'Mutual Fund',       'VEXPX' union all
  select 'Mutual Fund',       'VGSLX' union all
  select 'Mutual Fund',       'VGWAX' union all
  select 'Mutual Fund',       'VIMAX' union all
  select 'Mutual Fund',       'VINEX' union all
  select 'Mutual Fund',       'VITAX' union all
  select 'Mutual Fund',       'VMMSX' union all
  select 'Mutual Fund',       'VMMXX' union all
  select 'Mutual Fund',       'VMRAX' union all
  select 'Mutual Fund',       'VPACX' union all
  select 'Mutual Fund',       'VTIAX' union all
  select 'Mutual Fund',       'VTSAX' union all
  select 'Mutual Fund',       'VWENX' union all
  select 'Mutual Fund',       'VWIGX' union all
  select 'Mutual Fund',       'VWINX' union all
  select 'Mutual Fund',       'VWNDX' union all

  select         'ETF',         'VEA' union all
  select         'ETF',         'VFH' union all
  select         'ETF',         'VGT' union all
  select         'ETF',         'VHT' union all
  select         'ETF',         'VWO' union all

  select       'Stock',           'V' union all
  select       'Stock',          'CY' union all
  select       'Stock',          'GS' union all
  select       'Stock',          'SQ' union all
  select       'Stock',         'SAP' union all
  select       'Stock',         'TSM' union all
  select       'Stock',         'TXN' union all
  select       'Stock',        'AAPL' union all
  select       'Stock',        'AMZN' union all
  select       'Stock',        'GOOG' union all
  select       'Stock',        'INTC' union all
  select       'Stock',        'INTU' union all
  select       'Stock',        'NVDA' union all
  select       'Stock',        'PYPL' union all
  select       'Stock',       'BRK-B' union all
  select       'Stock',       'SFTBF' union all
  select       'Stock',     'LON:FCH'
), portfolio as (
  select
    classification._type classification,
    markets.description,
    portfolio.ticker,
    portfolio.quantity,
    portfolio.cost_per_share
  from
    dw.portfolio_dim portfolio
    join dw.markets_dim markets on markets.ticker = portfolio.ticker
    join classification on classification._ticker = portfolio.ticker
  where
    portfolio.dataset = ( select datasource from datasource )
  group by
    1,2,3,4,5
), today as (
  select
    portfolio.classification,
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
       = 1 -- VMMXX not available via TIINGO api
  group by
    1,2,3
), yesterday as (
  select
    portfolio.classification,
    portfolio.description,
    equities.ticker,
    sum((quantity * coalesce(close,cost_per_share))) yesterday
  from
    equities
    right join portfolio on equities.ticker = portfolio.ticker
  where
    date in ( select yesterday from date )
  group by
    1,2,3
), ytd as (
  select
    portfolio.classification,
    portfolio.description,
    equities.ticker,
    sum((quantity * coalesce(close,cost_per_share))) market_value
  from
    equities
    right join portfolio on equities.ticker = portfolio.ticker
  where
    date = ( select beginning_of_year from beginning_of_year )
  group by
    1,2,3
), backup as (
  select
    portfolio.classification,
    portfolio.description,
    equities.ticker,
    sum((quantity * cost_per_share))                 cost_basis,
    sum((quantity * coalesce(close,cost_per_share))) market_value,
    sum(((quantity * coalesce(close,cost_per_share)) - (quantity * cost_per_share))) gain_loss
  from
    equities
    right join portfolio on equities.ticker = portfolio.ticker
  where
    date in ( select max_known_date from max_known_date )
    or (case when equities.ticker in ('VMMXX')
              and date = (select beginning_of_year from beginning_of_year) then 1 else 0 end)
       = 1 -- VMMXX not available via TIINGO api
  group by
    1,2,3
), detail as (
  select
    coalesce(today.classification, yesterday.classification) classification,
    coalesce(today.description, yesterday.description) description,
    coalesce(today.ticker,      yesterday.ticker) ticker,
    today.cost_basis, today.market_value, today.gain_loss,
    today.market_value - ytd.market_value ytd_gain_loss,
    today.market_value - yesterday.yesterday today_gain_loss
  from
    today
    full outer join yesterday on today.ticker = yesterday.ticker
    full outer join ytd on yesterday.ticker = ytd.ticker
  order by today.market_value desc
), detail_with_backup as (
  select
    coalesce(detail.classification, backup.classification) classification,
    coalesce(detail.description,    backup.description) description,
    coalesce(detail.ticker,         backup.ticker) ticker,
    coalesce(detail.cost_basis,     backup.cost_basis) cost_basis,
    coalesce(detail.market_value,   backup.market_value) market_value,
    coalesce(detail.gain_loss,      backup.gain_loss) gain_loss,
    coalesce(detail.ytd_gain_loss,  backup.market_value - ytd.market_value, 0) ytd_gain_loss,
    coalesce(detail.today_gain_loss, 0) today_gain_loss
  from
    detail
    full outer join backup on detail.description = backup.description
    full outer join ytd on backup.description = ytd.description
), summary as (
  select
    'Portfolio Total'::text           classification,
    sum(cost_basis)         cost_basis,
    sum(market_value)       market_value,
    sum(gain_loss)          gain_loss,
    sum(ytd_gain_loss)      ytd_gain_loss,
    sum(today_gain_loss)    today_gain_loss
  from
    detail_with_backup
), classification_results as (
  select
    classification,
    sum(cost_basis)         cost_basis,
    sum(market_value)       market_value,
    sum(gain_loss)          gain_loss,
    sum(ytd_gain_loss)      ytd_gain_loss,
    sum(today_gain_loss)    today_gain_loss
  from
    detail_with_backup
  where ticker <> ''
  group by
    1
), benchmark as (
  select
    'Benchmark'             classification,
    sum(cost_basis)         cost_basis,
    sum(market_value)       market_value,
    sum(gain_loss)          gain_loss,
    sum(ytd_gain_loss)      ytd_gain_loss,
    sum(today_gain_loss)    today_gain_loss
  from
    detail_with_backup
  where ticker = 'VTSAX'
  group by
    1
), _union_pre as (
  select * from summary
  union all
  select * from classification_results
), _union as (
  select * from benchmark
  union all
  select * from _union_pre
), report_pre as (
  select
    classification,
    (market_value / ( select market_value from summary ) * 100)::decimal(8,2) || '%' "mix_%",
    cost_basis::int ,
    market_value::int,
    today_gain_loss::int,
    (today_gain_loss / market_value * 100)::decimal(8,2) || '%'  "today_gain_loss_%",
    ytd_gain_loss::int,
    (ytd_gain_loss / market_value * 100)::decimal(8,2)   || '%'  "ytd_gain_loss_%",
    gain_loss::int total_gain_loss,
    (gain_loss / cost_basis * 100)::decimal(8,2)         || '%'  "total_gain_loss_%"
  from
    _union
), report as (
  select
    classification,
    case when classification = 'Benchmark' then '---' else "mix_%"::text end,
    case when classification = 'Benchmark' then '---' else cost_basis::text end,
    case when classification = 'Benchmark' then '---' else market_value::text end,
    case when classification = 'Benchmark' then '---' else today_gain_loss::text end,
    "today_gain_loss_%",
    case when classification = 'Benchmark' then '---' else ytd_gain_loss::text end,
    "ytd_gain_loss_%",
    case when classification = 'Benchmark' then '---' else total_gain_loss::text end,
    case when classification = 'Benchmark' then '---' else "total_gain_loss_%" end
  from report_pre
)
select * from report
