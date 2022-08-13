<#
.SYNOPSIS
This powershell script will Upload the specified user account to CyberArk

.PARAMETER UriBase
The Web API resource string
EG: https://onebuild:8001/api/cyberark

.PARAMETER HostName
hostname of account to upload (Windows or iLO)
eg: lonms11111 or lonmi11111 or lonms11111-r

.PARAMETER UserToUpload
Username to upload to CyberArk
eg: "foxmoatAdmin", "iLOAdmin"

.PARAMETER PwdToUpload
PwdToUpload to upload to CyberArk
Note: Leave empty for windows account or HashPL encrypted string for iLOAdmin account

.PARAMETER FunctionOrBusiness
OneBuild Business layer or "iLO"

.PARAMETER TeamOrManagedBy
OneBuild TeamOrManagedBy property or iLO Team eg: "DCS Windows"

.PARAMETER UserName
Username to access the API
EG: fm\svc-obinstaller

.PARAMETER Password
Password for the username

.NOTES
Modification History:
V1.0.0	11/03/2016 - Brent R from original code by Chris C
#>
Param
(
  [Parameter(Position=0, Mandatory=$false, ValueFromPipeline=$false)]
  [string] $UriBase = "https://onebuild.fm.foxmoat.net:8001/api/cyberark" ,
  [Parameter(Position=1, Mandatory=$false, ValueFromPipeline=$false)]
  [string] $HostName ,
  [Parameter(Position=2, Mandatory=$false, ValueFromPipeline=$false)]
  [string] $UserToUpload = "foxmoatAdmin", #"ILOAdmin", #"foxmoatAdmin"
  [Parameter(Position=3, Mandatory=$false, ValueFromPipeline=$false)]
  [string] $PwdToUpload,
  [Parameter(Position=4, Mandatory=$false, ValueFromPipeline=$false)]
  [string] $FunctionOrBusiness = "Group",
  [Parameter(Position=5, Mandatory=$false, ValueFromPipeline=$false)]
  [string] $TeamOrManagedBy = "mGDCS-ESS-WindowsServices", #"CTX", "SQL", "WEB" "G USR - ROL OneBuild Development", # "mGDCS-ESS-WindowsServices, #
  [Parameter(Position=6, Mandatory=$false, ValueFromPipeline=$false)]
  [string] $UserName = "FM\svc-OBInstaller",
  [Parameter(Position=7, Mandatory=$true, ValueFromPipeline=$false)]
  [string] $Password,
  [Parameter(Position=8, Mandatory=$false, ValueFromPipeline=$false)]
  [string] $Location= "Lon",
  [Parameter(Position=9, Mandatory=$false, ValueFromPipeline=$false)]
  [string] $utilityPath = "\\$(HOSTNAME)\d$\private\Utilities"
)
set-psdebug -strict
$errorActionPreference = 'SilentlyContinue'

# --------------------------------------------------------------------------------------------------
# Constant Variables
# --------------------------------------------------------------------------------------------------

set-variable -name INT_RC_SUCCESS 			-value 0 -option constant
set-variable -name INT_RC_FAILURE 			-value 1 -option constant
set-variable -name STR_LOGFILE_PATH_PREFIX	-value "C:\foxmoat\Logs\" -option constant
set-variable -name STR_LOGFILE_EXTENSION 	-value ".log" -option constant

# --------------------------------------------------------------------------------------------------
# --------------------------------------------------------------------------------------------------
# Functions
# --------------------------------------------------------------------------------------------------
# --------------------------------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# 
#   Func:	QuitScript
# 
#   Input:	Return code to exit with
#  
#   Purpose: Clean up open objects and exit with return code
# 		
# ---------------------------------------------------------------------------
Function QuitScript([int]$intRC) {
	#Release object resources
	# $objSQ.Dispose()
	Write-Output "`nExit code: $intRC"
	exit $intRC
}

