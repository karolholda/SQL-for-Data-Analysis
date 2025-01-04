select 
	delivery_state 
	, max(order_date)	as last_order
	, min(order_date)	as first_order
from orders o 
group by 1