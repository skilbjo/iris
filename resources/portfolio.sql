with date as (
  select '2018-02-27'::date now
--  select (now() at time zone 'pst')::date now
), detail as (
  select
    markets.description,
    sum((quantity * cost_per_share))                        cost_basis,
    sum((quantity * close))                                 market_value,
    sum(((quantity * close) - (quantity * cost_per_share))) gain_loss
  from
    dw.equities
    join dw.portfolio on equities.dataset = portfolio.dataset and equities.ticker = portfolio.ticker
    join dw.markets on equities.dataset = markets.dataset and equities.ticker = markets.ticker
  where
    date in ( select now from date )
  group by
    1
), summary as (
  select
    'Portfolio Total'::text description,
    sum(cost_basis)         cost_basis,
    sum(market_value)       market_value,
    sum(gain_loss)          gain_loss
  from
    detail
), _union as (
  select * from summary
  union all
  select * from detail
), report as (
  select
    description, cost_basis::int , market_value::int, gain_loss::int,
    (gain_loss / market_value * 100)::decimal(8,2) || '%'  "gain_loss_%"
  from
    _union
)
select * from report
