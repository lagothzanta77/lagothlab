use [LW]
select * from weapons inner join 
weaponmastery on
weapontype_id=weaponmastery.id
where effectAgainstHelghast != 'none'
order by name desc
GO
