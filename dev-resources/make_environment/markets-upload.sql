create temp table markets_stage (

);

\copy markets_stage () from '/Users/skilbjo/dev/iris/dev-resources/make_environment/markets.csv' with csv header;

begin;

  update dw.markets_dim
  set
  from
    markets_stage
  where

  insert into dw.markets_dim (
    _user,
    dataset,
    ticker,
    quantity,
    cost_per_share
  )
  select
    markets_stage._user,
    markets_stage.dataset,
    markets_stage.ticker,
    markets_stage.quantity,
    markets_stage.cost_per_share
  from
    markets_stage
    left join dw.markets_dim on
  where
    markets_dim.ticker is null;

commit;
