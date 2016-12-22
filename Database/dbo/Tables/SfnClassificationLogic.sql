CREATE TABLE [dbo].[SfnClassificationLogic] (
    [Id]                  INT            IDENTITY (1, 1) NOT NULL,
    [EvaluationOrder]     INT            NOT NULL,
    [ParameterOrder]      INT            NOT NULL,
    [SubParameterOrder]   INT            NULL,
    [LogicalOperator]     VARCHAR (5)    NULL,
    [ColumnName]          VARCHAR (500)  NULL,
    [NegateCondition]     BIT            NULL,
    [ConditionalOperator] VARCHAR (10)   NULL,
    [Values]              VARCHAR (1024) NULL,
    [SFN]                 VARCHAR (10)   NULL
);

