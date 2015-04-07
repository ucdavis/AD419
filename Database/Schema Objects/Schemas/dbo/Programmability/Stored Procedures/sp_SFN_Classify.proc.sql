/*
------------------------------------------------------------------------
PROGRAM: sp_SFN_Classify
BY:	Mike Ransom
USAGE:	execute sp_SFN_Classify

DESCRIPTION: 


CURRENT STATUS:
[9/12/06] Tue
Working correctly

NOTES:
MODIFICATIONS: see bottom
CALLED BY:
	manually
DEPENDENCIES: 
	Run sp_Repopulate_Acct_SFN at beginning of reporting cycle to populate with all the latest FIS accounts.
-------------------------------------------------------------------------
*/
CREATE PROCEDURE [dbo].[sp_SFN_Classify]
	@FiscalYear int = 2009,
	@IsDebug bit = 0
AS
-------------------------------------------------------------------------
DECLARE @txtSQL VarChar(1024)
DECLARE @TSQL varchar(MAX)

print '-- reset (clear) SFN, SFNsCt, SFNs in table Acct_SFN...'
Select @TSQL = 'Update Acct_SFN set SFN=Null, SFNsCt=0, SFNs='''' 
;'
	if @IsDebug = 1
		begin
			Print @TSQL
		end
	else
		begin
			EXEC(@TSQL)
		end

--Federal agency funded:
	--Note: The "official" ruleset from Kevin Koughlin doesn't include any 4061s for anything.  4061 was added last year at Steve Pesis' direction in order to handle some accounts that didn't get classified. I would like to see official blessing of this modification, or have some understanding of what the 4061 (or 2 or 3) represent.
Select @TSQL = 'Execute Classify ''209'', ''left(OpFundGroupCode,4) in (''''4061'''',''''4062'''',''''4063'''') and FederalAgencyCode=''''16'''' '', ' + Convert(char(4), @FiscalYear) + ', ' + CONVERT(char(1), @IsDebug) + ';'	--NSF
	if @IsDebug = 1
		begin
			Print '-- ' + @TSQL
			EXEC(@TSQL)
		end
	else
		begin
			EXEC(@TSQL)
		end
		
Select @TSQL = 'Execute Classify ''310'', ''left(OpFundGroupCode,4) in (''''4061'''',''''4062'''',''''4063'''') and FederalAgencyCode=''''05'''' '', ' + Convert(char(4), @FiscalYear) + ', ' + CONVERT(char(1), @IsDebug) + ';'	--DOE
	if @IsDebug = 1
		begin
			Print '-- ' + @TSQL
			EXEC(@TSQL)
		end
	else
		begin
			EXEC(@TSQL)
		end
Select @TSQL = 'Execute Classify ''308'', ''left(OpFundGroupCode,4) in (''''4061'''',''''4062'''',''''4063'''') and FederalAgencyCode=''''11'''' '', ' + Convert(char(4), @FiscalYear) + ', ' + CONVERT(char(1), @IsDebug) + ';'	--AID
	if @IsDebug = 1
		begin
			Print '-- ' + @TSQL
			EXEC(@TSQL)
		end
	else
		begin
			EXEC(@TSQL)
		end
Select @TSQL = 'Execute Classify ''311'', ''left(OpFundGroupCode,4) in (''''4061'''',''''4062'''',''''4063'''') and FederalAgencyCode=''''03'''' '', ' + Convert(char(4), @FiscalYear) + ', ' + CONVERT(char(1), @IsDebug) + ';'	--DOD
	if @IsDebug = 1
		begin
			Print '-- ' + @TSQL
			EXEC(@TSQL)
		end
	else
		begin
			EXEC(@TSQL)
		end
Select @TSQL = 'Execute Classify ''313'', ''left(OpFundGroupCode,4) in (''''4061'''',''''4062'''',''''4063'''') and FederalAgencyCode=''''06'''' and (left(NIHDocNum,2)<>''''08'''' or NIHDocNum IS NULL)'', ' + Convert(char(4), @FiscalYear) + ', ' + CONVERT(char(1), @IsDebug) + ';'	--HHS
	if @IsDebug = 1
		begin
			Print '-- ' + @TSQL
			EXEC(@TSQL)
		end
	else
		begin
			EXEC(@TSQL)
		end
Select @TSQL = 'Execute Classify ''316'', ''left(OpFundGroupCode,4) in (''''4061'''',''''4062'''',''''4063'''') and FederalAgencyCode=''''06'''' and left(NIHDocNum,2)=''''08'''' '', ' + Convert(char(4), @FiscalYear) + ', ' + CONVERT(char(1), @IsDebug) + ';'	--NIH
	if @IsDebug = 1
		begin
			Print '-- ' + @TSQL
			EXEC(@TSQL)
		end
	else
		begin
			EXEC(@TSQL)
		end
Select @TSQL = 'Execute Classify ''314'', ''left(OpFundGroupCode,4) in (''''4061'''',''''4062'''',''''4063'''') and FederalAgencyCode=''''14'''' '', ' + Convert(char(4), @FiscalYear) + ', ' + CONVERT(char(1), @IsDebug) + ';'	--NASA
	if @IsDebug = 1
		begin
			Print '-- ' + @TSQL
			EXEC(@TSQL)
		end
	else
		begin
			EXEC(@TSQL)
		end
Select @TSQL = 'Execute Classify ''318'', ''left(OpFundGroupCode,4) in (''''4061'''',''''4062'''',''''4063'''') AND  (FederalAgencyCode NOT IN (''''01'''',''''03'''',''''05'''',''''06'''',''''11'''',''''14'''',''''16'''') OR FederalAgencyCode IS NULL)'', ' + Convert(char(4), @FiscalYear) + ', ' + CONVERT(char(1), @IsDebug) + ';'
	if @IsDebug = 1
		begin
			Print '-- ' + @TSQL
			EXEC(@TSQL)
		end
	else
		begin
			EXEC(@TSQL)
		end
--Modification to include USFS:
Select @TSQL = 'Execute Classify ''318'', ''left(OpFundGroupCode,4) in (''''4061'''',''''4062'''',''''4063'''') AND  (FederalAgencyCode = ''''01'''') and (SponsorCode = ''''0300'''') '', ' + Convert(char(4), @FiscalYear) + ', ' + CONVERT(char(1), @IsDebug) + ';' --USFS
	--Federal, Other
		if @IsDebug = 1
		begin
			Print '-- ' + @TSQL
			EXEC(@TSQL)
		end
	else
		begin
			EXEC(@TSQL)
		end

--State Appropriations:
Select @TSQL = 'Execute Classify ''220'', ''(OpFundGroupCode LIKE ''''401%'''') OR (OpFundGroupCode LIKE ''''404%'''' AND (NOT SponsorCategoryCode LIKE ''''12'''' OR SponsorCategoryCode IS NULL))'', ' + Convert(char(4), @FiscalYear) + ', ' + CONVERT(char(1), @IsDebug) + ';'
	--401 = 19900 General, 404 = Special State, Stage Agency
	if @IsDebug = 1
		begin
			Print '-- ' + @TSQL
			EXEC(@TSQL)
		end
	else
		begin
			EXEC(@TSQL)
		end
Select @TSQL = 'Execute Classify ''221'', ''left(OpFundGroupCode,3) in (''''409'''')'', ' + Convert(char(4), @FiscalYear) + ', ' + CONVERT(char(1), @IsDebug) + ';'	-- Self-generated

	if @IsDebug = 1
		begin
			Print '-- ' + @TSQL
			EXEC(@TSQL)
		end
	else
		begin
			EXEC(@TSQL)
		end
Select @TSQL = 'Execute Classify ''222A'', ''left(OpFundGroupCode,3) in (''''408'''') and (SponsorCategoryCode not in (''''05'''',''''12'''') OR SponsorCategoryCode IS NULL)'', ' + Convert(char(4), @FiscalYear) + ', ' + CONVERT(char(1), @IsDebug) + ';'	--Gifts
	if @IsDebug = 1
		begin
			Print '-- ' + @TSQL
			EXEC(@TSQL)
		end
	else
		begin
			EXEC(@TSQL)
		end
Select @TSQL = 'Execute Classify ''222B'',  ''OpFundGroupCode LIKE ''''407%'''' '', ' + Convert(char(4), @FiscalYear) + ', ' + CONVERT(char(1), @IsDebug) + ';'	--Endowments
	if @IsDebug = 1
		begin
			Print '-- ' + @TSQL
			EXEC(@TSQL)
		end
	else
		begin
			EXEC(@TSQL)
		end

Select @txtSQL = '''(OpFundGroupCode LIKE ''''4042%'''' and SponsorCategoryCode LIKE ''''12'''') '	--commodities
Select @txtSQL = @txtSQL + 'OR (OpFundGroupCode LIKE ''''408%'''' and SponsorCategoryCode in (''''05'''',''''12''''))'''		--more commodities
Select @TSQL = 'Execute Classify ''222C'',' + @txtSQL + ', ' + Convert(char(4), @FiscalYear) + ', ' + CONVERT(char(1), @IsDebug) + ';'
if @IsDebug = 1
		begin
			Print '-- ' + @TSQL
			EXEC(@TSQL)
		end
	else
		begin
			EXEC(@TSQL)
		end

Select @TSQL = 'Execute Classify ''223A'', ''OpFundGroupCode like ''''405%'''' '', ' + Convert(char(4), @FiscalYear) + ', ' + CONVERT(char(1), @IsDebug) + ';'
if @IsDebug = 1
		begin
			Print '-- ' + @TSQL
			EXEC(@TSQL)
		end
	else
		begin
			EXEC(@TSQL)
		end
Select @TSQL = 'Execute Classify ''223C'', ''OpFundGroupCode LIKE ''''4%'''' AND left(OpFundGroupCode,3) in (''''402'''',''''403'''',''''410'''',''''411'''')'', ' + Convert(char(4), @FiscalYear) + ', ' + CONVERT(char(1), @IsDebug) + ';'
	--[4/13/05] Note: K. Coughlin's spec on 223c is not definitive. It states "NE everything defined above" but doesn't define "above".  He gave 409 & 410 as examples, but 402, 403 are also not defined above.  Nor does he ever specify that we're only concerned with 4xx codes. A tally of all "OpFundGp3" values confirms they all start with 4, except for just a couple here and there that suggest a mis-coding.
	--[4/14/05] Note: KC's rules spreadsheet gives OP Fundgroup 409% as an example of 223C, but 409% is clearly defined "above" as SFN 221.  Took 409 out of the 223C list.

-- SFN 219: USDA Contracts, Grants, & Cooperative Agreements:
if @IsDebug = 1
		begin
			Print '-- ' + @TSQL
			EXEC(@TSQL)
		end
	else
		begin
			EXEC(@TSQL)
		end
Select @TSQL = 'Execute Classify ''219'', ''left(OpFundGroupCode,4) in (''''4061'''',''''4062'''',''''4063'''') and FederalAgencyCode=''''01'''' and (SponsorCode NOT IN (''''0300'''',''''0450'''',''''0334'''') OR SponsorCode IS NULL)'', ' + Convert(char(4), @FiscalYear) + ', ' + CONVERT(char(1), @IsDebug) + ';'
-- Second level 219 classification to pick up possible 204-related expenses (if they really are 204s, they will match later)
if @IsDebug = 1
		begin
			Print '-- ' + @TSQL
			EXEC(@TSQL)
		end
	else
		begin
			EXEC(@TSQL)
		end
Select @TSQL = 'Execute Classify ''219'', ''left(OpFundGroupCode,4) in (''''4061'''',''''4062'''',''''4063'''') and FederalAgencyCode=''''01'''' and SponsorCode in (''''0450'''',''''0334'''')'', ' + Convert(char(4), @FiscalYear) + ', ' + CONVERT(char(1), @IsDebug) + ';'
	--[9/12/06] mlr: last year, this followed the CSREES, moved above CSREES today after discussion with S. Pesis regarding 4 accounts which also met 205 criteria.

-- CSREES-administered, federally-funded:
	-- Note: The classification is order-dependent here in many cases.  A large number of these also fit the criteria for "other" Federderal_Agency_code "XX" funding sources (SFN 318), but the OpFundNum values below indicate they are CSREES-administered funds, so they need the SFN 2xx classifications.

--USDA Contracts Grants Co-Op Agreements (not CSREES-administered)
	--Note: some of these will have already met the criteria
if @IsDebug = 1
		begin
			Print '-- ' + @TSQL
			EXEC(@TSQL)
		end
	else
		begin
			EXEC(@TSQL)
		end
Select @TSQL = 'Execute Classify ''201'', ''left(OpFundNum,5) in (''''21005'''',''''21006'''',''''21009'''',''''21010'''')'', ' + Convert(char(4), @FiscalYear) + ', ' + CONVERT(char(1), @IsDebug) + ';'
if @IsDebug = 1
		begin
			Print '-- ' + @TSQL
			EXEC(@TSQL)
		end
	else
		begin
			EXEC(@TSQL)
		end
Select @TSQL = 'Execute Classify ''202'', ''left(OpFundNum,5) in (''''21013'''',''''21014'''',''''21015'''',''''21016'''')'', ' + Convert(char(4), @FiscalYear) + ', ' + CONVERT(char(1), @IsDebug) + ';'
if @IsDebug = 1
		begin
			Print '-- ' + @TSQL
			EXEC(@TSQL)
		end
	else
		begin
			EXEC(@TSQL)
		end
Select @TSQL = 'Execute Classify ''203'', ''left(OpFundNum,5) in (''''21007'''',''''21008'''')'', ' + Convert(char(4), @FiscalYear) + ', ' + CONVERT(char(1), @IsDebug) + ';'
--Execute Classify '204', 'left(OpFundGroupCode,4) in (''4061'',''4062'',''4063'') and FederalAgencyCode=''01'' and SponsorCode in (''0450'',''0334'')'
	if @IsDebug = 1
		begin
			Print '-- ' + @TSQL
			EXEC(@TSQL)
		end
	else
		begin
			EXEC(@TSQL)
		end
-- [9/10/2009] by KJT: Modified below to use new FISDataMart.dbo.OpFundNumbers
Select @TSQL = 'Execute Classify ''204'', ''left(OpFundGroupCode,4) in (''''4061'''',''''4062'''',''''4063'''') and FederalAgencyCode=''''01'''' and SponsorCode in (''''0450'''',''''0334'''') 
		AND [OpFundNum] in (
				SELECT OPFundNum FROM [FISDataMart].[dbo].[OPFundNumbers] where Name like ''''%USDA%CSREES%'''' OR Name like ''''%USDA%NIFA%''''
				OR Name like ''''%USDA%-%-%'''' OR Name like ''''%NATIONAL INSTITUTE FOR%-%-%'''' OR Name like ''''%-%-%''''
				
			) 
		AND left(OpFundNum,5) not in (''''21003'''',''''21004'''',''''21005'''',''''21006'''',''''21007'''',''''21008'''',''''21009'''',''''21010'''', ''''21013'''',''''21014'''',''''21015'''',''''21016'''')	
		AND (AwardNum like ''''%-%-%'''' AND (AwardNum not like ''''SA%'''' AND AwardNum not like ''''%SA''''))'', ' + Convert(char(4), @FiscalYear) + ', ' + CONVERT(char(1), @IsDebug) + '
			;'
	if @IsDebug = 1
		begin
			Print '/*' + @TSQL + '*/'
			EXEC(@TSQL)
		end
	else
		begin
			EXEC(@TSQL)
		end
		
Select @TSQL = 'Execute Classify ''205'', ''left(OpFundNum,5) in (''''21003'''',''''21004'''')'', ' + Convert(char(4), @FiscalYear) + ', ' + CONVERT(char(1), @IsDebug) + ';'
	if @IsDebug = 1
		begin
			Print '-- ' + @TSQL
			EXEC(@TSQL)
		end
	else
		begin
			EXEC(@TSQL)
		end

-------------------------------------------------------------------------
/*
MODIFICATIONS:

[9/9/05] Fri: 
	--Rules for 204s and 219s were wrong, mistakenly used SponsorCategoryCode rather then SponsorCode. Result was that nothing was classified as 204.  204s probably all got classified as 219s.  Modify and re-run...  
	--New rule for 318 explicitly excludes USFS from 318, leaving it unclassified. I think this is a mistake and have added a line to catch that exception to the exclusion
[9/9/05] Fri: 
	Rules for 204s and 219s were wrong, mistakenly used SponsorCategoryCode rather then SponsorCode. Result was that nothing was classified as 204.  204s probably all got classified as 219s.  Modify and re-run...  
	--New rule for 318 explicitly excludes USFS from 318, leaving it unclassified. I think this is a mistake and have added a line to catch that exception to the exclusion

[9/12/06] Tue
	modified to move 219s above CSREES (give CSREES lines precidence)
	
[9/10/2009] by KJT:
	Modified to use new [FISDataMart].[dbo].[OPFundNumbers].

[3/23/2015] by KJT:
	REvised to also include 204 accounts baginning with "NATIONAL INSTITUTE FOR".

*/
