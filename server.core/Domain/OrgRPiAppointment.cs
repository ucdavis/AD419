namespace Server.Core.Domain;

/// <summary>
/// A PI who holds an appointment in an OrgR beyond the one their projects sit
/// under. Every non-204 project the PI directs also appears on this OrgR.
/// </summary>
public class OrgRPiAppointment
{
    public string UcpEmployeeId { get; set; } = string.Empty;
    public string OrgR { get; set; } = string.Empty;

    /// <summary>Director name when the row was added; shown only when the PI has no projects this cycle.</summary>
    public string? PiName { get; set; }
}
