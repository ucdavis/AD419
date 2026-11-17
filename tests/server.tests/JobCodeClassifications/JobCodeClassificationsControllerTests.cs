using FluentAssertions;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Server.Controllers;
using Server.ExpenseReview;
using Server.JobCodeClassifications;
using Server.Models;
using Server.Models.JobCodeClassifications;
using Server.Tests.Helpers;

namespace Server.Tests.JobCodeClassifications;

public class JobCodeClassificationsControllerTests
{
    private static readonly FiscalYearCycle Fy25 = new("FY25", new DateOnly(2024, 10, 1), new DateOnly(2025, 9, 30));

    private static JobCodeClassificationsController CreateController(
        StubService service,
        FiscalYearCycle? cycle,
        RecordingExpenseReviewFilterCacheInvalidator? invalidator = null) =>
        new(service, new StubCycleProvider(cycle), invalidator ?? new RecordingExpenseReviewFilterCacheInvalidator())
        {
            ControllerContext = new ControllerContext { HttpContext = new DefaultHttpContext() },
        };

    [Fact]
    public async Task Get_conflicts_when_no_confirmed_workflow_cycle_exists()
    {
        var service = new StubService();
        var controller = CreateController(service, cycle: null);

        var result = await controller.Get(CancellationToken.None);

        result.Should().BeOfType<ConflictObjectResult>()
            .Which.Value.Should().Be("No fiscal period has been confirmed in Project Identification.");
        service.ReceivedCycle.Should().BeNull();
    }

    [Fact]
    public async Task Get_passes_the_current_run_cycle_to_the_service()
    {
        var service = new StubService();
        var controller = CreateController(service, Fy25);

        var result = await controller.Get(CancellationToken.None);

        var response = result.Should().BeOfType<OkObjectResult>()
            .Which.Value.Should().BeOfType<JobCodeClassificationsResponse>().Subject;
        response.Rows.Should().ContainSingle().Which.JobCode.Should().Be("1234");
        service.ReceivedCycle.Should().Be(Fy25);
    }

    [Fact]
    public async Task Patch_returns_no_content_and_invalidates_the_expense_review_filter_cache_when_assigned()
    {
        var service = new StubService { AssignResult = JobCodeAssignResult.Assigned };
        var invalidator = new RecordingExpenseReviewFilterCacheInvalidator();
        var controller = CreateController(service, Fy25, invalidator);

        var result = await controller.Assign(new UpdateJobCodeClassificationRequest("0000", "1S"), CancellationToken.None);

        result.Should().BeOfType<NoContentResult>();
        service.ReceivedAssignment.Should().Be(("0000", "1S"));
        invalidator.Calls.Should().Be(1);
    }

    [Theory]
    [InlineData(JobCodeAssignResult.InvalidJobCode, "Job code must be 1 to 4 characters.")]
    [InlineData(JobCodeAssignResult.InvalidStaffType, "Unknown staff type 'ZZ'.")]
    public async Task Patch_returns_bad_request_for_invalid_job_code_and_for_invalid_staff_type(
        JobCodeAssignResult assignResult, string message)
    {
        var service = new StubService { AssignResult = assignResult };
        var invalidator = new RecordingExpenseReviewFilterCacheInvalidator();
        var controller = CreateController(service, Fy25, invalidator);

        var result = await controller.Assign(new UpdateJobCodeClassificationRequest("0000", "ZZ"), CancellationToken.None);

        result.Should().BeOfType<BadRequestObjectResult>().Which.Value.Should().Be(message);
        invalidator.Calls.Should().Be(0);
    }

    private sealed class StubCycleProvider(FiscalYearCycle? cycle) : IConfirmedCycleProvider
    {
        public Task<FiscalYearCycle?> GetAsync(CancellationToken cancellationToken) => Task.FromResult(cycle);
    }

    private sealed class StubService : IJobCodeClassificationService
    {
        public JobCodeAssignResult AssignResult { get; init; }

        public FiscalYearCycle? ReceivedCycle { get; private set; }

        public (string? JobCode, string? StaffTypeCode)? ReceivedAssignment { get; private set; }

        public Task<JobCodeClassificationsResponse> GetAsync(FiscalYearCycle cycle, CancellationToken cancellationToken)
        {
            ReceivedCycle = cycle;
            return Task.FromResult(new JobCodeClassificationsResponse(
                cycle.FiscalYear,
                cycle.CycleStart,
                cycle.CycleEnd,
                [new JobCodeClassificationDto("1234", "Professor", "1S", "241", false, 1, 100m, 0.25m)],
                [new StaffTypeOptionDto("1S", "241", "Scientist")]));
        }

        public Task<bool> HasBlockingAsync(FiscalYearCycle cycle, CancellationToken cancellationToken) =>
            throw new NotSupportedException();

        public Task<JobCodeAssignResult> AssignAsync(string? jobCode, string? staffTypeCode, CancellationToken cancellationToken)
        {
            ReceivedAssignment = (jobCode, staffTypeCode);
            return Task.FromResult(AssignResult);
        }
    }
}
