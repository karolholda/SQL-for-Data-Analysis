WITH BaseData as (
    SELECT 
        o.item_id,
        i.sku,
        i.item_name,
        r.ing_id,
        ing.ing_name,
        r.quantity 																		as receipe_quantity,
        SUM(o.quantity) 																as order_quantity,
        ing.ing_weight,
        ing.ing_price
    FROM orders o
    LEFT JOIN item i ON o.item_id = i.item_id
    LEFT JOIN recipe r ON i.sku = r.recipe_id
    LEFT JOIN ingredient ing ON ing.ing_id = r.ing_id
    GROUP BY 
        o.item_id,
        i.sku,
        i.item_name,
        r.ing_id,
        r.quantity,
        ing.ing_name,
        ing.ing_weight,
        ing.ing_price
),
FinalData as (
    SELECT 
        s1.item_name,
        s1.ing_id,
        s1.ing_name,
        s1.order_quantity,
        s1.receipe_quantity,
        s1.order_quantity * s1.receipe_quantity 										as ordered_weight,
        s1.ing_price / s1.ing_weight as unit_cost,
        (s1.order_quantity * s1.receipe_quantity) * (s1.ing_price / s1.ing_weight) 		as ingredient_cost
    FROM BaseData s1
)
SELECT 
	s2.ing_name
	,s2.ordered_weight
	,ing.ing_weight*inv.quantity 														as total_inv_weight
	,(ing.ing_weight * inv.quantity) - s2.ordered_weight								as remaining_weight
	FROM (
		select
		ing_id
		,ing_name
		,sum(ordered_weight)															as ordered_weight
	from FinalData
	group by 
		ing_name
		,ing_id
) s2

left join inventory inv on inv.item_id = s2.ing_id
left join ingredient ing on ing.ing_id = s2.ing_id


