
CREATE PROCEDURE [dbo].[Step13]
AS
BEGIN
INSERT INTO Organizations
	SELECT 
	  O.[Year]
      ,'--' [Period]
      ,O.[Org]
      ,O.[Chart]
      ,[Level]
      ,[Name]
      ,[Type]
      ,[BeginDate]
      ,[EndDate]
      ,[HomeDeptNum]
      ,[HomeDeptName]
      ,[UpdateDate]
      ,[Chart1]
      ,[Org1]
      ,[Name1]
      ,[Chart2]
      ,[Org2]
      ,[Name2]
      ,[Chart3]
      ,[Org3]
      ,[Name3]
      ,[Chart4]
      ,[Org4]
      ,[Name4]
      ,[Chart5]
      ,[Org5]
      ,[Name5]
      ,[Chart6]
      ,[Org6]
      ,[Name6]
      ,[Chart7]
      ,[Org7]
      ,[Name7]
      ,[Chart8]
      ,[Org8]
      ,[Name8]
      ,[Chart9]
      ,[Org9]
      ,[Name9]
      ,[Chart10]
      ,[Org10]
      ,[Name10]
      ,[Chart11]
      ,[Org11]
      ,[Name11]
      ,[Chart12]
      ,[Org12]
      ,[Name12]
      ,[ActiveIndicator]
      ,CONVERT(char(4), O.Year) + '|' + '--' + '|' + RTRIM(O.Chart)  + '|' + O.Org AS [OrganizationPK]
      ,CONVERT(smalldatetime, GETDATE(), 120) AS [LastUpdateDate]
	FROM Organizations O
	INNER JOIN
	(
		select Year, MAX(Period) Period, Chart, Org
		FROM Organizations
		WHERE
			CONVERT(char(4), Year) + '|' + '--' + '|' + RTRIM(Chart)  + '|' + Org
			NOT IN 
			(
				SELECT OrganizationPK 
				FROM Organizations
				WHERE Period = '--'
			)
		group by year, chart, org
	)  OIG ON O.Year = OIG.Year AND O.Period = OIG.Period AND O.Chart = OIG.Chart AND O.Org = OIG.Org
END