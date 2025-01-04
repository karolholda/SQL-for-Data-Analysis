select 
	o.customer_id 
	,or2.order_id 
	,or2.next_order_free 
from orders o
right join order_returns or2 on o.order_id = or2.order_id 
