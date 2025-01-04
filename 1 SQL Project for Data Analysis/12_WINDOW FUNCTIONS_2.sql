select 
	cost_forecast_id
	,cost_forecast
	,str_to_date(CONCAT(cost_year, '-01-01'), '%Y-%m-%d') 	as cost_date
/* no partition */
	,row_number() over (order by cost_forecast desc)		as row_number_ranking
	,rank() over (order by cost_forecast desc)				as rank_ranking
	,dense_rank() over (order by cost_forecast desc)		as dense_rank_ranking
/* pratition by year */
	,row_number() over (order by cost_forecast desc)		as row_number_ranking
	,rank() over 
		(partition by cost_year order by cost_forecast desc)				as rank_ranking
	,dense_rank() over (order by cost_forecast desc)		as dense_rank_ranking	
	
from cost_forecast cf 