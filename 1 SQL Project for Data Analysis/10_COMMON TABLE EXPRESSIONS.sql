with
needed_states as 
	(
	select delivery_state
	from orders
	group by 1
	having count(distinct customer_id) > 100 
	),
all_orders as 
	(
	select count(order_id)	as total_orders
	from orders
	),
ds_orders as
	(
	select delivery_state
	,count(order_id)											as orders_ds
	from orders 
	group by 1
	),
ds_sm_orders as
	(
	select 
		delivery_state
		,shipping_mode
		,count(order_id)										as orders_ds_sm
	from orders 
	group by 1, 2
	)
select 
	dss.delivery_state
	,dss.shipping_mode
	,dss.orders_ds_sm
	,dso.orders_ds
	,ao.total_orders
	,round((dss.orders_ds_sm / dso.orders_ds) * 100, 1)			as ds_ratio_percent 
from ds_sm_orders 												dss
join ds_orders 													dso	on dss.delivery_state = dso.delivery_state										
cross join all_orders											ao 
join needed_states												ns on ns.delivery_state = dss.delivery_state