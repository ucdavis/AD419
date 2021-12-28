
-- =============================================
-- Author:		Ken Taylor
-- Create date: 02-11-2010
-- Description:	Rebuild main FISDataMart table indexes.
-- Usage:
/*
	USE [PPSDataMart]
	GO

	EXEC [dbo].[usp_RebuildPPSDataMartIndexes]
	GO

*/
-- Modifications: 
--	2021-03-09 by kjt: Revised to include Alter index on [UCPath_PersonJob], and [UCPath_JobDepartmentPrecidence],
--		plus changed index name on [dbo].[Persons] to [PK_Persons_1] as this is a new persons table which is being updated
--		from UCPath. 
-- =============================================
CREATE PROCEDURE [dbo].[usp_RebuildPPSDataMartIndexes]
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    ALTER INDEX [PK_Appointments] ON [dbo].[Appointments] REBUILD PARTITION = ALL WITH ( PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON, ONLINE = OFF, SORT_IN_TEMPDB = OFF )
	ALTER INDEX [PK_Departments] ON [dbo].[Departments] REBUILD PARTITION = ALL WITH ( PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON, ONLINE = OFF, SORT_IN_TEMPDB = OFF )
	ALTER INDEX [PK_Distributions] ON [dbo].[Distributions] REBUILD PARTITION = ALL WITH ( PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON, ONLINE = OFF, SORT_IN_TEMPDB = OFF )
	ALTER INDEX [PK_UCPath_PersonJob] ON [dbo].[UCPath_PersonJob] REBUILD PARTITION = ALL WITH ( PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON, ONLINE = OFF, SORT_IN_TEMPDB = OFF )
	ALTER INDEX [UCPath_JobDepartmentPrecidence_EMPLID_CLINDX] ON [dbo].[UCPath_JobDepartmentPrecidence] REBUILD PARTITION = ALL WITH ( PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON, ONLINE = OFF, SORT_IN_TEMPDB = OFF )
	ALTER INDEX [PK_RICE_UC_KRIM_PERSON] ON [dbo].[RICE_UC_KRIM_PERSON] REBUILD PARTITION = ALL WITH ( PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON, ONLINE = OFF, SORT_IN_TEMPDB = OFF )
	ALTER INDEX [PK_Persons_1] ON [dbo].[Persons] REBUILD PARTITION = ALL WITH ( PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON, ONLINE = OFF, SORT_IN_TEMPDB = OFF )
	ALTER INDEX [PK_Schools] ON [dbo].[Schools] REBUILD PARTITION = ALL WITH ( PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON, ONLINE = OFF, SORT_IN_TEMPDB = OFF )
	ALTER INDEX [PK_TitleGroups] ON [dbo].[TitleGroups] REBUILD PARTITION = ALL WITH ( PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON, ONLINE = OFF, SORT_IN_TEMPDB = OFF )
	ALTER INDEX [PK_Titles] ON [dbo].[Titles] REBUILD PARTITION = ALL WITH ( PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON, ONLINE = OFF, SORT_IN_TEMPDB = OFF )
END
