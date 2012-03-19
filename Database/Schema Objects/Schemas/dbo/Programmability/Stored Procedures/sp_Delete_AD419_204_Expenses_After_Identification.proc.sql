-- =============================================
-- Author:		Ken Taylor
-- Create date: November 17, 2010
-- Description:	New requirement starting 2009-2010: 
-- Delete all 204 expenses after they have been identified as per Steve Pesis.
--
-- Modifications:
--
-- [12/17/2010] by kjt: Revised to use AllExpenses, table (formerly Expenses) instead of new Expenses view.
--
-- =============================================
CREATE PROCEDURE [dbo].[sp_Delete_AD419_204_Expenses_After_Identification]
	-- Add the parameters for the stored procedure here
	@FiscalYear int = 2010, 
	@IsDebug bit = 0
AS
BEGIN
	DECLARE @TSQL varchar(max) = ''
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    -- Insert statements for procedure here
	Select @TSQL = 'IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N''[dbo].[Expenses_204]'') AND type in (N''U''))
	DROP TABLE [dbo].[Expenses_204]
	select * into [AD419].[dbo].[Expenses_204]
	FROM [AD419].[dbo].[Expenses]
	where Exp_SFN = ''204''

	IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N''[dbo].[Associations_204]'') AND type in (N''U''))
	DROP TABLE [dbo].[Associations_204]
	select * into [AD419].[dbo].[Associations_204] from Associations where ExpenseID 
	in (select ExpenseID from Expenses where Exp_SFN = ''204'')

	delete from Associations where ExpenseID 
	in (select ExpenseID from Expenses where Exp_SFN = ''204'')

	delete from AllExpenses where Exp_SFN = ''204''

	IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N''[dbo].[Projects_204]'') AND type in (N''U''))
		BEGIN
			--DROP TABLE [dbo].[Projects_204]
			select * into Projects_204 from AllProjects 
			where Project like ''%-CG%'' or Project like ''%-OG%'' or Project like ''%-SG%''
		END
	ELSE
		BEGIN
		    SET IDENTITY_INSERT [dbo].[Projects_204] ON
			INSERT INTO [dbo].[Projects_204] (
				 [Accession]
				,[Project]
				,[isInterdepartmental]
				,[isValid]
				,[BeginDate]
				,[TermDate]
				,[ProjTypeCd]
				,[RegionalProjNum]
				,[CRIS_DeptID]
				,[CoopDepts]
				,[CSREES_ContractNo]
				,[StatusCd]
				,[Title]
				,[UpdateDate]
				,[inv1]
				,[inv2]
				,[inv3]
				,[inv4]
				,[inv5]
				,[inv6]
				,[idProject]
				,[IsCurrentAD419Project]) 
			SELECT 
				 [Accession]
				,[Project]
				,[isInterdepartmental]
				,[isValid]
				,[BeginDate]
				,[TermDate]
				,[ProjTypeCd]
				,[RegionalProjNum]
				,[CRIS_DeptID]
				,[CoopDepts]
				,[CSREES_ContractNo]
				,[StatusCd]
				,[Title]
				,[UpdateDate]
				,[inv1]
				,[inv2]
				,[inv3]
				,[inv4]
				,[inv5]
				,[inv6]
				,[idProject]
				,[IsCurrentAD419Project] 
			FROM AllProjects
			WHERE Project like ''%-CG%'' or Project like ''%-OG%'' or Project like ''%-SG%''
			SET IDENTITY_INSERT [dbo].[Projects_204] OFF
		END

	delete from AllProjects 
	where Project like ''%-CG%'' or Project like ''%-OG%'' or Project like ''%-SG%''

	truncate table [204AcctXProj]

	delete from FFY_2010_SFN_ENTRIES 
	where SFN like ''204''
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
