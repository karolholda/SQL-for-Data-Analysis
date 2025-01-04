select 
	order_id
	,order_date
	,delivery_city
	,delivery_state
	,count(order_id) over (partition by delivery_city)		as city_orders
	,min(order_date) over (partition by delivery_state)		as first_state_order
from orders o 