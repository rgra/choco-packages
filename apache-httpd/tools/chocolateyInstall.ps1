$packageName = $env:chocolateyPackageName
$vcNumber = "14"
$releaseNumber = "0"

if(!$PSScriptRoot){ $PSScriptRoot = Split-Path $MyInvocation.MyCommand.Path -Parent }
$optionsFile = (Join-Path $PSScriptRoot 'options.xml')

#http://www.apachehaus.com/downloads/httpd-2.4.18-x64-vc11-r2.zip
$unzipParameters = @{
    packageName = $env:chocolateyPackageName
    url = "http://www.apachehaus.com/downloads/httpd-$($env:chocolateyPackageVersion)-x86-vc$vcNumber.zip" 
    url64bit = "http://www.apachehaus.com/downloads/httpd-$($env:chocolateyPackageVersion)-x64-vc$vcNumber.zip" 
    checksum = '4a002ca4649e9999ddb332da9d16fc1cd3e3cc95';
    checksumType = 'sha1';
    checksum64 = 'c35c1ff8e2746556ac26b43bc13a4750b57f83a0';
    checksumType64 = 'sha1';
}

$arguments = @{}

# Now we can use the $env:chocolateyPackageParameters inside the Chocolatey package
$packageParameters = $env:chocolateyPackageParameters

# Default value
$InstallationPath = Join-Path (Get-BinRoot) "Apache/httpd-$env:chocolateyPackageVersion"
$serviceName = "Apache"

# Now parse the packageParameters using good old regular expression
if ($packageParameters) {
    $match_pattern = "\/(?<option>([a-zA-Z0-9]+)):(?<value>([`"'])?([a-zA-Z0-9- \(\)\s_\\:\.]+)([`"'])?)|\/(?<option>([a-zA-Z]+))"
    $option_name = 'option'
    $value_name = 'value'

    if ($packageParameters -match $match_pattern ){
        $results = $packageParameters | Select-String $match_pattern -AllMatches
        $results.matches | % {
        $arguments.Add(
            $_.Groups[$option_name].Value.Trim(),
            $_.Groups[$value_name].Value.Trim())
        }
    }
    else
    {
        Throw "Package Parameters were found but were invalid (REGEX Failure)"
    }

    if ($arguments.ContainsKey("unzipLocation")) {
        Write-Host "InstallationPath Argument Found"
        $InstallationPath = $arguments["unzipLocation"]
    }
    if ($arguments.ContainsKey("serviceName")) {
        Write-Host "ServiceName Argument Found"
        $serviceName = $arguments["serviceName"]
    }
} else {
    Write-Debug "No Package Parameters Passed in"
}


Write-Debug "Installing to $InstallationPath, creating service $serviceName"

Install-ChocolateyZipPackage @unzipParameters -UnzipLocation $InstallationPath

$binPath = (Join-Path $InstallationPath 'Apache24\bin')

Write-Debug "Installing Service $binPath : $serviceName"

Push-Location $binPath
Start-ChocolateyProcessAsAdmin ".\httpd.exe -k install -n '$($serviceName)'"
Pop-Location

$options = @{
    version = $env:chocolateyPackageVersion;
    unzipLocation = $InstallationPath;
    serviceName = $serviceName;
}

Export-CliXml -Path $optionsFile -InputObject $options


