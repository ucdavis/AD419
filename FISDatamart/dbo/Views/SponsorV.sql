
--=================================================
-- Name: SponsorV (VIEW)
-- Author: Ken Taylor
-- Created On: June 15, 2021
-- Description: 
-- Sources data from OPNEQUERY(FIS_DS,...), and renames the columns 
--	to what's currently present in the Sponsor table.
--- The main purpose of this table is to be used as a source for loading the 
--	Sponsor table.
--
-- Usage:
/*

	USE [FISDataMart]
	GO

	SELECT * FROM [dbo].[SponsorV]

	GO

*/

-- Modifications:
--
--=================================================

CREATE VIEW [dbo].[SponsorV] AS

	SELECT * FROM OPENQUERY(FIS_DS, '
		SELECT
			SPONSOR_CODE            "SponsorCode",
			SPONSOR_CODE_NAME       "SponsorCodeName",
			FEDERAL_AGENCY_CODE     "FederalAgencyCode",
			SPONSOR_CATEGORY_CODE   "SponsorCategoryCode",
			SPONSOR_CATEGORY_NAME   "SponsorCategoryName",
			FOREIGN_SPONSOR_IND     "ForeignSponsorInd",
			UCOP_LAST_UPDATE_DATE   "UCOP_LastUpdateDate",
			TP_LAST_UPDATE_DATE     "TP_LastUpdateDate"
		FROM
			FINANCE.SPONSOR
')