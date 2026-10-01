namespace Server.AutoAssociations;

/// <summary>
/// The auto-association build procedure rejected the current data (for
/// example an included transaction with no OrgR). The message is the
/// procedure's own and is safe to show to the user.
/// </summary>
public sealed class AutoAssociationBuildException(string message, Exception innerException)
    : Exception(message, innerException);
