using Microsoft.AspNetCore.Mvc;
using Server.ExpenseReview;
using Server.Helpers;
using Server.JobCodeClassifications;
using Server.Models.JobCodeClassifications;

namespace Server.Controllers;

// The Job Code tab of the Data Classification stage: job codes on reported
// payroll and the job SFN (FTE line) each one is assigned to.
public sealed class JobCodeClassificationsController(
    IJobCodeClassificationService jobCodes,
    IConfirmedCycleProvider confirmedCycles) : ApiControllerBase
{
    // GET api/jobcodeclassifications
    [HttpGet]
    public async Task<IActionResult> Get(CancellationToken cancellationToken)
    {
        var cycle = await confirmedCycles.GetAsync(cancellationToken);
        if (cycle is null)
        {
            return Conflict("No fiscal period has been confirmed in Project Identification.");
        }

        return Ok(await jobCodes.GetAsync(cycle, cancellationToken));
    }

    // PATCH api/jobcodeclassifications
    [HttpPatch]
    public async Task<IActionResult> Assign(
        [FromBody] UpdateJobCodeClassificationRequest request,
        CancellationToken cancellationToken)
    {
        ApiOperationContext.Set(HttpContext,
            ("JobCode", request.JobCode), ("StaffTypeCode", request.StaffTypeCode));

        var result = await jobCodes.AssignAsync(request.JobCode, request.StaffTypeCode, cancellationToken);
        if (result == JobCodeAssignResult.InvalidJobCode)
        {
            return BadRequest("Job code must be 1 to 4 characters.");
        }

        if (result == JobCodeAssignResult.InvalidStaffType)
        {
            return BadRequest($"Unknown staff type '{request.StaffTypeCode}'.");
        }

        // The Expense Review filter cache is left alone: a job SFN is not part
        // of the inclusion rule or of anything Expense Review filters on.
        return NoContent();
    }
}
