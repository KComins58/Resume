$Domain = "@test.local" #Domain that AD is hosted on
$fileserver = "ExampleDC" #File that folders are stored on
$sisexportfile = "C:\Users\Administrator\Desktop\Single Extract.txt" #Textfile with student information that needs to be imported
$emaildomain = "@example.com" #Email suffix #example.com
$withdrawpath = "\\$fileserver\students$\Withdrawn" #The folder storing all withdrawn/suspended students on the server
$OUWithdraw = "OU=Withdrawn,OU=Students,OU=Test,DC=test,DC=local" #The OU storing all withdrawn/suspended students on the AD
$logfilepath = "\\ExampleDC\students$\Changelog\Daily\" #The folder storing the changelog textfiles
$maxFiles = 13 #max number of log files before oldest deletes first - days in our case
$OUExtension = "OU=Students,OU=Test,DC=test,DC=local" #Sets OU, DC of AD

$scriptName = $MyInvocation.MyCommand.Name #retrieves the name of the currently running PowerShell script
$runningInstances = Get-Process | Where-Object { $_.ProcessName -eq "powershell" -and $_.MainModule.FileName -like "*$scriptName" } #retrieve a list of running processes, checks if the process name is "powershell, checks if the process's main module filename matches the current script's name.

if ($runningInstances) { #If running instances
    $runningInstances | Stop-Process -Force #stop them so no conflicting scripts are ran
}

$month = Get-Date -Format "MM"
$dateyear = Get-Date -Format "yyyy"

function get-year ($currentgrade) {
    if ($month -ge '6') {
        $year = [int]$dateyear + 1
    } else {
        $year = [int]$dateyear
    }

    $result = $year  # Initialize the result variable with the given year

    if ($currentgrade -eq "PA" -or $currentgrade -eq "PP") {
        $result += 13  # Add 13 years to the result if the current grade is "PA" or "PP"
    } 
    elseif ($currentgrade -eq "K"){
        $result += 12  # Add 12 years to the result if the current grade is "K"       
    }
    else {
        $result += (12 - $currentgrade)  # Add the remaining years based on the current grade
    }

    return [string]$result  # Return the calculated year
}

$grade = @{}
$orgunits = @{}
for ($i = 1; $i -le 12; $i++) {
    $currentGrade = $i.ToString().PadLeft(2, '0')
    $year = get-year $currentGrade
    $grade[$currentGrade] = $year
    $orgunits[$currentGrade] = "OU="+$year+","
}

$grade["K"] = get-year "K"; $orgunits["K"] = "OU="+$grade["K"]+","
$grade["PP"] = get-year "PP"; $orgunits["PP"] = "OU="+$grade["PP"]+","
$grade["PA"] = get-year "PA"; $orgunits["PA"] = "OU="+$grade["PA"]+","

#Create a map of codes to Active  Directory OUs where students should be moved/created etc. Student grade to grad year mapping.
$date = Get-Date -Format "yyyy-MM-dd HH-mm" #Current date/time in the format that textfiles will be named in
$UserPerm = $Domain.Substring(1) #permissions are the domain without the @. If they are different names, change accordingly

$files = Get-ChildItem -Path $logfilepath | Where-Object { !$_.PSIsContainer } | Sort-Object CreationTime #Get the textfile names within the logfile folder and order by creationtime
if ($files.Count -gt $maxFiles) { #Checks if there are more txt files in the changelog folder than is allowed
    $deleteCount = $files.Count - $maxFiles #Calculates how many to delete based on number existing - how many are allowed
    for ($i = 0; $i -lt $deleteCount; $i++) { #For loop from 0 -> How many to delete
        $oldestFile = $files[$i] #Oldest file is the 1 that is in the lowest index position
        Write-Host "`nDeleted: $($oldestFile.FullName)`n" #Write to log which files were deleted
        Remove-Item -Path $oldestFile.FullName #Remove the file
    }
}
try { #Incase transcript wasn't stopped last time
    Stop-Transcript
}
catch { #Do not display error code saying transcript doesn't exist
}
Start-Transcript -Path "$logfilepath$date.txt" #Start noting the changes that occur, they are stored during write-host
Import-Module ActiveDirectory # Import the Active Directory functions