# ---------------------------------------------------------------------------
#   Func:	LogIt
#   Input:	string to write, whether error or information, whether to write to console
#   Purpose: Write String to console and Logfile
# ---------------------------------------------------------------------------
Function LogIt([string]$TextToWrite, [bool]$ConsoleOutput = $true) {
  If ($ConsoleOutput) {
    # Write output to console
    Write-Host $TextToWrite
  }

	(Get-Date).ToString() + " $TextToWrite" | Out-File -FilePath $strScriptLog -Append -Encoding Default
}

# ---------------------------------------------------------------------------
# 
#   Sub:	ReportAndErrorHandling
# 
#   Input:	
# 
#   Purpose: 
# 			
# 		
# ---------------------------------------------------------------------------
Function ReportAndErrorHandling {
	param(
		[int] $intReturnCode, 
		[int[]] $intAcceptableReturnCodes = (0), 
		[string] $strDescription
	)
	
	if($intAcceptableReturnCodes -contains $intReturnCode) {
		#OK - contine execution
		$strDescription = "SUCCESS: " + $strDescription
		$strDescription += "`n`tRETURN CODE: $intReturnCode"
		Logit $strDescription
	} else {
		#Fail 
		$strDescription = "FAIL: " + $strDescription
		$strDescription += "`n`tRETURN CODE: $intReturnCode"
		Logit $strDescription
		QuitScript $intReturnCode
	} 
}

# ---------------------------------------------------------
# ConvertTo-Json20 - ConvertTo-Json for powershell 2
# ---------------------------------------------------------
Function ConvertTo-Json20([object] $item) {
  add-type -assembly system.web.extensions
  $ps_js=new-object system.web.script.serialization.javascriptSerializer
  return $ps_js.Serialize($item)
}

# ---------------------------------------------------------
# ConvertFrom-Json20 - ConvertFrom-Json for powershell 2
# ---------------------------------------------------------
Function ConvertFrom-Json20([object] $item) {
  add-type -assembly system.web.extensions
  $ps_js=new-object system.web.script.serialization.javascriptSerializer
  return $ps_js.DeserializeObject($item)
}

