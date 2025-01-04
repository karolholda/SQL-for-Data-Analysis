with 
orders_per_customer as 
	(
	select
		customer_id
		,count(order_id) as orders
	from orders 
	group by 1
	),
all_customers as 
	(
	select
		count(distinct customer_id)	 as total_customers
	from orders
	),
customers_histogram as
	(
	select
		orders
		,count(customer_id) 		as customers
	from orders_per_customer
	group by 1
	)
	select 
		ch.orders
		,round((ch.customers / ac.total_customers) * 100, 1)	as prc_distribution_of_customers
	from customers_histogram ch
	cross join all_customers ac
