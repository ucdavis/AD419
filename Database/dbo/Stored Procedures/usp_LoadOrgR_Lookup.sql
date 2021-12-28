

-- =============================================
-- Author:		Ken Taylor
-- Create date: August 26, 2019 
-- Description:	Load the OrgR_Lookup table.
-- 
--
-- Prerequisites:
--	AnotherLaborTransactions and AnotherLaborTransactions_Sept2019 (if applicable)
--  must have already been loaded.
--
-- Usage:
/*
	USE AD419 
	GO

	EXEC usp_LoadOrgR_Lookup

	GO
*/
-- Modifications:
--	20201019 by kjt: Revised to use AnotherLaborTransactions as
--		all labor data is now present in AnotherLaborTransactions.  This
--		required modifying FIN_COA_CD to Chart and ORG_CD to Org field
--		names as necessary.
--
-- =============================================
CREATE PROCEDURE [dbo].[usp_LoadOrgR_Lookup] 
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	DECLARE @Table TABLE (Chart varchar(2), OrgCd varchar(4), Org1 varchar(4), OrgR varchar(4) )
	DECLARE @Table2 TABLE (Chart varchar(2), OrgCd varchar(4), Org1 varchar(4), OrgR varchar(4) )

	INSERT INTO @Table
	SELECT DISTINCT 
		  Chart,
		  Org,
		  ORG_ID_LEVEL_4 AS ORG_1,
		  CASE Chart WHEN '3' THEN
			CASE ORG_ID_LEVEL_4  
				WHEN 'AAES' THEN ORG_ID_LEVEL_6
				WHEN '2400' THEN ORG_ID_LEVEL_6
				WHEN 'GSM1' THEN COALESCE(ORG_ID_LEVEL_6, ORG_ID_LEVEL_5)
			ELSE COALESCE (ORG_ID_LEVEL_5, ORG_ID_LEVEL_4)
			END
		  WHEN  'L' THEN
			CASE ORG_ID_LEVEL_4 
				WHEN 'AAES' THEN ORG_ID_LEVEL_6
				WHEN '2400' THEN ORG_ID_LEVEL_6
				WHEN 'GSM1' THEN COALESCE(ORG_ID_LEVEL_6, ORG_ID_LEVEL_5)
				ELSE  COALESCE (ORG_ID_LEVEL_5, ORG_ID_LEVEL_4)
			END 
		END AS ORG_R
	FROM [dbo].[AnotherLaborTransactions] t1
	LEFT OUTER JOIN (
	SELECT * FROM OPENQUERY(FIS_DS,'
			SELECT CHART_NUM, ORG_ID, ORG_ID_LEVEL_4, ORG_ID_LEVEL_5, ORG_ID_LEVEL_6
			FROM FINANCE.ORGANIZATION_HIERARCHY 
			WHERE (FISCAL_YEAR IN (9999) AND FISCAL_PERIOD = ''--'' AND ACTIVE_IND = ''Y''
			)
		')
	  ) t2 ON t1.Chart = t2.CHART_NUM AND t1.Org = t2.ORG_ID
	  ORDER BY Chart, Org_R, Org
 
	  INSERT INTO @Table2
	  SELECT DISTINCT 
		  Chart,
		  Org,
		  ORG_ID_LEVEL_4 AS ORG_1,
		  CASE Chart WHEN '3' THEN
			CASE ORG_ID_LEVEL_4  
				WHEN 'AAES' THEN ORG_ID_LEVEL_6
				WHEN '2400' THEN ORG_ID_LEVEL_6
				WHEN 'GSM1' THEN COALESCE(ORG_ID_LEVEL_6, ORG_ID_LEVEL_5)
			ELSE  COALESCE (ORG_ID_LEVEL_5, ORG_ID_LEVEL_4)
			END
		  WHEN  'L' THEN
			CASE ORG_ID_LEVEL_4 
				WHEN 'AAES' THEN ORG_ID_LEVEL_6
				WHEN '2400' THEN ORG_ID_LEVEL_6
				WHEN 'GSM1' THEN COALESCE(ORG_ID_LEVEL_6, ORG_ID_LEVEL_5)
				ELSE  COALESCE (ORG_ID_LEVEL_5, ORG_ID_LEVEL_4)
			END 
		END AS ORG_R
	  FROM [dbo].[AnotherLaborTransactions] t1
	  LEFT OUTER JOIN (
		SELECT * FROM OPENQUERY(FIS_DS,'
			SELECT CHART_NUM, ORG_ID, ORG_ID_LEVEL_4, ORG_ID_LEVEL_5, ORG_ID_LEVEL_6
			FROM FINANCE.ORGANIZATION_HIERARCHY 
			WHERE (FISCAL_YEAR IN (9999) AND FISCAL_PERIOD = ''--'' AND ACTIVE_IND = ''N''
			)
		')
	) t2 ON t1.Chart = t2.CHART_NUM AND t1.Org = t2.ORG_ID

	UPDATE @Table
	SET Org1 = t2.Org1, OrgR = t2.OrgR
	FROM @Table t1
	INNER JOIN @Table2 t2 ON t1.Chart = t2.Chart AND t1.OrgCd = t2.OrgCd
	WHERE t1.Org1 IS NULL

	TRUNCATE TABLE AD419.dbo.OrgR_Lookup
	
	INSERT INTO AD419.dbo.OrgR_Lookup
	SELECT Chart, Org1, OrgR, OrgCd
	FROM @Table

END