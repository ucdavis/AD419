CREATE VIEW dbo.ARC_Codes
AS
SELECT        ARC_Cd, ARC_Name, OP_Func_Name, DS_Last_Update_Date, ARC_Category_Cd, ARC_Sub_Category_Cd, isAES
FROM            FISDataMart.dbo.ARC_Codes