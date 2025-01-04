select 
*
from orders o 
where 
(
	customer_id < 50
and delivery_city = 'Los Angeles'
)
or order_date < date('2020-01-01')

