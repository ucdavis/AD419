

--=================================================
-- Name: OpFundInvestigatorV (VIEW)
-- Author: Ken Taylor
-- Created On: June 15, 2021
-- Description: 
-- Sources data from OPNEQUERY(FIS_DS,...), and renames the columns 
--	to what's currently present in the OpFundInvertigator table.
--- The main purpose of this table is to be used as a source for loading the 
--	OpFundInvestigator table.
--
-- Usage:
/*

	USE [FISDataMart]
	GO

	SELECT * FROM [dbo].[OpFundInvestigatorV]

	GO

*/

-- Modifications:
--	20210614 by kjt: Added filter so only records >= 2018 would be returned.
--
--=================================================

CREATE VIEW [dbo].[OpFundInvestigatorV] AS

	SELECT * FROM OPENQUERY(FIS_DS, '
	SELECT
		FISCAL_YEAR "Year",
		FISCAL_PERIOD "Period",
		OP_LOCATION_CODE "OpLocationCode",
		OP_FUND_NUM "OpFundNum",
		OP_FUND_INVESTIGATOR_NUM "OpFundInvestigatorNum",
		INVESTIGATOR_TYPE_CODE "InvestigatorTypeCode",
		INVESTIGATOR_DAFIS_USER_ID "InvestigatorDaFisUserId",
		INVESTIGATOR_USER_ID "InvestigatorUserId",
		INVESTIGATOR_NAME "InvestigatorName",
		CHART_NUM "Chart",
		ORG_ID "OrgId",
		CONTACT_IND "ContactInd",
		RESPONSIBLE_IND "ResponsibleInd",
		DS_LAST_UPDATE_DATE "LastUpdateDate"
	FROM
		FINANCE.OP_FUND_INVESTIGATOR
	WHERE FISCAL_YEAR >= 2018

')