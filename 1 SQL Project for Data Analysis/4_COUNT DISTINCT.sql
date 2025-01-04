select 
	shipping_mode 
	,count(order_id)
	,count(distinct customer_id) 
from orders o
where delivery_city = 'Los Angeles'
group by 1