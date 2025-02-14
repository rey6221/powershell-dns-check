# Define input and output files
$inputFile = "domains.txt"      # Text file containing domain names (one per line)
$resolversFile = "resolvers.txt" # Text file containing DNS resolvers (one per line)
$outputFile = "dns_results.csv"
$recordType = "A"  # Change this to MX, TXT, etc., if needed

# Check if the output CSV exists, and add the header only if it's missing
if (-not (Test-Path $outputFile)) {
    "Timestamp,Domain,Record Type,IP Address,DNS Server" | Out-File -FilePath $outputFile -Encoding utf8
}

# Read domains and resolvers from their respective files
$domains = Get-Content $inputFile | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
$resolvers = Get-Content $resolversFile | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }

# Loop through each resolver
foreach ($dnsServer in $resolvers) {
    Write-Host "Using resolver: $dnsServer"

    # Loop through each domain
    foreach ($domain in $domains) {
        # Run nslookup
        $lookupResult = nslookup -querytype=$recordType $domain $dnsServer 2>&1

        # Extract IP addresses
        $ipAddresses = $lookupResult | Where-Object { $_ -match "Address:" } | ForEach-Object { ($_ -split "Address:")[-1].Trim() }

        # Remove the first entry if it contains the DNS server address
        if ($ipAddresses -and $ipAddresses[0] -eq $dnsServer) {
            $ipAddresses = $ipAddresses[1..($ipAddresses.Length - 1)]
        }

        # Convert array to a comma-separated string
        $ipString = if ($ipAddresses) { $ipAddresses -join ", " } else { "No record found" }

        # Record the timestamp
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

        # Append to CSV file
        "$timestamp,$domain,$recordType,$ipString,$dnsServer" | Out-File -FilePath $outputFile -Append -Encoding utf8
    }
}

Write-Host "DNS lookup results appended to $outputFile"