Function GetPlums([string] $sPWD) {
  If ($sPWD.Substring(0,2) -ne "\\") { return $sPWD }
  $strPwd = $sPWD.Substring(2,($sPWD.Length-2))
  $strTemp = $sPWD
  $f1 = "$utilityPath\hashpwd.exe"
  $f2 = "$utilityPath\HASHPL3.dll"
  If ((Test-Path $f1) -and (Test-Path $f2)) {
    $pinfo = New-object System.Diagnostics.ProcessStartInfo
    $pinfo.CreateNoWindow = $true
    $pinfo.UseShellExecute = $false
    $pinfo.RedirectStandardOutput = $true
    $pinfo.RedirectStandardError = $true
    $pinfo.FileName = $f1
    $pinfo.Arguments = "$strPwd /D"
    $p = New-Object System.Diagnostics.Process
    $p.StartInfo = $pinfo
    [void]$p.Start()
    $p.WaitForExit()
    $stdout = $p.StandardOutput.ReadToEnd()
    $strtest = "Output = `""
    If ($stdout.Contains($strtest)) {
      $p1 = $stdout.IndexOf($strtest) + $strtest.Length
      $rstr = $stdout.Substring($p1,$stdout.Length-$p1)
      $strTemp = $rstr.Substring(0,$rstr.IndexOf("`""))
    }
  }
  return $strTemp
}

# --------------------------------------------------------------------------------------------------
# --------------------------------------------------------------------------------------------------
# Main
# --------------------------------------------------------------------------------------------------
# --------------------------------------------------------------------------------------------------


$strFilename = "CA_test_script"
$strScriptLog = $STR_LOGFILE_PATH_PREFIX + $strFilename + $STR_LOGFILE_EXTENSION

$strCurrentFolder = Split-Path $MyInvocation.MyCommand.Definition -Parent

Logit "Starting execution, Checking parameters ..."

if (!($UriBase))
{
	ReportAndErrorHandling -intReturnCode $INT_RC_FAILURE `
	-strDescription	"UriBase was not specified."
}
if (!($HostName))
{
	ReportAndErrorHandling -intReturnCode $INT_RC_FAILURE `
	-strDescription	"HostName was not specified."
}
if (!($UserToUpload))
{
	ReportAndErrorHandling -intReturnCode $INT_RC_FAILURE `
	-strDescription	"UserToUpload was not specified."
}
if (!($FunctionOrBusiness))
{
	ReportAndErrorHandling -intReturnCode $INT_RC_FAILURE `
	-strDescription	"FunctionOrBusiness was not specified."
}

if (!($UserName))
{
	ReportAndErrorHandling -intReturnCode $INT_RC_FAILURE `
	-strDescription	"UserName was not specified."
}
if (!($Password))
{
	ReportAndErrorHandling -intReturnCode $INT_RC_FAILURE `
	-strDescription	"Password was not specified."
}
#$CPwd = $Password
$CPwd = GetPlums($Password)

Add-Type @"
    using System.Net;
    using System.Security.Cryptography.X509Certificates;
    public class TrustAllCertsPolicy : ICertificatePolicy {
        public bool CheckValidationResult(
            ServicePoint srvPoint, X509Certificate certificate,
            WebRequest request, int certificateProblem) {
            return true;
        }
    }
"@
[System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy

Add-Type -Language CSharp @"
public class CAReq
{
  public string HostName;
  public string Username;
  public string FunctionOrBusiness;
  public string TeamOrManagedBy;
  public string EncryptedPassword;
  public string Location;
}
"@;

Logit "Uploading to CyberArk: Hostname: $HostName, User Account: $UserToUpload, FunctionOrBusiness: $FunctionOrBusiness, TeamOrManagedBy: $TeamOrManagedBy, Location: $Location"
Logit "Invoking Web Request Post to $UriBase ..."

$Headers = @{"Content-Type" = "application/json"}
$SecurePassword = ConvertTo-SecureString -String $CPwd -AsPlainText -Force
$Credential = new-object -typename System.Management.Automation.PSCredential -argumentlist $Username, $SecurePassword

$CAReq = New-Object CAReq
$CAReq.HostName = $HostName
$CAReq.Username = $UserToUpload
$CAReq.FunctionOrBusiness = $FunctionOrBusiness
$CAReq.TeamOrManagedBy = $TeamOrManagedBy
$CAReq.EncryptedPassword = $PwdToUpload
$CAReq.Location = $Location

$CAReqJson = ConvertTo-Json20 $CAReq 
$CAResp = ""

$request = [System.Net.WebRequest]::Create($UriBase)
$request.ContentType = "application/json"
$request.Method = "POST"
$request.Credentials = $Credential

try
{
    $requestStream = $request.GetRequestStream()
    $streamWriter = New-Object System.IO.StreamWriter($requestStream)
    $streamWriter.Write($CAReqJson)
}
finally
{
    if ($null -ne $streamWriter) { $streamWriter.Dispose() }
    if ($null -ne $requestStream) { $requestStream.Dispose() }
}

$Response = $request.GetResponse()
$ResponseStream = $Response.GetResponseStream()
$StreamReader = New-Object System.IO.StreamReader($ResponseStream)
$CARespJson = $StreamReader.ReadToEnd()

$CAResp = ConvertFrom-Json20 $CARespJson 

Write-Host "See Log file: $strScriptLog for full CyberArk Log"
Logit $CAResp.CyberArkLog $false

if($CAResp.CyberArkErrLog -ne "")
{
    ReportAndErrorHandling -intReturnCode $INT_RC_FAILURE `
    -strDescription	$CAResp.CyberArkErrLog
} else {
  Logit "`nSuccessful upload to CyberArk"
}

$out = $UserToUpload + " password has been reset to $($CAResp.Password)"
    Logit $out

QuitScript $INT_RC_SUCCESS
