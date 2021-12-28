

--=========================================================================
-- Author: Ken Taylor
-- Created on: June 15, 2021
-- Name: RiceUcKrimPerson (VIEW)
-- Description: A replacement for the FISDataMart.dbo.RiceUcKrimPerson table,
--	Which uses the PPSDataMart.dbo.RICE_UC_KRIM_PERSON table as a datasource,
--	and renames the columns to match the table it replaces.
--	This was done because there are still some stored procedures and/or functions
--	that used the FISDataMart table that was not being updated automatically.
--	However, the PPSDataMart.dbo.RICE_UC_KRIM_PERSON is updated nightly, so
--	it made more sense just to create a reference to it with the revised column names
--	instead of maintaining another table with identical information.
--
-- Usage:
/*

	USE [FISDataMart]
	GO

	SELECT * FROM [dbo].[RiceUcKrimPerson]

	GO

*/

-- Modifications:
--
--=========================================================================

CREATE VIEW [dbo].[RiceUcKrimPerson] AS
	SELECT 
		[PRNCPL_ID] AS [PrincipalId], 
		[PRNCPL_NM] AS [PrincipalName], 
		[ENTITY_ID] AS [EntityId], 
		[LDAP_UID_NBR] AS [LdapUidNumber], 
		[MOTHRA_ID] AS [MothraId], 
		[COMP_ACCT_USER_ID] AS [ComputingAccountUserId], 
		[FIRST_NM] AS [FirstName], 
		[MIDDLE_NM] AS [MiddleName], 
		[LAST_NM] AS [LastName], 
		[PERSON_NM] AS [PersonName], 
		[EMAIL_ADDR] AS [EmailAddress], 
		[PHONE_NBR] AS [PhoneNumber], 
		[EMPLOYEE_ID] AS [EmployeeId], 
		[PPS_ID] AS [PpsId], 
		[STUDENT_ID] AS [StudentId], 
		[PIDM] AS [Pidm], 
		[DAFIS_ID] AS [DaFisId], 
		[STAFF_IND] AS [StaffInd], 
		[FACULTY_IND] AS [FacultyInd], 
		[STUDENT_IND] AS [StudentInd], 
		[AFFILIATE_IND] AS [AffiliateInd], 
		[PRMRY_DEPT_CD] AS [PrimaryDeptCode], 
		[EMP_STAT_CD] AS [EmployeeStatusCode], 
		[ACTV_IND] AS [ActiveInd], 
		[LAST_UPDT_DT] AS [LastUpdateDate]
	FROM [PPSDataMart].[dbo].[RICE_UC_KRIM_PERSON_V]