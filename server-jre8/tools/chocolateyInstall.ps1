$packageName = $env:chocolateyPackageName
# The buildNumber should be easier to determine or pass from the nuspec
$buildNumber = "08"
$checksum = "7c46e565a353f4b318760aa7082a435458f9bba7e5b89d9e3fd6c190242093d9"
$downloadHash = "1961070e4c9b4e26a04e7f5a083f551e"

# Discard any -pre/-beta/-testing appended to avoid releasing an unfinished on Chocolatey.org
$semanticVersion = $env:chocolateyPackageVersion.Split("-")[0]
#8.0.xx to jdk1.8.0_xx
$versionArray = $semanticVersion.Split(".")
$majorVersion = $versionArray[0]
$minorVersion = $versionArray[1]
$updateVersion = $versionArray[2]

$folderVersion = "jdk1.$majorVersion.$($minorVersion)_$updateVersion"

$fileNameBase = "server-jre-$($majorVersion)u$($updateVersion)-windows-x64"
$fileName = "$fileNameBase.tar.gz"

# Oracle got clever and is throwing a hash/sessionID into the path
$url = "http://download.oracle.com/otn-pub/java/jdk/$($majorVersion)u$($updateVersion)-b$buildNumber/$($downloadHash)/$fileName"

$osBitness = Get-ProcessorBits
# 32-bit not supported
if ($osBitness -eq 32) {
   Throw "The package $packageName is only available for 64-bit architectures"
}

$arguments = @{}

# Now we can use the $env:chocolateyPackageParameters inside the Chocolatey package
$packageParameters = $env:chocolateyPackageParameters

# Default value
# uses deprecated Get-BinRoot
#$InstallationPath = Join-Path (Get-BinRoot) "Java/server-jre"
$InstallationPath = Join-Path (Get-ToolsLocation) "Java/server-jre"
$ForceEnvVars = $false
$EnvVariableType = "Machine"

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

    if ($arguments.ContainsKey("InstallationPath")) {
        Write-Host "InstallationPath Argument Found"
        $InstallationPath = $arguments["InstallationPath"]
    }
    if ($arguments.ContainsKey("Force")) {
        Write-Host "Force Argument Found"
        $ForceEnvVars = $true
    }
    if ($arguments.ContainsKey("User")) {
        Write-Host "User Argument Found"
        $EnvVariableType = "User"
    }

} else {
    Write-Debug "No Package Parameters Passed in"
}

Write-Debug "Installing to $InstallationPath, Params: ForceEnvVars=$ForceEnvVars, EnvVariableType=$EnvVariableType"

# Future state, write install options file to use in uninstall (ie /Machine or /User /InstallationPath)
# This would be easier if installed with Install-ChocolateyZipFile and writing the parameters to $toolsDir aka Invocation.

#Create Temp Folder
$chocTempDir = Join-Path $env:TEMP "chocolatey"
$tempDir = Join-Path $chocTempDir "$packageName"
if ($env:packageVersion -ne $null) {$tempDir = Join-Path $tempDir "$env:packageVersion"; }
if (![System.IO.Directory]::Exists($tempDir)) {[System.IO.Directory]::CreateDirectory($tempDir) | Out-Null}

$tarGzFile = "$tempDir\$fileName"
$tarFile = "$tempDir\$fileNameBase.tar"

if ([System.IO.File]::Exists($tarGzFile)) {
    Write-Debug "Checking if existing file $tarGzFile matches checksum"
    #Check sum of existing file
    Try {
        Get-ChecksumValid -File $tarGzFile -Checksum $checksum -ChecksumType SHA256 -ErrorAction Stop
    }
    Catch{
        Write-Debug "Checksum failed, deleting old file $tarGzFile"
        Remove-Item $tarGzFile
    }
}

# Added some .NET code to remove the dependency on wget
# If chocolatey >= 0.9.10 could use Get-ChocolateyWebFile with $options
# Currently investigating a bug where it doesn't seem to pass the cookie in properly
#if ($env:ChocolateyVersion -gt "0.9.10") {
#$options =
#@{
#  Headers = @{
#    Cookie = " oraclelicense=accept-securebackup-cookie";
#  }
#}
#
#Write-Debug "Downloading file $tarGzFile using Get-ChocolateyWebFile"
#Get-ChocolateyWebFile -PackageName $packageName -FileFullPath $tarGzFile -Url $url -Checksum $checksum -ChecksumType SHA256 -Options $options
# } # End Get-ChocolateyWebFile
#
# } else {
# Native .NET download for choco < 0.9.10
Write-Debug "Downloading file $tarGzFile using System.Net.WebClient"
$wc = New-Object System.Net.WebClient
$wc.Headers.Add([System.Net.HttpRequestHeader]::Cookie, "oraclelicense=accept-securebackup-cookie");
$wc.Proxy.Credentials = [System.Net.CredentialCache]::DefaultNetworkCredentials
$wc.DownloadFile($url, $tarGzFile)
Get-ChecksumValid -File $tarGzFile -Checksum $checksum -ChecksumType SHA256
# } # End native .NET block

# Wget dependency block {
#if (![System.IO.File]::Exists($tarGzFile)) {
#  $wget = Join-Path "$env:ChocolateyInstall" '\bin\wget.exe'
#  Write-Debug "wget found at `'$wget`'"
#
#  #Download file. Must set Cookies to accept license
#  Write-Debug "Downloading file $tarGzFile"
#  .$wget --quiet --no-check-certificate --header "Cookie: gpw_e24=http%3A%2F%2Fwww.oracle.com%2F; oraclelicense=accept-securebackup-cookie" $url -O $tarGzFile
#  Get-ChecksumValid -File $tarGzFile -Checksum $checksum -ChecksumType SHA256
#}
# } # End wget dependency block

#Extract gz to .tar File
Get-ChocolateyUnzip $tarGzFile $tempDir
#Extract tar to destination
Get-ChocolateyUnzip $tarFile $InstallationPath

$newJavaHome = Join-Path $InstallationPath $folderVersion
$oldJavaHome = Get-EnvironmentVariable "JAVA_HOME" $EnvVariableType

if(($oldJavaHome -eq "") -or $ForceEnvVars) {
   Write-Host "Setting JAVA_HOME to $newJavaHome"
   Install-ChocolateyEnvironmentVariable -variableName "JAVA_HOME" -variableValue $newJavaHome -variableType $EnvVariableType
}
else {
   Write-Debug "JAVA_HOME already set to $oldJavaHome."
}

# Need to do an existance check to see if the variable version is already in PATH
Install-ChocolateyPath '%JAVA_HOME%\bin' $EnvVariableType
Get-EnvironmentVariable -Name 'PATH' -Scope $EnvVariableType -PreserveVariables
#Remove-Item -Recurse $tempDir
