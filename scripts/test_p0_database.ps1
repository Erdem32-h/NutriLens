param([string]$ContainerName = "nutrilens-p0-test-$PID")
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$image = 'public.ecr.aws/supabase/postgres:17.6.1.095'
$password = [guid]::NewGuid().ToString('N')
function Invoke-TestSql([string]$Sql) {
    $result = $Sql | docker exec -i -e "PGPASSWORD=$password" $ContainerName psql -w -U supabase_admin -d postgres -v ON_ERROR_STOP=1 -At
    if ($LASTEXITCODE -ne 0) { throw "Isolated SQL test failed: $result" }
    return $result
}
docker run --detach --name $ContainerName --env "POSTGRES_PASSWORD=$password" $image | Out-Null
if ($LASTEXITCODE -ne 0) { throw 'Could not start isolated database' }
try {
    $ready = $false
    for ($i = 0; $i -lt 60; $i++) {
        docker exec $ContainerName pg_isready -U postgres *> $null
        if ($LASTEXITCODE -eq 0) { $ready = $true; break }
        Start-Sleep -Seconds 1
    }
    if (-not $ready) { throw 'Database startup timed out' }
    # Image first starts a temporary server, then restarts after init scripts.
    Start-Sleep -Seconds 5
    foreach ($file in @(
        'supabase/tests/p0_fixture.sql',
        'supabase/migrations/20260905210000_account_deletion_preparation.sql',
        'supabase/migrations/20260905211000_persistent_ai_quota.sql',
        'supabase/tests/p0_regression.sql'
    )) {
        Invoke-TestSql (Get-Content (Join-Path $root $file) -Raw)
    }
    # Independent connections prove admission is atomic across workers.
    $subject = 'dev:' + ('c' * 64)
    $outcomes = 1..60 | ForEach-Object -Parallel {
        $sql = "select public.consume_ai_quota('$using:subject', 1000);"
        $sql | docker exec -i -e "PGPASSWORD=$using:password" $using:ContainerName psql -w -U supabase_admin -d postgres -v ON_ERROR_STOP=1 -At
        if ($LASTEXITCODE -ne 0) { throw 'Concurrent SQL failed' }
    } -ThrottleLimit 12
    if (@($outcomes | Where-Object { $_ -eq 't' }).Count -ne 30 -or
        @($outcomes | Where-Object { $_ -eq 'f' }).Count -ne 30) {
        throw 'Concurrent subject quota admitted wrong request count'
    }
    Invoke-TestSql 'truncate public.ai_request_quota;' | Out-Null
    $outcomes = 1..30 | ForEach-Object -Parallel {
        $hash = ([string]$_).PadLeft(64, '0')
        "select public.consume_ai_quota('dev:$hash', 10);" |
            docker exec -i -e "PGPASSWORD=$using:password" $using:ContainerName psql -w -U supabase_admin -d postgres -v ON_ERROR_STOP=1 -At
        if ($LASTEXITCODE -ne 0) { throw 'Concurrent SQL failed' }
    } -ThrottleLimit 12
    if (@($outcomes | Where-Object { $_ -eq 't' }).Count -ne 10 -or
        @($outcomes | Where-Object { $_ -eq 'f' }).Count -ne 20) {
        throw 'Rotating identities bypassed global quota'
    }
    Write-Output 'SQL regression and concurrent quota tests passed.'
} finally {
    # Only this script's disposable container; never touches linked Supabase.
    docker rm --force $ContainerName | Out-Null
}