$packageName = $env:chocolateyPackageName

$versionArray = $env:chocolateyPackageVersion.Split(".")
$folderVersion = "jdk1.$($versionArray[0]).$($versionArray[1])_$($versionArray[2])"
# This will need updated to handle install options file eventually
$InstallationPath = Join-Path (Get-ToolsLocation) "Java/server-jre"
$EnvVariableType = "Machine"

if ([System.IO.Directory]::Exists($InstallationPath)) {
    Write-Debug "Uninstalling $packageName from $InstallationPath"

    $JavaHome = Get-EnvironmentVariable "JAVA_HOME" $EnvVariableType
    if($JavaHome -eq $InstallationPath) {
        Install-ChocolateyEnvironmentVariable -variableName "JAVA_HOME" -variableValue $null -variableType $EnvVariableType
    }
    Remove-Item -Recurse $InstallationPath
}
else {
    Write-Debug "No $packageName found at $InstallationPath"
}

# Remove installed variable(s) from PATH
# Loop via @DarwinJS on GitHub as a temp workaround, https://github.com/chocolatey/choco/issues/310
#To avoid bad situations - does not use substring matching, regular expressions are "exact" matches
#Removes duplicates of the target removal path, Cleans up double ";", Handles ending "\"

# Expanded path looks like 'C:\tools\Java\server-jre\jdk1.8.0_101\bin'
# Need to escape the backslash in the regex
[regex] $PathsToRemove = "^(%JAVA_HOME%\\bin)"
$environmentPath = Get-EnvironmentVariable -Name 'PATH' -Scope $EnvVariableType -PreserveVariables
$environmentPath
[string[]]$newpath = ''
foreach ($path in $environmentPath.split(';'))
{
  If (($path) -and ($path -notmatch $PathsToRemove))
    {
        [string[]]$newpath += "$path"
        "$path added to `$newpath"
    } else {
        "Path to remove found: $path"
    }
}
$AssembledNewPath = ($newpath -join(';')).trimend(';')
$AssembledNewPath

Install-ChocolateyEnvironmentVariable -variableName 'PATH' -variableValue $AssembledNewPath -variableType $EnvVariableType
"Path with variables"
$newEnvironmentPath = Get-EnvironmentVariable -Name 'PATH' -Scope $EnvVariableType -PreserveVariables
"Path with values instead of variables"
$env:PATH
