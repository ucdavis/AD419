-- =============================================
-- Author:		Ken Taylor
-- Create date: 04-26-2010
-- Description:	Gets the base budget appropriations and FTE sums for the fiscal year provided.
-- Default is to get it for CE, IR, and OR function types, plus Pending transactions.
-- Modifications:
--	20110307 by kjt:
--		Added table name prefix to IsCAES, since it has now been added to Accounts table.
--	20111019 by kjt:
--		Revised to accept multiple OP Fund Numbers.
--	20130424 by kjt:
--		Fixed code to also accept multiple OP funds for FTE as well.
-- 20151009 by kjt: Added OP Fund to select list.
-- =============================================
CREATE PROCEDURE [dbo].[usp_GetBaseBudget] 
	-- Add the parameters for the stored procedure here
	@IncludeAppliedTransactions bit = 1,
	@IncludePendingTransactions bit = 1,
	@IncludeCE bit = 1,
	@IncludeIR bit = 1,
	@IncludeOR bit = 1,
	@IncludeOT bit = 0,
	@IsCAES tinyint = 3, -- 1 AAES without ACBS; 2 ACBS only; 3 AAES and ACBS; 0 BIOS only.
	@FiscalYear int = 2010,
	@SubFundGroups varchar(500) = 'GENFND', -- a comma delimitted list of SubFundGroups, typically just one, i.e., 'GENFND', etc.
	@OpFundNum varchar(500) = '19900' -- a comma delimitted list of OpFundNumbers, typically just one, i.e., '19900', etc.
WITH RECOMPILE
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    -- Insert statements for procedure here
	/****** Script for SelectTopNRows command from SSMS  ******/

--Declare @IncludeAppliedTransactions bit = 1
--Declare @IncludePendingTransactions bit = 1
--Declare @IncludeCE bit = 1
--Declare @IncludeIR bit = 1
--Declare @IncludeOR bit = 1
--Declare @IncludeOT bit = 0
--Declare @IsCAES tinyint = 3
--Declare @FiscalYear int = 2010
--Declare @SubFundGroups varchar(500) = 'GENFND,OTHER'
--Declare @OPFundNum varchar(6) = '19900,69085'


Declare @CE_FunctionCodeID smallint;
Set @CE_FunctionCodeID = (select FunctionCodeID from FISDataMart.dbo.FunctionCode where FunctionCode = 'CE');
Declare @IR_FunctionCodeID smallint;
Set @IR_FunctionCodeID = (select FunctionCodeID from FISDataMart.dbo.FunctionCode where FunctionCode = 'IR');
Declare @OR_FunctionCodeID smallint;
Set @OR_FunctionCodeID = (select FunctionCodeID from FISDataMart.dbo.FunctionCode where FunctionCode = 'OR');
Declare @OT_FunctionCodeID smallint;
Set @OT_FunctionCodeID = (select FunctionCodeID from FISDataMart.dbo.FunctionCode where FunctionCode = 'OT');


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

IF @IncludeOT = 1
BEGIN
	Insert into @MyFunctionCodeIDs(FunctionCodeID) values (@OT_FunctionCodeID);
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

-- New logic to handle ACBS
DECLARE @CAESList TABLE (IsCAES tinyint)
IF @IsCAES = 0
	BEGIN
		-- BIOS only
		Insert into @CAESList (IsCAES) VALUES (0)
	END
IF @IsCAES = 1 OR @IsCAES = 3
	BEGIN
		-- CAES excluding ACBS
		Insert into @CAESList (IsCAES) VALUES (1)
	END
IF @IsCAES = 2 OR @IsCAES = 3
	BEGIN
		-- ACBS only
		Insert into @CAESList (IsCAES) VALUES (2)
	END


DECLARE @MyTable TABLE (Chart varchar(2), OrgID char(4), FunctionCodeID smallint, OpFundNum char(6), [Object] char(4), BaseBudget money, FTE Decimal(14,2) )

INSERT INTO @MyTable(Chart , OrgID, FunctionCodeID, OpFundNum, [Object], BaseBudget)
SELECT 
	 bbv.Chart
	,[OrgID]
	,FunctionCodeID
	,acts.OPFundNum
	,[Object]
    ,SUM([LineAmount])*-1 BaseBudget
FROM [FISDataMart].[dbo].[BaseBudgetV] bbv
  inner join FISDataMart.dbo.Accounts acts on bbv.AccountsFK = acts.AccountPK
