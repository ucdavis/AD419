-- =============================================
-- Author:		Ken Taylor
-- Create date: 04-06-2010
-- Description:	Gets the base budget appropriations and FTE sums for the fiscal year provided.
-- Default is to get it for CE, IR, and OR function types, plus Pending transactions.
-- =============================================
CREATE PROCEDURE [dbo].[usp_GetBaseBudget_no_sums]
	-- Add the parameters for the stored procedure here
	@IncludeAppliedTransactions bit = 1,
	@IncludePendingTransactions bit = 1,
	@IncludeCE bit = 1,
	@IncludeIR bit = 1,
	@IncludeOR bit = 1,
	@FiscalYear int = 2010
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    -- Insert statements for procedure here
	/****** Script for SelectTopNRows command from SSMS  ******/
/*
Declare @IncludePendingTransactions bit = 1
Declare @IncludeCE bit = 1
Declare @IncludeIR bit = 1
Declare @IncludeOR bit = 1
Declare @FiscalYear int = 2010
*/

Declare @CE_FunctionCodeID smallint;
Set @CE_FunctionCodeID = (select FunctionCodeID from FISDataMart.dbo.FunctionCode where FunctionCode = 'CE');
Declare @IR_FunctionCodeID smallint;
Set @IR_FunctionCodeID = (select FunctionCodeID from FISDataMart.dbo.FunctionCode where FunctionCode = 'IR');
Declare @OR_FunctionCodeID smallint;
Set @OR_FunctionCodeID = (select FunctionCodeID from FISDataMart.dbo.FunctionCode where FunctionCode = 'OR');

DECLARE @MyFunctionCodeIDs TABLE (FunctionCodeID smallint)

IF @IncludeCE = 1
BEGIN
	Insert into @MyFunctionCodeIDs(FunctionCodeID) values (@CE_FunctionCodeID);
END

IF @IncludeIR = 1
BEGIN
	Insert into @MyFunctionCodeIDs(FunctionCodeID) values (@IR_FunctionCodeID);
END

IF @IncludeOR = 1
BEGIN
	Insert into @MyFunctionCodeIDs(FunctionCodeID) values (@OR_FunctionCodeID);
END


DECLARE @MyIsPendings TABLE (IsPending bit)
IF @IncludeAppliedTransactions = 1
BEGIN
	Insert into @MyIsPendings (IsPending) VALUES ('0')
END
IF @IncludePendingTransactions = 1
BEGIN
	Insert into @MyIsPendings (IsPending) VALUES ('1')
END


DECLARE @MyTable TABLE (OrgID char(4), FunctionCodeID smallint, [Object] char(4), BaseBudget money, FTE Decimal(14,2) )

INSERT INTO @MyTable(OrgID, FunctionCodeID, [Object], BaseBudget)
SELECT [OrgID],
FunctionCodeID
,obj.[Object],
    
      [LineAmount]*-1 BaseBudget
     
      
  FROM [FISDataMart].[dbo].[BaseBudgetV] bbv
  inner join FISDataMart.dbo.Accounts acts on bbv.AccountsFK = acts.AccountPK
  inner join FISDataMart.dbo.Objects obj on bbv.ObjectsFK = obj.ObjectPK
  where BalType in ('BB','BI') and bbv.Year = @FiscalYear --and acts.OPFundNum like '19900%'
  AND acts.FunctionCodeID IN (select * from @MyFunctionCodeIDs)
  --and bbv.Chart in ('3', 'L')
  and bbv.IsCAES = 1
  and IsPending IN (Select * from @MyIsPendings)
  
  group by OrgID, FUnctionCOdeID, obj.[Object],[LineAmount]
  

DECLARE MyCursor CURSOR FOR SELECT  [OrgID] ,
FunctionCodeID
    ,obj.[Object]
      ,[LineAmount]*-1 FTE
      
  FROM [FISDataMart].[dbo].[BaseBudgetV] bbv
  inner join FISDataMart.dbo.Accounts acts on bbv.AccountsFK = acts.AccountPK
  inner join FISDataMart.dbo.Objects obj on bbv.ObjectsFK = obj.ObjectPK
  where BalType in ('FT','FI') and bbv.Year = @FiscalYear  --and acts.OPFundNum like '19900%' 
  
  AND FunctionCodeID IN (select * from @MyFunctionCodeIDs)
  
  --and bbv.Chart in ('3', 'L')
  and bbv.IsCAES = 1
  and IsPending IN (Select * from @MyIsPendings)
  group by OrgID, FunctionCodeID, obj.[Object],[LineAmount]
  
OPEN MyCursor
DECLARE @OrgID char(4), @FunctionCodeID smallint, @Object char(4), @FTE decimal(14,2)
fetch next from MyCursor into @OrgID, @FunctionCodeID, @Object, @FTE
while @@FETCH_STATUS <> -1
	begin
		update @MyTable set FTE = @FTE WHERE OrgID = @OrgID and FunctionCodeID = @FunctionCodeID  and [Object] = @Object
	
		fetch next from MyCursor into @OrgID, @FunctionCodeID, @Object, @FTE
	end
	
close MyCursor
deallocate MyCursor

Update @MyTable set FTE = 0.00 where FTE is NULL

Select   
/*CASE [OrgID] WHEN 'ADCE' THEN 'APLS'
WHEN 'LAWR' THEN 'ALAW' 
WHEN 'CDAA' THEN 'AHCD'
WHEN 'ENRS' THEN 'AENT'
WHEN 'ET19' THEN 'ATEX'
WHEN 'HDAA' THEN 'AHCH'
WHEN 'NDEP' THEN 'ANEM'
WHEN 'PDEP' THEN 'APPA'
WHEN 'SUST' THEN 'ACTR'
WHEN 'XE21' THEN 'ADES'  
ELSE [OrgID] END 
AS */
[OrgID], 
CASE FunctionCodeID WHEN @CE_FunctionCodeID THEN 'CE'
WHEN @IR_FunctionCodeID THEN 'IR'
WHEN @OR_FunctionCodeID THEN 'OR'
ELSE 'OT'
END as FunctionCode
--, [Object], SUM(BaseBudget) as BaseBudget, SUM(FTE) as FTE from @MyTable 
, [Object], BaseBudget, FTE from @MyTable 
Where BaseBudget <> 0
Group by OrgID, FunctionCodeID, [Object], BaseBudget,FTE
order by OrgID, FunctionCodeID, [Object], BaseBudget,FTE

END
