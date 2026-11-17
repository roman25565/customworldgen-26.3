# Starts a Fabric test server that has the DatapackBiomesToPng mod, runs /biomemap or /biomefind
# commands over RCON one after another, waits for each to finish (watching the log), outputs each
# job's report and stops the server.
param(
    [Parameter(Mandatory)] [string]$ServerDir,
    [Parameter(Mandatory)] [int]$RconPort,
    [Parameter(Mandatory)] [string[]]$Commands,  # e.g. 'biomefind quick 30000 frozen_peaks 7000 3000'
    [string]$Launcher = 'fabric-server-mc.1.21.1-loader.0.20.1-launcher.1.1.2.jar',
    [double]$CpuShare = 0.5          # share of logical CPUs the server may use (the PC runs hot)
)
$ErrorActionPreference = 'Stop'
$Password = (Get-Content "$PSScriptRoot\rcon-password.txt" -Raw).Trim()
. "$PSScriptRoot\Rcon.ps1"

# Caps CPU load: the mod's parallel sampling gets that many threads, and the whole process is pinned
# to that many logical CPUs at idle priority. Up to half of the logical CPUs it takes every other one
# (one SMT thread per physical core), so the heat spreads over all cores instead of a few hot ones.
$logical = [Environment]::ProcessorCount
$threads = [math]::Max(1, [math]::Floor($logical * $CpuShare))
$mask = 0L
if ($threads -le $logical / 2) { for ($i = 0; $i -lt $threads; $i++) { $mask = $mask -bor (1L -shl (2 * $i)) } }
else { $mask = [long][math]::Pow(2, $threads) - 1 }
$proc = Start-Process java -ArgumentList '-Xms2G', '-Xmx6G', "-Djava.util.concurrent.ForkJoinPool.common.parallelism=$threads", '-jar', $Launcher, 'nogui' `
    -WorkingDirectory $ServerDir -RedirectStandardOutput "$ServerDir\stdout.txt" -RedirectStandardError "$ServerDir\stderr.txt" -PassThru -WindowStyle Hidden
$proc.ProcessorAffinity = [IntPtr]$mask
$proc.PriorityClass = 'Idle'
$deadline = (Get-Date).AddMinutes(8)
while (-not ((Get-Content "$ServerDir\stdout.txt" -Raw -ErrorAction SilentlyContinue) -match 'Done \(')) {
    Start-Sleep -Seconds 2
    if ($proc.HasExited -or (Get-Date) -gt $deadline) { 'server failed:'; Get-Content "$ServerDir\stdout.txt" -Tail 40; if (-not $proc.HasExited) { $proc.Kill() }; exit 1 }
}
$c = Connect-Rcon $RconPort
$c.Client.ReceiveTimeout = 60000
try {
    foreach ($command in $Commands) {
        $logStart = (Get-Content "$ServerDir\logs\latest.log").Count
        "> $command"
        Invoke-Rcon $c $command
        $jobDeadline = (Get-Date).AddMinutes(120)
        while ($true) {
            Start-Sleep -Seconds 2
            $new = @(Get-Content "$ServerDir\logs\latest.log" | Select-Object -Skip $logStart)
            if ($new -match '(biomemap|biomefind) \S+ (done|failed)') { break }
            if ((Get-Date) -gt $jobDeadline) { 'timeout'; break }
            if ($proc.HasExited) { "server exited (code $($proc.ExitCode)) during the job"; Get-Content "$ServerDir\stdout.txt" -Tail 10; exit 1 }
        }
        # The report is logged as one multi-line message: output from the done/failed line on.
        $at = [array]::FindIndex([string[]]$new, [Predicate[string]] { param($l) $l -match '(biomemap|biomefind) \S+ (done|failed)' })
        $new | Select-Object -Skip $at
    }
} finally {
    Invoke-Rcon $c 'stop' | Out-Null
    $c.Client.Close()
    $proc.WaitForExit(120000) | Out-Null
}