where BalType in ('BB','BI') and bbv.Year = @FiscalYear 
--and acts.OPFundNum like '19900'
  AND acts.FunctionCodeID IN (select * from @MyFunctionCodeIDs)
  --and bbv.Chart in ('3', 'L')
  --and IsCAES = 1
  AND bbv.IsCAES IN (Select * from @CAESList)
  AND acts.SubFundGroupNum IN (select * from dbo.SplitVarcharValues(@SubFundGroups))
  --AND acts.OpFundNum LIKE @OpFundNum 
  AND acts.OpFundNum IN (select * from dbo.SplitVarcharValues(@OpFundNum)) 
  and IsPending IN (Select * from @MyIsPendings)
  and bbv.Account in (select account
					  from FISDataMart.dbo.Accounts acts 
					  where bbv.chart = acts.chart AND acts.Year = @FiscalYear AND acts.Period = '--')
group by bbv.Chart, OrgID, FunctionCodeID, acts.OpFundNum, [Object]
  

DECLARE MyCursor CURSOR FOR 
SELECT
	bbv.Chart
	,[OrgID]
	,FunctionCodeID
    ,[Object]
    ,SUM([LineAmount])*-1 FTE
      
FROM [FISDataMart].[dbo].[BaseBudgetV] bbv
  inner join FISDataMart.dbo.Accounts acts on bbv.AccountsFK = acts.AccountPK
where BalType in ('FT','FI') and bbv.Year = @FiscalYear  
--and acts.OPFundNum like '19900' 
  AND FunctionCodeID IN (select * from @MyFunctionCodeIDs)
  --and bbv.Chart in ('3', 'L')
  --and IsCAES = 1
  AND bbv.IsCAES IN (Select * from @CAESList)
  AND acts.SubFundGroupNum IN (select * from dbo.SplitVarcharValues(@SubFundGroups))
  AND acts.OpFundNum IN (select * from dbo.SplitVarcharValues(@OpFundNum)) 
  and IsPending IN (Select * from @MyIsPendings)
  and bbv.Account in (select account
					  from FISDataMart.dbo.Accounts acts 
					  where bbv.chart = acts.chart AND acts.Year = @FiscalYear AND acts.Period = '--')
group by bbv.Chart, OrgID, FunctionCodeID, [Object]
  
OPEN MyCursor
DECLARE @Chart varchar(2), @OrgID char(4), @FunctionCodeID smallint, @Object char(4), @FTE decimal(14,2)
fetch next from MyCursor into @Chart, @OrgID, @FunctionCodeID, @Object, @FTE

while @@FETCH_STATUS <> -1
	begin
		update @MyTable set FTE = @FTE 
		WHERE OrgID = @OrgID and FunctionCodeID = @FunctionCodeID  and [Object] = @Object
		AND Chart = @Chart 

		fetch next from MyCursor into  @Chart, @OrgID, @FunctionCodeID, @Object, @FTE
	end
	
close MyCursor
deallocate MyCursor

Update @MyTable set FTE = 0.00 where FTE is NULL

-- This will need to be modified to accomadate the new org hierarchy
Select  
	CASE WHEN Chart1 = 'L' THEN Org4 
	     WHEN Chart1 = '3' THEN Org3 
	     WHEN Chart6 = 'L' THEN 
		 CASE WHEN @FiscalYear = 2016 THEN Org6 ELSE Org7 END
	     ELSE Org6
	     END AS Org3
	,CASE WHEN Chart1 = 'L' THEN Name4 
	     WHEN Chart1 = '3' THEN Name3 
	     WHEN Chart6 = 'L' THEN 
		 CASE WHEN @FiscalYear = 2016 THEN Name6 ELSE Name7 END
	     ELSE Name6
	     END AS Name3
	,[OrgID] 
	,CASE FunctionCodeID 
		WHEN @CE_FunctionCodeID THEN 'CE'
		WHEN @IR_FunctionCodeID THEN 'IR'
		WHEN @OR_FunctionCodeID THEN 'OR'
	    WHEN @OT_FunctionCodeID THEN 'OT'
		ELSE 'NA'
	  END as FunctionCode
	,OpFundNum
	,[Object]
	,BaseBudget
	,FTE
from @MyTable myTable
	inner join Organizations Orgs
	 ON Org = OrgID AND myTable.Chart = Orgs.Chart AND Year = @FiscalYear and Period = '--'
Where BaseBudget <> 0 
Group by CASE WHEN Chart1 = 'L' THEN Org4 
	     WHEN Chart1 = '3' THEN Org3 
	     WHEN Chart6 = 'L' THEN
		 CASE WHEN @FiscalYear = 2016 THEN Org6 ELSE Org7 END
	     ELSE Org6
	     END 
		,CASE WHEN Chart1 = 'L' THEN Name4 
	     WHEN Chart1 = '3' THEN Name3 
	     WHEN Chart6 = 'L' THEN 
		 CASE WHEN @FiscalYear = 2016 THEN Name6 ELSE Name7 END
	     ELSE Name6
	     END, OrgID, FunctionCodeID, OpFundNum, [Object], BaseBudget,FTE
order by Org3, OrgID, FunctionCode, OpFundNum, [Object], BaseBudget,FTE

END
