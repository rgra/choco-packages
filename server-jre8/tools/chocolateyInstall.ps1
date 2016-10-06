$packageName = $env:chocolateyPackageName
$buildNumber = "13"
$checksum = "9fd7206aaadc82c5944b9d654d642910a2563ace1115c92332f9ca3b22da8ef8"

#8.0.xx to jdk1.8.0_xx
$versionArray = $env:chocolateyPackageVersion.Split(".")
$majorVersion = $versionArray[0]
$minorVersion = $versionArray[1]
$updateVersion = $versionArray[2]

$folderVersion = "jdk1.$majorVersion.$($minorVersion)_$updateVersion"

$fileNameBase = "server-jre-$($majorVersion)u$($updateVersion)-windows-x64"
$fileName = "$fileNameBase.tar.gz"

$url        = "http://download.oracle.com/otn-pub/java/jdk/$($majorVersion)u$($updateVersion)-b$buildNumber/$fileName"

$osBitness = Get-ProcessorBits
# 32-bit not supported
if ($osBitness -eq 32) {
   Throw "The package $packageName is only available for 64-bit architectures"
}

$arguments = @{}

# Now we can use the $env:chocolateyPackageParameters inside the Chocolatey package
$packageParameters = $env:chocolateyPackageParameters

# Default value
$InstallationPath = Join-Path (Get-BinRoot) "Java/server-jre"
$ForceEnvVars = $false
$EnvVariableType = "User"

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
    if ($arguments.ContainsKey("Machine")) {
        Write-Host "Machine Argument Found"
        $EnvVariableType = "Machine"
    }

} else {
    Write-Debug "No Package Parameters Passed in"
}

Write-Debug "Installing to $InstallationPath, Params: ForceEnvVars=$ForceEnvVars, EnvVariableType=$EnvVariableType"

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

if (![System.IO.File]::Exists($tarGzFile)) {
  $wget = Join-Path "$env:ChocolateyInstall" '\bin\wget.exe'
  Write-Debug "wget found at `'$wget`'"

  #Download file. Must set Cookies to accept license
  Write-Debug "Downloading file $tarGzFile"
  .$wget --quiet --no-check-certificate --header "Cookie: gpw_e24=http%3A%2F%2Fwww.oracle.com%2F; oraclelicense=accept-securebackup-cookie" $url -O $tarGzFile
  Get-ChecksumValid -File $tarGzFile -Checksum $checksum -ChecksumType SHA256
}

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

Install-ChocolateyPath '%JAVA_HOME%\bin' $EnvVariableType

#Remove-Item -Recurse $tempDir
