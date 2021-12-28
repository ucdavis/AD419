
CREATE PROCEDURE [dbo].[Step7]
AS
BEGIN
merge SubAccounts as SubAccounts
	using
	(
		SELECT 
			Fiscal_Year,
			Fiscal_Period,
			Chart_Num,
			Account_Num,
			SubAccount_Num,
			SubAccount_Name,
			Active_Ind,
			Last_Update_Date,
			Sub_Account_PK
		FROM
			OPENQUERY (
				FIS_DS,
				'SELECT  
					SA.FISCAL_YEAR			Fiscal_Year,
					SA.FISCAL_PERIOD		Fiscal_Period,
					SA.CHART_NUM			Chart_Num, 
					SA.ACCT_NUM				Account_Num, 
					SA.SUB_ACCT_NUM			SubAccount_Num, 
					SA.SUB_ACCT_NAME		SubAccount_Name, 
					SA.SUB_ACCT_ACTIVE_IND	Active_Ind,
					SA.DS_LAST_UPDATE_DATE	Last_Update_Date,
					SA.FISCAL_YEAR || ''|'' || SA.FISCAL_PERIOD || ''|'' || SA.CHART_NUM || ''|'' || SA.ACCT_NUM  || ''|'' || SA.SUB_ACCT_NUM as Sub_Account_PK
				FROM 
					FINANCE.SUB_ACCOUNT SA
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
											(CHART_NUM_LEVEL_4 = ''3'' AND ORG_ID_LEVEL_4 = ''AAES'')
											OR
											(CHART_NUM_LEVEL_5 = ''L'' AND ORG_ID_LEVEL_5 = ''AAES'')
									
											OR
											(ORG_ID_LEVEL_4 = ''BIOS'')
										)
								)
							)
					) A ON SA.CHART_NUM = A.CHART_NUM AND SA.ACCT_NUM = A.ACCT_NUM
				WHERE 
					(
						SA.FISCAL_YEAR >= 2011
					)
				--ORDER BY SA.FISCAL_YEAR, SA.FISCAL_PERIOD, SA.CHART_NUM, SA.ACCT_NUM, SA.SUB_ACCT_NUM
		')
	) FIS_DS_SUB_ACCOUNT ON SubAccounts.SubAccountPK = FIS_DS_SUB_ACCOUNT.Sub_Account_PK

	WHEN MATCHED THEN UPDATE set
	   [SubAccountName] = SubAccount_Name
      ,[ActiveInd] = Active_Ind
      ,[LastUpdateDate] = Last_Update_Date

	WHEN NOT MATCHED BY TARGET THEN INSERT VALUES 
		(Fiscal_Year,
		Fiscal_Period,
		Chart_Num,
		Account_Num,
		SubAccount_Num,
		SubAccount_Name,
		Active_Ind,
		Last_Update_Date,
		Sub_Account_PK
	)

	--WHEN NOT MATCHED BY SOURCE THEN DELETE
	;
END