select 
	r.date
	,s.first_name
	,s.last_name
	,s.hourly_rate 
	,sh.start_time
	,sh.end_time
from rota r
left join staff s on s.staff_id = r.staff_id
left join shift sh on sh.shift_id = r.shift_id