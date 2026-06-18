/*
One-time provisioning for the ad419 app's access to caes-roberto.

Run manually as a sysadmin on caes-roberto, once per environment. Server-level
objects (logins, linked server mappings) cannot be managed by a DACPAC, so this
lives here as a documented script instead.

The app reaches caes-roberto through an Azure App Service hybrid connection and
only runs OPENQUERY against the AE_Redshift_PROD linked server. The login needs
no database access beyond connecting. The linked server and its security mapping
are managed elsewhere; the login below still needs to be added to that mapping.

Replace <password> before running. Record the password in the GitHub Environment
secret DATAMART_CONNECTION as part of the connection string:
  Server=caes-roberto,1433;Database=master;User Id=ad419_app;Password=...;Encrypt=True;TrustServerCertificate=True
*/

CREATE LOGIN [ad419_app] WITH PASSWORD = '<password>', CHECK_POLICY = ON;
