use [LW]
select name,type,effectAgainstHelghast from weapons left join 
weaponmastery on
weapontype_id=weaponmastery.id
where effectAgainstHelghast is not NULL and effectAgainstHelghast != 'none'
order by name desc
GO