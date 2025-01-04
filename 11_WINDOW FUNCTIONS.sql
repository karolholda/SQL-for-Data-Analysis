select 
	cost_forecast_id
	,cost_forecast
	,row_number() over (order by cost_forecast desc)		as row_number_ranking
	,rank() over (order by cost_forecast desc)				as rank_ranking
	,dense_rank() over (order by cost_forecast desc)		as dense_rank_ranking
from cost_forecast cf 