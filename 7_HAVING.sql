select 
	delivery_city 
	,count(distinct customer_id)	as nr_of_customers
	,count(order_id) 
from orders o 
group by 1
having count(order_id) between 5 and 200 
order by 2 desc 