ALTER TABLE [dbo].[Accounts]
    ADD CONSTRAINT [FK_Accounts_Organizations] FOREIGN KEY ([Year], [Period], [Org], [Chart]) REFERENCES [dbo].[Organizations] ([Year], [Period], [Org], [Chart]) ON DELETE NO ACTION ON UPDATE NO ACTION NOT FOR REPLICATION;


GO
ALTER TABLE [dbo].[Accounts] NOCHECK CONSTRAINT [FK_Accounts_Organizations];

