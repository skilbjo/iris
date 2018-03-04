with now as (
  select '2018-02-27'::date now
--  select (now() at time zone 'pst')::date now
), date as (
  select
    (select now from now) today,
    case (extract(isodow from (select now from now))::integer) % 7
      when 1 then (select now from now) - 3
      when 0 then (select now from now) - 2
      else        (select now from now) - 1
    end as yesterday
), cost_basis as (
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
    date in ( select today from date )
  group by
    1
), yesterday as (
  select *
  from crosstab(
    $$with now as (
      select '2018-02-27'::date now
    ), date as (
      select
        (select now from now) today,
        case (extract(isodow from (select now from now))::integer) % 7
          when 1 then (select now from now) - 3
          when 0 then (select now from now) - 2
          else        (select now from now) - 1
        end as yesterday
    ), result as (
    select
      markets.description,
      date,
      sum((quantity * close))                                 market_value
    from
      dw.equities
      join dw.portfolio on equities.dataset = portfolio.dataset and equities.ticker = portfolio.ticker
      join dw.markets on equities.dataset = markets.dataset and equities.ticker = markets.ticker
    where
      date in ( (select today from date) , (select yesterday from date ) )
    group by
      1,2
    order by
      1,2
    ) select * from result
    order by
      1$$,
      $$with now as (select '2018-02-27'::date now) select now date from now union all select  case (extract(isodow from (select now from now))::integer) % 7 when 1 then (select now from now) - 3 when 0 then (select now from now) - 2 else (select now from now) - 1 end order by 1$$
   ) as ct (description text, yesterday decimal(10,2), today decimal(10,2))
), detail as (
  select
    cost_basis.*,
    cost_basis.market_value - yesterday.yesterday today_gain_loss
  from
    cost_basis
    join yesterday on cost_basis.description = yesterday.description
), summary as (
  select
    'Portfolio Total'::text description,
    sum(cost_basis)         cost_basis,
    sum(market_value)       market_value,
    sum(gain_loss)          gain_loss,
    sum(today_gain_loss)    today_gain_loss
  from
    detail
), _union as (
  select * from summary
  union all
  select * from detail
), report as (
  select
    description, cost_basis::int , market_value::int, gain_loss::int total_gain_loss,
    (gain_loss / market_value * 100)::decimal(8,2) || '%'  "total_gain_loss_%",
    today_gain_loss::int,
    (today_gain_loss / market_value * 100)::decimal(8,2) || '%'  "today_gain_loss_%"
  from
    _union
)
select * from report
