# Creates the Android upload keystore and android\key.properties. Run it yourself: it asks for the password, so the
# password is never written into the repo, a script, or a chat.
#
#   powershell -ExecutionPolicy Bypass -File tool\make_upload_key.ps1
#
# Back up the .jks and the password afterwards (see docs\store\RELEASE_SIGNING.md).

$ErrorActionPreference = 'Stop'
$project = Split-Path -Parent $PSScriptRoot
$keyDir = Join-Path $env:USERPROFILE 'survival-node-keys'
$jks = Join-Path $keyDir 'survival-node-upload.jks'
$props = Join-Path $project 'android\key.properties'

# find keytool: JAVA_HOME first, then PATH
$keytool = $null
if ($env:JAVA_HOME -and (Test-Path (Join-Path $env:JAVA_HOME 'bin\keytool.exe'))) { $keytool = Join-Path $env:JAVA_HOME 'bin\keytool.exe' }
elseif (Get-Command keytool -ErrorAction SilentlyContinue) { $keytool = (Get-Command keytool).Source }
if (-not $keytool) { throw 'keytool not found. Install a JDK or set JAVA_HOME.' }

if (Test-Path $jks) { throw "A keystore already exists at $jks. Refusing to overwrite it. Move it away first if you really want a new one." }

New-Item -ItemType Directory -Force -Path $keyDir | Out-Null

$pw1 = Read-Host 'Choose a keystore password (at least 8 characters)' -AsSecureString
$pw2 = Read-Host 'Type it again' -AsSecureString
$a = [Runtime.InteropServices.Marshal]::PtrToStringBSTR([Runtime.InteropServices.Marshal]::SecureStringToBSTR($pw1))
$b = [Runtime.InteropServices.Marshal]::PtrToStringBSTR([Runtime.InteropServices.Marshal]::SecureStringToBSTR($pw2))
if ($a -ne $b) { throw 'Passwords do not match.' }
if ($a.Length -lt 8) { throw 'Use at least 8 characters.' }

$dname = Read-Host 'Your name or organisation for the certificate (for example: Twelve Scents Publishing)'
if (-not $dname) { $dname = 'Twelve Scents Publishing' }

& $keytool -genkeypair -v -keystore $jks -alias upload -keyalg RSA -keysize 2048 -validity 10000 `
  -storepass $a -keypass $a -dname "CN=$dname, O=$dname, C=US"
if ($LASTEXITCODE -ne 0) { throw 'keytool failed.' }

$esc = $jks -replace '\\', '/'
@"
storePassword=$a
keyPassword=$a
keyAlias=upload
storeFile=$esc
"@ | Set-Content -Path $props -Encoding ascii

Write-Host ''
Write-Host "Created: $jks"
Write-Host "Wrote:   $props (not committed: it is git-ignored)"
Write-Host 'NEXT: back up the .jks and your password in two safe places.'
