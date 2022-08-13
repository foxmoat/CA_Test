# What is CyberArk

CyberArk is an enterprise level password and account management solution capable of account synchronisation, one-time password use with automatic reset and provides triple A framework for credential security management.

The ServerBuild CyberArk implementation can be divided into 3 components:

## 1. ServerBuild Database component

These comprise of the PowerShell script, the Package Binary directory and all associated tasks.

The PowerShell script &quot;CyberArkUpload.ps1&quot; accepts among others 3 critical parameters that are used to determine which configuration file to use when executing the PasswordUpload.exe utility.

These parameters include:

1. FunctionOrBusiness: This parameter is equivalent to the deployment _BusinessLayer_. In the case storing ILO credentials, this is hardcoded to ILO.
2. TeamOrManagedBy: This parameter is equivalent to the _ManagedBy_ attribute of the target OU as configured in Active Directory.
3. Location: This is a recent addition, and is equivalent to the physical location of the server as indicated in the ServerBuild configuration page.

The 3 parameters indicated above are concatenated in the format &quot;.\FunctionOrBusiness\TeamOrManagedBy\Location\&quot; by the ServerBuild WebService, and used to determine which configuration file to load when storing the credentials.

## 2. ServerBuild WebService component

The code for the WebService component is located in the WebAPI GIT [repository](https://stash.dts.fm.foxmoat.net/projects/WINENG/repos/onebuild.webapi/browse?at=refs%2Fheads%2Fmaster) (ServerBuild.WebApi/ServerBuild.WebApi/Controllers/CyberArkController.cs).

The ServerBuild WebService contains logic used to evaluate the target configuration folder and can be surmised as follows:

- If the target directory _&quot;.\FunctionOrBusiness\TeamOrManagedBy\Location\_&quot; exists then the configuration files there are used. If not the next criteria is evaluated.
- If the target directory _&quot;.\FunctionOrBusiness\TeamOrManagedBy\&quot;_ exists then the configuration files there are used. If not the next criteria is evaluated.
- If the target directory _&quot;.\FunctionOrBusiness\Location_\&quot; exists then the configuration files there are used. If not the next criteria is evaluated.
- If the target directory _&quot;.\FunctionOrBusiness\&quot;_ exists then the configuration files there are used. If not, the WebService throws an error.

During execution, the WebService, evaluates the target directory to use, creates a sub-directory with the name of the server being deployed, makes a copy of all the configuration files in the target directory and updates the password.csv file with the necessary information. The web service then executes the PasswordUpload.exe process which performs the actual upload into CyberArk. If the upload is successful, the WebService deletes the created sub-directory and returns the generated password to the ServerBuild service. Whatever the case, the execution is logged both on the ServerBuild server and in the .\FOXMOAT\Logs\ folder of the deployed server.

## 3. ServerBuild Server directory

The ServerBuild server directory structure is used to host the layer specific configuration files. In addition to hosting the WebService, the ServerBuild server also hosts the configuration files used for uploading the credentials.

Those configuration files are hosted in separate directories and depending on which options are selected during deployment, place the credentials in different safes, with different _PolicyIDs_ and on different CyberArk server clusters.

Among the files stored in this location, the following are most critical:

1. _user.ini_ – This file contains encrypted credentials that is used to connect to the CyberArk safe and is usually provided by members of the Security Team during CyberArk safe setup.
2. _Vault.ini_ – This file contains among other things, details of the CyberArk cluster server and port number as well as default connectivity settings.
3. _password.csv_ – This file contains the details of the credentials to store, the safe into which these go, the PolicyID to use, the format for storing the credentials as well as any other parameters required by the business unit when setting up the safe.