# Import the Data - This is based on using the accompanying SISsync.sql file to extract data from PowerSchool and expects a tab delimited file, if you're using a CSV from another system or autosend, change `t to , (or omit the delimiter option entirely) and modify the headers appropriately
$sisfile = Import-Csv -delimiter "`t" -Path $SisExportFile -header "givenName","sn","lunchpin","grade","studentid","status","aup","suspended"

$NotPresent = $sisfile.studentid

#Start Processing per file line
foreach ($sisline in $sisfile) { #Read from textfile line by line
    $gradyear = $grade.Get_Item($sisline.Grade) #Set graduation years
    $path = $orgunits.Get_Item($sisline.Grade) + "$OUExtension" #set the path variable to the OU the student should end up in. In the example below the AD OU Structure is Schools -> Schoolname -> Students
    $sn = $sisline.sn #Set username
    $givenName = $sisline.givenName #Set given name
    $firstinitial = $givenName[0] #Set first initial
    $i = 0 #Set number of initals for for-loop
    $sAMAccountName = (($gradyear + $firstinitial + $sn) -replace " ", "" -replace "\.\.", "." -replace "'", "" -replace "-", "" -replace "ó", "o" -replace ",", "" -replace "í", "i" ).ToLower() #Remove unnecessary characters/change to common ones then lower into uniform format
    $OriginalsAMAccountName = $existinguser.SamAccountName
    $userPrincipalName = "$sAMAccountName$Domain" #Set the UPN of the student Example@Example.com   
	if (Get-ADUser -Filter "UserPrincipalName -eq '$userPrincipalName'") { # Increase the substring length until a unique UPN is found
        while (Get-ADUser -Filter "UserPrincipalName -eq '$userPrincipalName'") { #While the UPN isn't unique
            $i++ #Increase # of initials
            $sAMAccountName = (($gradYear + $givenName.Substring(0,$i) + $sn) -replace " ", "" -replace "\.\.", "." -replace "'", "" -replace "-", "" -replace "ó", "o" -replace ",", "" -replace "í", "i").ToLower() #Increase initials in first name
            $userPrincipalName = $sAMAccountName + $domain #Set UPN
        }
    }
    if ($sAMAccountName.length -gt 20){$sAMAccountName = $sAMAccountName.substring(0,20)} #AD can only hold 20 characters. If you substring a word less than 20 characters it threw up an error 
    $name = (($sisline.givenName + " " + $sisline.sn) -replace "\.\.", "." -replace "'", "" -replace "-", "" -replace "ó", "o" -replace ",", "" -replace "í", "i").ToUpper() #Set the displayname (Capatilized) for the account in AD Firstname Lastname
    $pass = "Owls" + $sisline.lunchpin #Set a password for the account
	$password = ConvertTo-SecureString -AsPlainText $pass -Force #Set the password to a secure string
	$mail = "$sAMAccountName$emaildomain" #Set the mail attribute for the account (if desired, usually helpful if you're synchronizing to Google Apps/Office 365)
    $displayname = $sisline.givenname + " " + $sisline.sn + " " + "(" + $gradyear + ")" #Set displayname Name Surname (Gradyear)
    $status = $sisline.status #Set status
    $aup = $sisline.aup #Set aup
    $suspended = $sisline.suspended #set suspended
    if ($aup -eq $null -or $aup -eq "") {$aup = $true} #if aup is empty, assume its true
    if ($status -eq $null -or $status -eq "") {$status = $true}  #if status is empty, assume its true
    if ($suspended -eq "") {$suspended = $false}  #if suspended is empty, assume its false
    if ($suspended -eq $true) {$status = $false}  #if status is true, run same commands as status=false as it moves to withdrawn and disables
	$employeeID = $sisline.studentid #Store student ID in AD's "EmployeeID" attribute
	$c = "US"#Optional location attributes, helpful if syncing to Moodle via LDAP
	$co = "United States" #Optional location attributes, helpful if syncing to Moodle via LDAP
	$physicalDeliveryOfficeName = $sisline.grade #Set office i.e. which Grade students are in
	$description = "Class of $gradyear Student User" #Set description which tells us gradyear
	#Create a hashtable of all the "otherattributes" this is used when we create/update the user - this makes it easier to call in statement
	$otherAttributes = @{'userPrincipalName' = "$userPrincipalName";  'mail' = "$mail"; 'givenName' = "$givenName"; 'sn' = "$sn"; 'DisplayName' = "$displayname"; 'employeeID' = "$employeeID"; 'employeenumber' = "$pass"; 'c' = "$c"; 'physicalDeliveryOfficeName' = "$physicalDeliveryOfficeName"; 'description' = "$description"}
	$otherAttributes.description = [string]$otherAttributes.description #recast description as a string because AD commands require it and it gets converted to int if it's all numeric.
    if (-not $employeeID.StartsWith('9999')) { #9999 is a generic one that is used when a new student is added
        $existingUser = Get-ADUser -Filter "EmployeeID -eq '$employeeID'" #Check if student exists by seaching if ID is unique
        if ($existingUser -ne $null) { #If a user already exists run code snippet
            $changes = $false #Set if there are any changes made so no unnecessary running of below code
            $existingPath = (Get-ADUser -Identity $existingUser.SamAccountName -Properties HomeDirectory).HomeDirectory #Get the existing user's home directory path
            if ($existingPath -ne $null) {$existingYear = (Split-Path -Path $existingPath -Parent).Split("\")[-1]} #Check if home directory path is valid then extract the year from the home directory path \\Server\students$\gradyear\studentfolder
            if ($HomeDirectory -notlike '*Withdrawn*') {Remove-ADGroupMember "Grad$existingYear" $existingUser -Confirm:$false}
            if (($existingUser.Name) -ne $name) {$newname = $name; $newsAMAccountName = $sAMAccountName; $changes = $true} else {$newname = $existingUser.Name; $newsAMAccountName = $existingUser.SamAccountName} #If Name is changed, set changed to true to run script and assign values to new variables
            if ($existingUser.Surname -ne $sn) {$newlastname = $sn; $newsAMAccountName = $sAMAccountName; $changes = $true} else {$newlastname = $existingUser.surname; $newsAMAccountName = $existingUser.SamAccountName} #If Surname is changed, set changed to true to run script and assign values to new variables
            if ($existingyear -ne $gradyear) {$newyear = $gradyear; $newsAMAccountName = $sAMAccountName; $changes = $true} else {$newyear = $existingyear; $newsAMAccountName = $existingUser.SamAccountName} #If GradYear is changed, set changed to true to run script and assign values to new variables
            if ($changes -eq $true -and $status -eq $true){ #Run script if changes were made and status is true. No changes should be made if status is false
                $user = Get-ADUser -Identity $existingUser -Properties proxyAddresses #Get proxy address property to update
                Set-ADUser -Identity $existingUser -Add @{proxyAddresses=$existingUser.SamAccountName+$emaildomain} #Set proxy addresses so that a changed user will still recieve their old emails
                $newpath = "CN=$newname,OU=$newyear,$OUExtension" #Set path to the old user name in the new year in OU
                $i = 0 #This sets the number of characters the first inital will be - 1
                $sAMSearch = $newsAMAccountName #Set the varaible to search against to confirm it doesn't already exist
                while (((Get-ADUser -Filter {sAMAccountName -eq $sAMSearch} -SearchBase "OU=$newyear,$OUExtension") -ne $null) -and ($newsAMAccountName -ne $OriginalsAMAccountName)) { #Run loop to check that it doesnt exist
                    $newsAMAccountName = (("$newyear"+$newname.substring(0,$i+1)+"$newlastname" ) -replace " ", "" -replace "\.\.", "." -replace "'", "" -replace "-", "" -replace "ó", "o" -replace ",", "" -replace "í", "i").ToLower() #Remove unnecessary characters/change to common ones then lower into uniform format
			        $sAMSearch = $newsAMAccountName #Set the variable to search against as newname[0,i+1]
                    $i++ #Increase i
                } 
                $testpath = "CN="+$existinguser.Name+",OU=$newyear,$OUExtension" #Change path in OU to new user name
                $newhomedirectory = "\\$fileserver\students$\$newyear\$newsAMAccountName" #Where the new homedirectory will be located -either changed based on name change or location change 
                $mail = "$newsAMAccountName$emaildomain" #Set the mail attribute for the account (if desired, usually helpful if you're synchronizing to Google Apps/Office 365)
                if ($newsAMAccountName -ne $OriginalsAMAccountName) {      
                    Move-Item -Path $existingPath -Destination $newhomedirectory -Force #Move homedirectory folder to newhomedirectory folder
                    Move-ADObject -Identity $existinguser -TargetPath $path #Move OU in AD to new OU position
                    Rename-ADObject -Identity $testpath -NewName $newname #Rename OU in AD
                    Set-ADUser -Identity $newpath -userPrincipalName $newsAMAccountName -givenName $givenName -EmailAddress $mail -Surname $sn -SamAccountName $newsAMAccountName -DisplayName $displayname -HomeDirectory $newhomedirectory -Description $description -Office $sisline.Grade #Update all the places that may have been changed. i.e email needs to change with name and gradyear
                    Write-Host "`nHome directory: $existingPath -> $newhomedirectory`nAD: $existingUser -> $path`nNew Name: $newpath -> $name`n" #Write-Host adds to changelog
                } else {
                    Set-ADUser -Identity $existingUser.DistinguishedName -GivenName $givenName -EmailAddress $mail -Surname $sn -DisplayName $displayName -Description $description -HomeDirectory $newhomedirectory -Office $sisline.Grade
                    Rename-ADObject -Identity $existingUser.DistinguishedName -NewName $newname #Rename OU in AD # Rename the OU in Active Directory 
                    Move-Item -Path $existingPath -Destination $newhomedirectory -Force #Move homedirectory folder to newhomedirectory folder
                }
                $homepath = "\\$fileserver\students$\$newyear\$newsAMAccountName" #Use these variables in further calculations but depend on whether changes were made or not
                $distinguishedname = "CN=$newname,OU=$newyear,$OUExtension" #Use these variables in further calculations but depend on whether changes were made or not
                $path = $newpath #Use these variables in further calculations but depend on whether changes were made or not
                $statyear = $newyear #Use these variables in further calculations but depend on whether changes were made or not
            }
            else {
                $homepath = "\\$fileserver\students$\$gradyear\$newsAMAccountName" #Use these variables in further calculations but depend on whether changes were made or not
                $distinguishedname = $existingUser.DistinguishedName #Use these variables in further calculations but depend on whether changes were made or not
                $path = $orgunits.Get_Item($sisline.Grade) + "$OUExtension" #Use these variables in further calculations but depend on whether changes were made or not
                $newsAMAccountName = $existingUser.SamAccountName #Use these variables in further calculations but depend on whether changes were made or not
                $statyear = $existingyear #Use these variables in further calculations but depend on whether changes were made or not
            }
            if (($existingUser.DistinguishedName -notlike '*Withdrawn*') -and $status -eq $false) { #Check that the path exists and if status is false (Status = False / Suspended = True)
                Move-Item -Path $existingpath -Destination $withdrawpath -Force #Move homedirectory folder to withdrawpath folder
                Move-ADObject -Identity $distinguishedname -TargetPath $OUWithdraw #Move OU in AD to new OU position in Withdraw OU
                $distinguishedname = "CN=$newname,OU=Withdrawn,$OUExtension" #Use these variables in further calculations
                Set-ADUser -Identity $distinguishedname -HomeDirectory $withdrawpath #Move homedirectory folder to withdraw folder
                Write-Host "Home directory: $existingPath -> $withdrawpath`nAD: $distinguishedname -> $OUWithdraw`n" #Write-Host adds to changelog
            }
            elseif (($existingUser.DistinguishedName -like '*Withdrawn*') -and ($status -eq $true)){ #Check that the path exists and if status is true (Status = True & Suspended = False)
                Move-Item -Path "$withdrawpath\$newsAMAccountName" -Destination $homepath -Force #Move homedirectory folder to gradyear folder
                Move-ADObject -Identity $distinguishedname -TargetPath $path  #Move OU in AD to new OU position in Gradyear OU
                $distinguishedname = "CN=$newname,OU=$statyear,$OUExtension" #Use these variables in further calculations
                Set-ADUser -Identity $distinguishedname -HomeDirectory $homepath #Move homedirectory folder to gradyear folder
                Write-Host "Home directory: $withdrawpath\$newsAMAccountName -> $homepath`nAD: $distinguishedname -> $path`n" #Write-Host adds to changelog
            } 
        }elseif ($existingUser -eq $null) {#If employeeID starts with 9999 skip creation.
                write-host "1:$path 2:$sAMAccountName 3:$name"
                New-ADUser -sAMAccountName $sAMAccountName -Name $name -Path $path -otherAttributes $otherAttributes -Enabled $true -CannotChangePassword $true -PasswordNeverExpires $true -AccountPassword $password #create user using $sAMAccountName and set attributes and assign it to the $user variable
	            $newyear = $gradyear
                $homepath = "\\"  + $fileserver + "\students$\$gradyear\" + $sAMAccountName  #The example below assumes student home folders exist in a \\ExampleDC\student$\username structure
	            if ((Test-Path ($homepath)) -ne $true){ #If path doesn't exist already
		            New-Item -ItemType directory -Path $homepath #creates a new directory at the path specified
		            $acl = Get-Acl $homepath #retrieves the access control list 
		            $permission = "$UserPerm\$sAMAccountName","Modify","ContainerInherit,ObjectInherit","None","Allow" #sets the $permission variable to an array
		            $accessRule = New-Object System.Security.AccessControl.FileSystemAccessRule $permission #creates a new file system access rule object using $permission
		            $acl.SetAccessRule($accessRule) #adds the newly created access rule to the access control list 
		            $acl | Set-Acl $homepath #sets the updated access control list
	            }
                $existingUser = Get-ADUser -Filter "EmployeeID -eq '$employeeID'" #Check if student exists by seaching if ID is unique
                if ($status -eq $false) { #If status = false & suspended = true
                    Move-Item -Path $homepath -Destination $withdrawpath -Force # Move the directory on the server
                    Set-ADUser -Identity $existingUser.DistinguishedName -HomeDirectory ($withdrawpath+"\"+$existingUser.SamAccountName) -SamAccountName $existingUser.SamAccountName #Change properties in AD
                    Move-ADObject -Identity $existingUser.DistinguishedName -TargetPath $OUWithdraw #Move AD t to Withdrawn OU
                    Write-Host "Home directory: $homepath -> $withdrawpath`nAD: "$existingUser.DistinguishedName" -> $OUWithdraw`n" #Write-Host adds to changelog
                } elseif ($status -eq $true) { #If status = true & suspended = false
                    Set-ADUser -Identity $existingUser -HomeDirectory $homepath -HomeDrive "U:" #Set Homefirectory folder in the AD
                    Write-Host "Home directory: $homepath`n" #Write-Host adds to changelog
                }
            }
        $user = Get-ADUser -Filter {employeeID -eq $employeeID} #Set existing user if ID exists
        if ($user -ne $null) { #Make sure $user isn't null so it doesn't throw up error codes
            if ($aup -eq $true -and $status -eq $true) {Set-ADUser -Identity $user.DistinguishedName -Enabled $true #If $aup and $status = true and suspended = false, enable account in AD
               }elseif ($aup -ne $true -or $status -ne $true) {Set-ADUser -Identity $user.DistinguishedName -Enabled $false} #If $aup and $status = false and suspended = true, disable account in AD
        }
    }
    $ADUsers = Get-ADUser -Filter * -SearchBase $OUExtension -Properties HomeDirectory, EmployeeID, SamAccountName #Get the list of AD users
    foreach ($ADUser in $ADUsers) { #Iterate through each AD user
        $SamAccountName = $ADUser.SamAccountName
        $employeeID = $ADUser.EmployeeID #Set employeeID
        $HomeDirectory = $ADUser.HomeDirectory #Set Homedirectory
        $DistinguishedName = $ADUser.DistinguishedName
        $gradyear = ((Split-Path -Path $HomeDirectory -Parent).Split("\"))[-1]
        if ($status -eq $true) {Add-ADGroupMember "Grad$gradyear" $DistinguishedName} #Add to appropriate gradyear ADgroup if they aren't in withdrawn
        if ($employeeID -notin $NotPresent -and $HomeDirectory -notlike '*Withdrawn*') {
            Move-Item -Path $HomeDirectory -Destination $withdrawpath -Force
            Set-ADUser -Identity $DistinguishedName -HomeDirectory ($withdrawpath+"\"+$SamAccountName) -SamAccountName $SamAccountName #Change properties in AD
            Move-ADObject -Identity $DistinguishedName -TargetPath $OUWithdraw #Move AD t to Withdrawn OU
            Write-Host "Not Found in sisfile`nHome directory: $HomeDirectory -> $withdrawpath`nAD: $DistinguishedName -> $OUWithdraw`n" #Write-Host adds to changelog
        }
    }
}

Stop-Transcript #End log taking
