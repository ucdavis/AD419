CREATE TABLE [dbo].[DocumentOriginCodes] (
    [DocumentOriginCode]             VARCHAR (2)   NOT NULL,
    [OriginCodeDescription]          VARCHAR (40)  NULL,
    [DocumentOriginDatabaseName]     VARCHAR (40)  NULL,
    [DocumentOriginServerName]       VARCHAR (40)  NULL,
    [DefaultChart]                   VARCHAR (2)   NULL,
    [DefaultAccount]                 VARCHAR (7)   NULL,
    [DefaultObject]                  VARCHAR (4)   NULL,
    [GLEContactEmail]                VARCHAR (100) NULL,
    [ReferenceControlManagerDaFisId] VARCHAR (100) NULL,
    [LastUpdateDate]                 DATETIME      NULL
);


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Document Origin Code: This table contains information about the origin codes representing feeds into the DaFIS system.', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'DocumentOriginCodes';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Document Origin Code: An identifier used to determine the source of a transaction. In TP, it is the server id, for the feeder systems, it is the service unit.', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'DocumentOriginCodes', @level2type = N'COLUMN', @level2name = N'DocumentOriginCode';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Origin Code Description: Descriptive name assigned to this Origin Code.', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'DocumentOriginCodes', @level2type = N'COLUMN', @level2name = N'OriginCodeDescription';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Document Origin Database Name: Probably the Database from which the document originated from or was originally saved in.', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'DocumentOriginCodes', @level2type = N'COLUMN', @level2name = N'DocumentOriginDatabaseName';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Document Origin Server Name: Probably the Database Server on which the DocumentOriginDatabase resides.', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'DocumentOriginCodes', @level2type = N'COLUMN', @level2name = N'DocumentOriginServerName';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Default Chart Number: Probably the default chart number to use if none is provided for documents which originate from this source.', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'DocumentOriginCodes', @level2type = N'COLUMN', @level2name = N'DefaultChart';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Default Account Number: Probably the default Account number to use if none is provided for documents which originate from this source.', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'DocumentOriginCodes', @level2type = N'COLUMN', @level2name = N'DefaultAccount';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Default Object Number: Probably the default Object number to use if none is provided for documments which originate from this source.', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'DocumentOriginCodes', @level2type = N'COLUMN', @level2name = N'DefaultObject';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'General Ledger Entry Contact ID(?): Probably whom to contact in regards to the General Ledger Entry for documents which originate from this source', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'DocumentOriginCodes', @level2type = N'COLUMN', @level2name = N'GLEContactEmail';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Reference Control Manager DaFIS ID: Probably the DaFIS in-house ID for the Reference Control Manager for documents which originate from this source.', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'DocumentOriginCodes', @level2type = N'COLUMN', @level2name = N'ReferenceControlManagerDaFisId';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'DaFIS Last Update Date: The last time this row was updated in Decision Support.', @level0type = N'SCHEMA', @level0name = N'dbo', @level1type = N'TABLE', @level1name = N'DocumentOriginCodes', @level2type = N'COLUMN', @level2name = N'LastUpdateDate';

