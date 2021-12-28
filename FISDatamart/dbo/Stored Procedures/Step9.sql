
CREATE PROCEDURE [dbo].[Step9]
AS
BEGIN
merge SubObjects as SubObjects
	using
	(
		SELECT 
			Fiscal_Year,
			Fiscal_Period,
			Chart_Num,
			Account_Num,
			[Object],
			SubObject,
			SubObject_Name,
			SubObject_Name_Short,
			SubObject_Active_Ind,
			Last_Update_Date,
			Sub_Object_PK
		FROM
			OPENQUERY (
				FIS_DS,
				'SELECT 
					SO.FISCAL_YEAR Fiscal_Year,
					SO.FISCAL_PERIOD Fiscal_Period,
					SO.CHART_NUM Chart_Num,
					SO.ACCT_NUM Account_Num,
					SO.OBJECT_NUM Object,
					SO.SUB_OBJECT_NUM SubObject,
					SO.SUB_OBJECT_NAME SubObject_Name,
					SO.SUB_OBJECT_SHORT_NAME SubObject_Name_Short,
					SO.SUB_OBJECT_ACTIVE_IND SubObject_Active_Ind,
					SO.DS_LAST_UPDATE_DATE Last_Update_Date,
					SO.FISCAL_YEAR || ''|'' || SO.FISCAL_PERIOD || ''|'' || SO.CHART_NUM || ''|'' || SO.ACCT_NUM || ''|'' || SO.OBJECT_NUM  || ''|'' || SO.SUB_OBJECT_NUM as Sub_Object_PK
				FROM 
					FINANCE.SUB_OBJECT SO
					INNER JOIN 
					(
						SELECT DISTINCT CHART_NUM, ACCT_NUM
						FROM FINANCE.ORGANIZATION_ACCOUNT
						WHERE 
							(
								(
									FISCAL_YEAR >= 2011
								)
								AND 
								(CHART_NUM, ORG_ID) IN 
								(	
									SELECT DISTINCT CHART_NUM, ORG_ID 
									FROM FINANCE.ORGANIZATION_HIERARCHY Org 
									WHERE
										FISCAL_YEAR >= 2011 
										AND
										(
											(CHART_NUM_LEVEL_1 = ''3'' AND ORG_ID_LEVEL_1 = ''AAES'')
											OR
											(CHART_NUM_LEVEL_2 = ''L'' AND ORG_ID_LEVEL_2 = ''AAES'')
									
											OR
											(ORG_ID_LEVEL_1 = ''BIOS'')
							
											OR 
											(CHART_NUM_LEVEL_4 = ''3'' AND ORG_ID_LEVEL_4  = ''AAES'')
											OR
											(CHART_NUM_LEVEL_5 = ''L'' AND ORG_ID_LEVEL_5 = ''AAES'')
							
									
											OR
											(ORG_ID_LEVEL_4 = ''BIOS'')
										)
								)
							)
					
					) ACCT ON SO.CHART_NUM = ACCT.CHART_NUM AND SO.ACCT_NUM = ACCT.ACCT_NUM
					
				WHERE 
					(
						(
							SO.FISCAL_YEAR >= 2011
						)
					)
	')
	) FIS_DS_SUB_OBJECT ON SubObjects.SubObjectPK = FIS_DS_SUB_OBJECT.Sub_Object_PK

	WHEN MATCHED THEN UPDATE set
	   [Name] = SubObject_Name
      ,[ShortName] = SubObject_Name_Short
      ,[ActiveInd] = SubObject_Active_Ind
      ,[LastUpdateDate] = Last_Update_Date
	
	WHEN NOT MATCHED BY TARGET THEN INSERT VALUES 
	(
		Fiscal_Year,
		Fiscal_Period,
		Chart_Num,
		Account_Num,
		Object,
		SubObject,
		SubObject_Name,
		SubObject_Name_Short,
		SubObject_Active_Ind,
		Last_Update_Date,
		Sub_Object_PK
	)
	--WHEN NOT MATCHED BY SOURCE THEN DELETE
;
END