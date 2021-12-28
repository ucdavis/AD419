
-- Modifications:
--
-- =============================================
create procedure [dbo].[usp_GetRolesByLoginID]
    	@LoginID nvarchar(10),
	@ApplicationName varchar(50) = 'AD419'

    as
begin
    exec [Catbert3].[dbo].[usp_getRolesInAppByLoginID] @ApplicationName, @LoginID
end;