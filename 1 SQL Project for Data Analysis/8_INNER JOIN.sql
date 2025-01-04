select 
	o.delivery_state 
	,o.shipping_mode 
	,ds.nr_of_orders_ds 
	,count(o.order_id)	as nr_of_orders 
	,concat(round(count(o.order_id)/ds.nr_of_orders_ds, 2)*100, ' %')	as ds_ratio_percent
from orders o 
inner join (
select 
	ds.delivery_state 
	,count(ds.order_id)	as nr_of_orders_ds 
from orders ds
group by 1
) ds on ds.delivery_state = o.delivery_state
group by 1, 2, 3
order by 1, 2

