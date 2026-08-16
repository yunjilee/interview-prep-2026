$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$planPaths = @(
    (Join-Path $repoRoot 'README.md'),
    (Join-Path $repoRoot 'STUDY_PLAN.md')
)
$expectedMilestones = 12
$tasksPerMilestone = 7
$expectedTasks = $expectedMilestones * $tasksPerMilestone

function Get-PlanProgress {
    param([Parameter(Mandatory)][string]$Path)

    $content = Get-Content -Path $Path -Raw -Encoding UTF8
    $milestones = [regex]::Matches(
        $content,
        '(?ms)^### Milestone (\d+)\b.*?(?=^### Milestone \d+\b|^## |\z)'
    )

    $statuses = [System.Collections.Generic.List[string]]::new()

    foreach ($milestoneNumber in 1..$expectedMilestones) {
        $milestone = $milestones |
            Where-Object { [int]$_.Groups[1].Value -eq $milestoneNumber } |
            Select-Object -First 1

        if (-not $milestone) {
            throw "$Path is missing Milestone $milestoneNumber."
        }

        $rows = [regex]::Matches(
            $milestone.Value,
            '(?m)^\| ([1-7]) \|.*\| (✅|⬜) \|\s*$'
        )

        if ($rows.Count -ne $tasksPerMilestone) {
            throw "$Path Milestone $milestoneNumber must contain exactly $tasksPerMilestone numbered progress rows."
        }

        foreach ($taskNumber in 1..$tasksPerMilestone) {
            $row = $rows |
                Where-Object { [int]$_.Groups[1].Value -eq $taskNumber } |
                Select-Object -First 1

            if (-not $row) {
                throw "$Path Milestone $milestoneNumber is missing task $taskNumber."
            }

            $statuses.Add($row.Groups[2].Value)
        }
    }

    if ($statuses.Count -ne $expectedTasks) {
        throw "$Path contains $($statuses.Count) tracked tasks; expected $expectedTasks."
    }

    return ,$statuses.ToArray()
}

$readmeStatuses = Get-PlanProgress -Path $planPaths[0]
$studyPlanStatuses = Get-PlanProgress -Path $planPaths[1]

for ($index = 0; $index -lt $expectedTasks; $index++) {
    if ($readmeStatuses[$index] -ne $studyPlanStatuses[$index]) {
        $milestone = [math]::Floor($index / $tasksPerMilestone) + 1
        $task = ($index % $tasksPerMilestone) + 1
        throw "README.md and STUDY_PLAN.md disagree at Milestone $milestone, task $task."
    }
}

$completed = @($readmeStatuses | Where-Object { $_ -eq '✅' }).Count
$percentage = [math]::Round(($completed / $expectedTasks) * 100)
$barWidth = 600
$fillWidth = [math]::Round(($completed / $expectedTasks) * $barWidth, 2)
$outputPath = Join-Path (Join-Path $repoRoot 'assets') 'progress.svg'
$outputDirectory = Split-Path -Parent $outputPath

New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null

$svg = @"
<svg xmlns="http://www.w3.org/2000/svg" width="640" height="58" role="img" aria-label="$completed of $expectedTasks tasks complete, $percentage percent">
  <title>Overall study progress: $completed of $expectedTasks tasks complete ($percentage%)</title>
  <rect width="640" height="58" rx="10" fill="#ffffff"/>
  <rect x="20" y="14" width="$barWidth" height="30" rx="8" fill="#d0d7de"/>
  <clipPath id="progress-clip">
    <rect x="20" y="14" width="$barWidth" height="30" rx="8"/>
  </clipPath>
  <rect x="20" y="14" width="$fillWidth" height="30" fill="#2da44e" clip-path="url(#progress-clip)"/>
  <text x="320" y="34" text-anchor="middle" font-family="-apple-system, BlinkMacSystemFont, Segoe UI, sans-serif" font-size="14" font-weight="600" fill="#24292f">$completed / $expectedTasks tasks ($percentage%)</text>
</svg>
"@

[System.IO.File]::WriteAllText(
    $outputPath,
    ($svg.Trim() + [Environment]::NewLine),
    [System.Text.UTF8Encoding]::new($false)
)

Write-Host "Updated progress: $completed / $expectedTasks tasks ($percentage%)."
