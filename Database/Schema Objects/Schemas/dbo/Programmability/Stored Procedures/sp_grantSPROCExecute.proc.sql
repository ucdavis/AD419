-- =============================================
-- Author:		Scott Kirkland
-- Create date: 11/9/06
-- Description:	
-- =============================================
CREATE PROCEDURE [dbo].[sp_grantSPROCExecute] 
	@RoleName varchar(50) = 'ASPNET', 
	@SPPrefix varchar(25) = 'usp'

AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

SET NOCOUNT ON

DECLARE @GrantStatement nvarchar(4000)

DECLARE GrantStatements CURSOR
LOCAL FAST_FORWARD READ_ONLY FOR
SELECT
    N'GRANT EXECUTE ON ' +
    QUOTENAME(ROUTINE_SCHEMA) +
    N'.' +
    QUOTENAME(ROUTINE_NAME) +
    ' TO ' + @RoleName + ''
FROM INFORMATION_SCHEMA.ROUTINES
WHERE
    OBJECTPROPERTY(
        OBJECT_ID(QUOTENAME(ROUTINE_SCHEMA) +
            N'.' +
            QUOTENAME(ROUTINE_NAME)),
        'IsMSShipped') = 0 AND
    OBJECTPROPERTY(
        OBJECT_ID(QUOTENAME(ROUTINE_SCHEMA) +
            N'.' +
            QUOTENAME(ROUTINE_NAME)),
        'IsProcedure') = 1 AND
    ROUTINE_SCHEMA = N'dbo' AND
    ROUTINE_NAME LIKE @SPPrefix + '%'
OPEN GrantStatements
WHILE 1 = 1
BEGIN
    FETCH NEXT FROM GrantStatements
        INTO @GrantStatement
    IF @@FETCH_STATUS = -1 BREAK
    BEGIN
       RAISERROR (@GrantStatement, 0, 1) WITH NOWAIT
       EXECUTE sp_ExecuteSQL @GrantStatement
    END
END
CLOSE GrantStatements
DEALLOCATE GrantStatements

END
