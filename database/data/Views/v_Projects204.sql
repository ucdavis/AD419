CREATE VIEW [data].[v_Projects204]
AS
-- Distinct AE project numbers mapped to 204 NIFA projects. The AE and UCPath
-- imports fold these into their source filters as unconditional OR arms.
-- Every 204 row has an AEProjectNumber by the readiness guard; the null
-- filter is defense in depth.
SELECT DISTINCT [AEProjectNumber]
FROM [data].[Projects]
WHERE [Sfn] = '204'
  AND [AEProjectNumber] IS NOT NULL;
