-- =============================================
-- Author:		Ken Taylor
-- Create date: 02/26/2010
-- Description:	This sproc updates the ACBS PPS expenses to their 
-- correspending BIOS orgs so that the 241 associations can be made
-- without having to have two orgs for the same purpose, i.e. 'BEVO', 'AEVE', etc.
-- =============================================
CREATE PROCEDURE [dbo].[sp_Set_ACBS_PPS_Expenses_To_BIOS_Orgs] (
	-- Add the parameters for the stored procedure here
	@FiscalYear int = 2009,
	@IsDebug bit = 0
)
AS
BEGIN
	DECLARE @TSQL varchar(max) = ''
	
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	----------------------------------------------------------------------------------------------------------
	
	Select @TSQL = '
	UPDATE 
		[AD419].[dbo].[Expenses]
	SET 
		Org = (CASE Org 
			WHEN ''ACBD'' THEN ''BDNO''  
			WHEN ''AEVE'' THEN ''BEVO''  
			WHEN ''AMCB'' THEN ''BMCO''  
			WHEN ''AMIC'' THEN ''BMIO''  
			WHEN ''ANPB'' THEN ''BNPO''  
			WHEN ''APLB'' THEN ''BPLO'' 
		END),
	OrgR = (CASE OrgR
			WHEN ''ACBD'' THEN ''BSCF''  
			WHEN ''AEVE'' THEN ''BEVE''  
			WHEN ''AMCB'' THEN ''BMCB''  
			WHEN ''AMIC'' THEN ''BMIC''  
			WHEN ''ANPB'' THEN ''BNPB''  
			WHEN ''APLB'' THEN ''BPLB'' 
		END)
	WHERE Org in (''ACBD'', ''AEVE'', ''AMCB'', ''AMIC'', ''ANPB'', ''APLB'')
'
		
	IF @IsDebug = 1
		BEGIN
			Print @TSQL
		END
	ELSE
		BEGIN
			EXEC(@TSQL)
		END

END
