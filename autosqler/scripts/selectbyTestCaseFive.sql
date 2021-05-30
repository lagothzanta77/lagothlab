use [LW]
select name,type,effectAgainstHelghast from weapons inner join 
weaponmastery on
weapontype_id=weaponmastery.id
where effectAgainstHelghast != 'none'
GO
