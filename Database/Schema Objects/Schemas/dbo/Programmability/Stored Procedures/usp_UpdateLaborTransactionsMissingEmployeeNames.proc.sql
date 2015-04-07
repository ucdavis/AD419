-- =============================================
-- Author:		Ken Taylor
-- Create date: November 16, 2012
-- Description:	Update the LaborTransactions table's missing employee names where they
--	were not found in the FINANCE.UCD_PERSON table.
-- Modifications:
-- 2013-11-13 by kjt: Added apostrophe replacement for names like O'Malley, etc.
-- 2015-02-19 by kjt: Removed [AD419] specific database references so sproc could be used on other databases
-- such as AD419_2014, etc.
-- =============================================
CREATE PROCEDURE [dbo].[usp_UpdateLaborTransactionsMissingEmployeeNames] 
	@IsDebug bit = 0 -- Set to 1 to print generated SQL only
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

 /*
Needed because the FINANCE.UCD_PERSON is missing names and a left outer join must be used in order to insert all of the pertainent records.
Therefore, this update must be performed to populate the missing TOE_Name fields as applicable.
*/

-- Print a list of employee IDs with whose records have NULL employee names prior to updates:
select distinct EID EIDs_with_Missing_Names
FROM dbo.LaborTransactions
WHERE TOE_NAME IS NUll
/*
EID
001216241
005419957
006762777
007203284
028661452
032150617
040795692
094002748
095076238
101208163
103981635
104252614
119927911
166402925
185953726
193617909
197335425
198684441
248648354
266554617
282474162
300349446
305750986
325660249
341293900
341453074
367712148
398013631
409820404
411496888
415509082
443424841
451881692
454046525
457845642
467013983
479948051
480225077
513307850
533907945
544744022
554940825
572758084
577870546
607105673
607862224
608302808
632970786
637981119
642400659
642818850
669884975
674459367
677469769
695727750
698606761
705164416
725599617
729589416
741267983
750358053
753984186
756214367
757407432
763735586
764115671
773660576
806308425
808194641
809402662
823987250
828311837
828629022
846756971
871368759
873935902
908067994
909779589
920032414
921105672
946849882
947412243
963944053
993141662
*/

--DECLARE @IsDebug bit = 0 -- Set to 1 to print generated SQL only:
DECLARE @RecordsUpdatedCount int = 0

DECLARE @MyCount int = 0 -- variable to hold rows updated per employee

DECLARE MyCursor CURSOR FOR SELECT DISTINCT P.FullName AS TOE_NAME, EID 
FROM PPSDataMart.dbo.Persons P
INNER JOIN dbo.LaborTransactions LT ON P.EmployeeID = LT.EID
WHERE LT.TOE_NAME IS NULL
ORDER BY P.FullName

DECLARE @TOE_NAME varchar(255), @EID varchar(9)
DECLARE @TSQL nvarchar(MAX) = ''
OPEN MyCursor
FETCH NEXT FROM MyCursor INTO @TOE_NAME, @EID
WHILE @@FETCH_STATUS <> -1
BEGIN
	SELECT @TSQL = '
SET NOCOUNT ON
'
-- Add RowCount variable if just printing SQL.  Not needed if executing because passed as param for sp_executesql.
	IF @IsDebug = 1
		SELECT @TSQL += '
DECLARE @RowCount int = 0
'
	SELECT @TSQL += '
UPDATE dbo.LaborTransactions
SET TOE_Name = ''' + REPLACE(@TOE_NAME, '''', '''''' ) + '''
WHERE EID = ''' + @EID + '''
SELECT @RowCount = @@RowCount
PRINT (''' + REPLACE(@TOE_NAME, '''', '''''' ) + ''' + '' ('' + ''' + @EID + ''' + ''): '' + CONVERT(varchar(5), @RowCount) + '' rows updated.'' );
'
	IF @IsDebug = 1
		BEGIN
			SET NOCOUNT ON
			PRINT @TSQL
			SET NOCOUNT OFF
		END
	ELSE
		BEGIN
			EXEC sp_executesql @TSQL, N'@RowCount int OUTPUT', @MyCount OUTPUT;
			SELECT @RecordsUpdatedCount = @MyCount + @RecordsUpdatedCount
		END

	FETCH NEXT FROM MyCursor INTO @TOE_NAME, @EID
END

CLOSE MyCursor
DEALLOCATE MyCursor
IF @IsDebug = 0
	PRINT '
Total Number of Records Updated = ' + CONVERT(varchar(50), @RecordsUpdatedCount);

SET NOCOUNT ON

-- Print a list of employee IDs with whose records have NULL employee names after updates have been completed:
select distinct EID EIDs_with_Missing_Names
FROM dbo.LaborTransactions
WHERE TOE_NAME IS NUll
/*
EID
*/

