$packageName = $env:chocolateyPackageName

$versionArray = $env:chocolateyPackageVersion.Split(".")
$folderVersion = "jdk1.$($versionArray[0]).$($versionArray[1])_$($versionArray[2])"
$InstallationPath = Join-Path $env:ProgramFiles "Java/server-jre"
$EnvVariableType = "User"

if ([System.IO.Directory]::Exists($InstallationPath)) {
    Write-Debug "Uninstalling $packageName from $InstallationPath"

    $JavaHome = Get-EnvironmentVariable "JAVA_HOME" $EnvVariableType
    if($JavaHome -eq $InstallationPath) {
        Install-ChocolateyEnvironmentVariable -variableName "JAVA_HOME" -variableValue "" -variableType $EnvVariableType
    }
    Remove-Item -Recurse $InstallationPath
}
else {
    Write-Debug "No $packageName found at $InstallationPath"
}