USE [LW]
GO
SELECT [name],[type],effectAgainstHelghast FROM weapons LEFT JOIN  
weaponmastery ON weapontype_id=weaponmastery.id
WHERE effectAgainstHelghast IS NOT NULL AND effectAgainstHelghast != 'none'
ORDER BY 1 ASC
GO
