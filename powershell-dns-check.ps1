# Read domains and record types from file
$domains = Get-Content "domains.txt" | ForEach-Object {
    $split = $_ -split ","
    [PSCustomObject]@{
        Domain = $split[0]
        RecordType = $split[1]
        ExpectedValue = $split[2]
    }
}

# Read resolvers from file
$resolvers = Get-Content "resolvers.txt"

# Output file
$outputFile = "dns_results.csv"

# Add CSV header only if the file does not exist
if (-Not (Test-Path $outputFile)) {
    "Timestamp,Result,Domain,RecordType,Resolver,ExpectedValue,ReturnedValue" | Set-Content -Path $outputFile
}

# Perform DNS lookups
foreach ($domainEntry in $domains) {
    foreach ($resolver in $resolvers) {
        try {
            $result = Resolve-DnsName -Name $domainEntry.Domain -Type $domainEntry.RecordType -Server $resolver -ErrorAction Stop
            
            switch ($domainEntry.RecordType.ToUpper()) {
                "A"     { $resolvedData = $result | Select-Object -ExpandProperty IPAddress -ErrorAction SilentlyContinue }
                "CNAME" { $resolvedData = $result | Select-Object -ExpandProperty NameHost -ErrorAction SilentlyContinue }
                "NS"    { $resolvedData = $result | Select-Object -ExpandProperty NameHost -ErrorAction SilentlyContinue }
                "MX"    { $resolvedData = $result | Select-Object -ExpandProperty NameExchange -ErrorAction SilentlyContinue }
                "TXT"   { 
                    $txtRecords = $result | Select-Object -ExpandProperty Strings -ErrorAction SilentlyContinue 
                    if ($txtRecords -is [array]) {
                        # Separate SPF and non-SPF records
                        $spfRecords = $txtRecords | Where-Object { $_ -match "^v=spf1" }
                        $otherRecords = $txtRecords | Where-Object { $_ -notmatch "^v=spf1" }

                        # Join multi-line TXT records
                        $spfResolved = ($spfRecords -join " ").Trim()
                        $otherResolved = ($otherRecords -join " ").Trim()

                        # Combine results into array format for processing
                        $resolvedData = @()
                        if ($spfResolved) { $resolvedData += $spfResolved }
                        if ($otherResolved) { $resolvedData += $otherResolved }
                    } elseif ($txtRecords) {
                        $resolvedData = @($txtRecords.Trim())
                    } else {
                        $resolvedData = @("Not found")
                    }
                }
                default  { $resolvedData = @("Unsupported record type") }
            }
            
        } catch {
            $resolvedData = @("Error: $_")
        }
        
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        
        # Ensure multiple results are properly handled
        $matchFound = $false
        foreach ($record in $resolvedData) {
            if ($record -eq $domainEntry.ExpectedValue) {
                $matchStatus = "Match"
                $matchFound = $true
            }
        }
        
        if (-not $matchFound) {
            if ($resolvedData -contains "Not found") {
                $matchStatus = "Not found"
            } else {
                $matchStatus = "No Match"
            }
        }
        
        # Output each record separately for clarity
        foreach ($record in $resolvedData) {
            "$timestamp,$matchStatus,$($domainEntry.Domain),$($domainEntry.RecordType),$resolver,$($domainEntry.ExpectedValue),$record" | Add-Content -Path $outputFile
        }
    }
}
