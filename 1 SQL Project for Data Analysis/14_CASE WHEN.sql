select 
	o.*
	,case 
		when o.orders = 1 then 'New'
		when o.orders > 1 and o.orders < 5 then 'Regular'
		when o.orders >= 5 and o.orders < 10 then 'Loyal'
		else 'Very Loyal'
	end	as customer_type
from
(
select
	customer_id
	,count(order_id) as orders 
from orders 
group by 1
) o

NOW()