/*
Script output:

ARMSTRONG,JOSEPH ALEXANDER (828311837): 4 rows updated.
BARTON,NICHOLAS H (608302808): 2 rows updated.
BECK,SAMUEL (572758084): 2 rows updated.
BOHANAN,LUKE P (642818850): 44 rows updated.
BRITTON,MATTHEW (533907945): 2 rows updated.
BRODWATER,KEVIN C (101208163): 30 rows updated.
BROWN,JEFFREY M (725599617): 2 rows updated.
BROWN,WENDY S (480225077): 6 rows updated.
BZDYK,EMILY L (325660249): 48 rows updated.
CALHOUN,TRACY A (873935902): 36 rows updated.
CASAS,ANGELES (198684441): 34 rows updated.
CATHEY,DANIEL L (705164416): 1 rows updated.
CHEN,QIUXIA (544744022): 2 rows updated.
COOPER,CAITLIN A (946849882): 18 rows updated.
CORDER0-LARA,KARLA (028661452): 12 rows updated.
CORNWALL,CAITLIN X. (479948051): 2 rows updated.
CORONA,JULIO C (398013631): 106 rows updated.
CORTEZ,ISRAEL (104252614): 36 rows updated.
DESHOTEL,MALIA J (695727750): 2 rows updated.
DIETRICH,EMMA I (607862224): 60 rows updated.
DOS SANTOS FARIA L,PAULO (947412243): 6 rows updated.
EASTMAN,BROOKE A (729589416): 1 rows updated.
FEDRIZZI,RYAN SCOTT (763735586): 8 rows updated.
FENG,YAOHUA (753984186): 28 rows updated.
FLORES,RAMON (300349446): 104 rows updated.
FLORES,WENCESLAO (993141662): 108 rows updated.
FRIEBERTSHAUSER,ALLISON D. (005419957): 146 rows updated.
FRIEDMAN,DANIEL A (457845642): 2 rows updated.
GARCIA SUAREZ,FEDERICO (909779589): 12 rows updated.
GLASCO,GERALD LEE (409820404): 18 rows updated.
HE,YIMENG (773660576): 2 rows updated.
HERNANDEZ,BLANCA E (764115671): 8 rows updated.
HERNANDEZ,JAIME BOLANOS (809402662): 38 rows updated.
HORN,REBECCA (669884975): 6 rows updated.
HU,YONGGUANG (513307850): 2 rows updated.
HUERTA,RICARDO (871368759): 12 rows updated.
HUTTO,SARA V (698606761): 2 rows updated.
JI,CHENGCHENG (846756971): 4 rows updated.
JIANG,FENG (828629022): 26 rows updated.
JONES,MADELEINE (001216241): 4 rows updated.
KAMMEL,LEAH (006762777): 2 rows updated.
LANGSTAFF,SUSAN A. (454046525): 2 rows updated.
LEE,DONGHYUK (166402925): 21 rows updated.
LIN,YI-CHIA (305750986): 6 rows updated.
LIU,DAN (007203284): 5 rows updated.
MA,SHEXIA (467013983): 12 rows updated.
MALLESWARAN,MALLIKA (756214367): 1 rows updated.
MARCHAND-TANAKA,SONDRA L. (103981635): 78 rows updated.
MILLS,SANCHIA V (411496888): 2 rows updated.
MONTI NAZHA,FERNANDO D (443424841): 6 rows updated.
OWLIA,RASHID REZA (637981119): 64 rows updated.
PACE,SARA A (920032414): 2 rows updated.
PADDOCK,EMILY S. (266554617): 18 rows updated.
PAN,YUANJIE (677469769): 15 rows updated.
PATTYSON,TIM G (963944053): 2 rows updated.
PITTS,G. STEPHEN (632970786): 24 rows updated.
POPP,ADAM C (341293900): 14 rows updated.
ROJO,FRANCISCO E (823987250): 6 rows updated.
SALAZAR,FREDDY MARCELO (921105672): 6 rows updated.
SCHILLER,LOGAN T. (607105673): 2 rows updated.
SCHMIT,MEGAN M (094002748): 1 rows updated.
SCHOLEY,EMMA REBECCA (642400659): 4 rows updated.
SCOTT,MAYA P (032150617): 2 rows updated.
SELLERS,JAMISON (908067994): 8 rows updated.
SHEN,WEI (197335425): 24 rows updated.
SHIN,JUNG-EUN (282474162): 2 rows updated.
SONG,GE (741267983): 65 rows updated.
SONG,XIAOYA (193617909): 44 rows updated.
SPILLER,MARGOT E (248648354): 14 rows updated.
STRONG,EMMA B (554940825): 8 rows updated.
SULLIVAN,KELLY A (040795692): 6 rows updated.
TAN,WATUMESA A. (367712148): 12 rows updated.
THORDSEN,MARGARET L (808194641): 26 rows updated.
TOOFAN,YALDA A (577870546): 6 rows updated.
TRIMMER,LINDSEY C (806308425): 2 rows updated.
VAHI-FERGUSON,GABRIEL (095076238): 1 rows updated.
WALTRIP,CHELSEY (674459367): 8 rows updated.
WANG,CHANGQUAN (415509082): 18 rows updated.
WANG,RU (750358053): 40 rows updated.
WHALEN,MATTHEW ADAM (185953726): 37 rows updated.
WHITLATCH,AARON M (341453074): 38 rows updated.
WU,JINGYAN (451881692): 18 rows updated.
XIAO,LU (119927911): 6 rows updated.
ZIMMERMAN,SHARON N (757407432): 22 rows updated.

Total Number of Records Updateds = 1686
*/

END