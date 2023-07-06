$Domain = "@test.local" #Domain that AD is hosted on
$fileserver = "ExampleDC" #Server name
$emaildomain = "@Example.com" #Email suffix @example.com
$OUExtension = "OU=Test,DC=test,DC=local" #Sets OU, DC of AD
$sisexportfilestaff = "C:\Users\Administrator\Desktop\staffexport.csv" #Textfile with staff information that needs to be imported
$password = ConvertTo-SecureString -AsPlainText "Example1234" -Force #Set the password to a secure string. Original password for staff is pre-set and changed on first logon
$webUrl = "https://docs.google.com/spreadsheets/d/e/Example/pubhtml"
$scriptName = $MyInvocation.MyCommand.Name #retrieves the name of the currently running PowerShell script
$runningInstances = Get-Process | Where-Object { $_.ProcessName -eq "powershell" -and $_.MainModule.FileName -like "*$scriptName" } #retrieve a list of running processes, checks if the process name is "powershell, checks if the process's main module filename matches the current script's name.
$logfilepath = "\\ExampleDC\Changelog\Daily\" #The folder storing the changelog textfiles  WARNING WILL DELETE ALL BUT 13 files in this location. MAKE SEPARATE LOG LOCATION.
$maxFiles = 13 #max number of log files before oldest deletes first - days in our case
$UserPerm = $Domain.Substring(1) #permissions are the domain without the @. If they are different names, change accordingly
$UnknownOU = "OU=Unknown,OU=Test,DC=test,DC=local"
$UnknownFolder = "\\ExampleDC\Unknown"

$date = Get-Date -Format "yyyy-MM-dd HH-mm" #Current date/time in the format that textfiles will be named in
$files = Get-ChildItem -Path $logfilepath | Where-Object { !$_.PSIsContainer } | Sort-Object CreationTime #Get the textfile names within the logfile folder and order by creationtime
try { #Incase transcript wasn't stopped last time
    Stop-Transcript
}

catch { #Do not display error code saying transcript doesn't exist
}

if ($files.Count -gt $maxFiles) { #Checks if there are more txt files in the changelog folder than is allowed
    $deleteCount = $files.Count - $maxFiles #Calculates how many to delete based on number existing - how many are allowed

    for ($i = 0; $i -lt $deleteCount; $i++) { #For loop from 0 -> How many to delete
        $oldestFile = $files[$i] #Oldest file is the 1 that is in the lowest index position
        Write-Host "`nDeleted: $($oldestFile.FullName)`n" #Write to log which files were deleted
        Remove-Item -Path $oldestFile.FullName #Remove the file
    }
}
Start-Transcript -Path "$logfilepath$date.txt" #Start noting the changes that occur, they are stored during write-host

Import-Module ActiveDirectory # Import the Active Directory functions

if ($runningInstances) { #If running instances
    $runningInstances | Stop-Process -Force #stop them so no conflicting scripts are ran
}

function UniqueTest($sAMAccountName, $givenName, $sn, $employeeid) { #Function that tests if sAMAccountName is unique, as it gets used in the UPN
    $i = 0 #Set counter
    $existinguser = (Get-ADUser -Filter "employeeid -eq '$employeeid'") #Get existing users sAMAccountName based off employeeid
    
    while ((Get-ADUser -Filter "sAMAccountName -eq '$sAMAccountName'") -and ($existinguser.sAMAccountName -ne $sAMAccountName)) { #Repeat until the sAMAccountName is unique or remains the same as it currently is / the and for is if you are updating a user
        $i++ #Increase counter
        $sAMAccountName = (($givenName.Substring(0, $i) + $sn) -replace " ", "" -replace "\.\.", "." -replace "'", "" -replace "-", "" -replace "ó", "o" -replace ",", "" -replace "í", "i").ToLower() #Create a new sAMAccountName with an additional initial
    }

    return $sAMAccountName #Return the function value to where it was called
}

function HomePath($position) { #get the correct folder/OU names
    switch ($position.ToLower())
    {
        "teacher" {return "Teacher"} #All teachers
        "instructional coaches" {return "Teacher"} #All instructional coaches
        "counselor" {return "Office"} #All counselor
        "custodial" {return "Support Staff"} #All custodial
        "kitchen" {return "Support Staff"} #All kitchen
        "maintenance" {return "Support Staff"} #All maintenance
        "nurse" {return "Office"} #All nurse
        "secretary" {return "Office"} #All secretary
        "bus driver" {return "Support Staff"} #All bus driver
        "principal" {return "Office"} #Principle
        "asst principal" {return "Office"} #asst principal

        default {return "Unknown"} #Otherwise causes an error if they have a position that hasn't been added
    }

}

function AddToGroups($employeeID,$position,$office,$accesslvl){ #Add a user to the appropriate email groups
    $existingUser = Get-ADUser -Filter "EmployeeID -eq '$employeeID'" -Properties * #Get the employee that was just created/updated
    Get-ADPrincipalGroupMembership $existingUser | Where-Object { $_.Name -ne "Domain Users" -and $_.Name -ne "911notifier" -and $_.Name -ne "Erate" -and $_.Name -ne "FMP" -and $_.Name -ne "Example Board of Education" -and $_.Name -ne "District Admin Team" -and
    $_.Name -ne "District ELL Teachers" -and $_.Name -ne "District Special Services" -and $_.Name -ne "SCCC Practical Nursing"} | ForEach-Object { Remove-ADGroupMember -Identity $_ -Members $existingUser -Confirm:$false }
    #office is building, position is admin/teacher/etc
    Add-ADGroupMember -Identity "Example Public Schools" -Members $existingUser #Add all to Example Public schools group
    Add-ADGroupMember -Identity "guest_wireless" -Members $existingUser #Add all to guest_wireless
    $offices = $office.ToUpper().Split(',') -replace " ", "" #If a staff member goes between multiple buildings, seperate by , #toupper so that it isn't case sensitive
    switch ($accesslvl) {
        "District-All_Access" {Add-ADGroupMember -Identity "District-All_Access" -Members $existingUser}
        "ACCESS-HS-Alltime" {Add-ADGroupMember -Identity "ACCESS-HS-Alltime" -Members $existingUser}
        "ACCESS-HS-Limited" {Add-ADGroupMember -Identity "ACCESS-HS-Limited" -Members $existingUser}
        "ACCESS-MS-Alltime" {Add-ADGroupMember -Identity "ACCESS-MS-Alltime" -Members $existingUser}
        "ACCESS-MS-Limited" {Add-ADGroupMember -Identity "ACCESS-MS-Limited" -Members $existingUser}
        "ACCESS-SC-Alltime" {Add-ADGroupMember -Identity "ACCESS-SC-Alltime" -Members $existingUser}
        "ACCESS-SC-Limited" {Add-ADGroupMember -Identity "ACCESS-SC-Limited" -Members $existingUser}
        "ACCESS-BF-Alltime" {Add-ADGroupMember -Identity "ACCESS-BF-Alltime" -Members $existingUser}
        "ACCESS-BF-Limited" {Add-ADGroupMember -Identity "ACCESS-BF-Limited" -Members $existingUser}
        "ACCESS-SB-Alltime" {Add-ADGroupMember -Identity "ACCESS-SB-Alltime" -Members $existingUser}
        "ACCESS-SB-Limited" {Add-ADGroupMember -Identity "ACCESS-SB-Limited" -Members $existingUser}
    }

    foreach ($officeCode in $offices) { #loop number of times needed for the groups the user is in
        switch ($officeCode.Trim()) {
            "BE" {Add-ADGroupMember -Identity "Benton Elementary" -Members $existingUser} #Benton Elementary
            "EW" {Add-ADGroupMember -Identity "Eastwood Elementary" -Members $existingUser} #Eastwood Elementary
            "SB" {Add-ADGroupMember -Identity "Spainhower Primary School" -Members $existingUser} #Spainhower Primary School
            "SC" {Add-ADGroupMember -Identity "Saline County Career Center" -Members $existingUser} #Saline County Career Center
            "HS" {Add-ADGroupMember -Identity "Example High School" -Members $existingUser} #Example High School
            "MS" {Add-ADGroupMember -Identity "Bueker Middle School" -Members $existingUser} #Bueker Middle School
            "BF" {Add-ADGroupMember -Identity "Butterfield ECC" -Members $existingUser} #Butterfield ECC
            "CO" {Add-ADGroupMember -Identity "District Central Office" -Members $existingUser} #District Central Office
            "NW" { Add-ADGroupMember -Identity "Northwest School" -Members $existingUser} #Northwest School
            "IA" { Add-ADGroupMember -Identity "Industrial Arts" -Members $existingUser} #Industrial Arts
            "DC" { Add-ADGroupMember -Identity "Distribution Center" -Members $existingUser} #Distribution Center
            "TLC" { Add-ADGroupMember -Identity "TLC" -Members $existingUser} #TLC
            default { Write-Host "Invalid office code: $officeCode"} #If they have an unknown office code
        }
    }

    switch ($position.ToLower()) #tolower so that it isn't case sensitive
    {
        "teacher" {Add-ADGroupMember -Identity "Classroom Teachers" -Members $existingUser} #All teachers
        "instructional coaches" {Add-ADGroupMember -Identity "Instructional Coaches" -Members $existingUser} #All instructional coaches
        "counselor" {Add-ADGroupMember -Identity "District Counselors" -Members $existingUser} #All counselor
        "custodial" {Add-ADGroupMember -Identity "District Custodians" -Members $existingUser} #All custodial
        "kitchen" {Add-ADGroupMember -Identity "District Food Service" -Members $existingUser} #All kitchen
        "maintenance" {Add-ADGroupMember -Identity "District Maintenance" -Members $existingUser} #All maintenance
        "nurse" {Add-ADGroupMember -Identity "District Nurses" -Members $existingUser} #All nurse
        "secretary" {Add-ADGroupMember -Identity "District Secretaries" -Members $existingUser} #All secretary
        "bus driver" {Add-ADGroupMember -Identity "District Transportation Department" -Members $existingUser} #All bus driver
    }
}

function UpdateADUser($employeeID,$office,$sAMAccountName,$name,$givenname,$mail,$sn,$displayname,$newhomedirectory,$position,$userPrincipalName){
    $existingUser = Get-ADUser -Filter "EmployeeID -eq '$employeeID'" -Properties * #Get matching user data according to employeeid
    $storage = HomePath $position #Get the folder/ou to put the user in
    $offices = $office.ToUpper().Split(',') -replace " ", "" #If a staff member goes between multiple buildings, separate by , #toupper so that it isn't case sensitive
    $onlyoffice = $offices[0]

    if ($storage -eq "Support Staff") {
        $onlyoffice = $position
    }
    $path = "OU="+$onlyoffice+",OU="+$storage+","+$OUExtension #1:OU=2034,OU=Students,OU=Test,DC=test,DC=local 2:2034ccheck 3:CHECK01 CHECK
    $testpath = "CN="+$existinguser.Name+",OU="+$onlyoffice+",OU=$storage,$OUExtension" #Change path in OU to new user name
    $newhomedirectory = "\\$fileserver\$storage$\$sAMAccountName" #Where the new homedirectory will be located -either changed based on name change or location change

    if ("CN=$name,$path" -ne $existinguser) {
        if ($name -ne $existingUser.name)
        {
            Set-ADUser -Identity $existingUser -Add @{proxyAddresses = $existingUser.mail } #Set proxy addresses so that a changed user will still recieve their old emails   
            Move-Item -Path $existingUser.HomeDirectory -Destination $newhomedirectory -Force #Move homedirectory folder to newhomedirectory folder
        }
        Move-ADObject -Identity $existinguser -TargetPath $path #Move OU in AD to new OU position
        Rename-ADObject -Identity $testpath -NewName $name #Rename OU in AD
        Set-ADUser -Identity "CN=$name,$path" -userPrincipalName $userPrincipalName -givenName $givenName -EmailAddress $mail -Surname $sn -SamAccountName $sAMAccountName -DisplayName $displayname -HomeDirectory $newhomedirectory -Description $position -Office $office -Enabled $true #Set all the attributes for th user
        write-host ("$name moved from "+$existingUser.homedirectory+" to $newhomedirectory") #For log taking
    }
}

function ChangeEntry($office){
     switch ($office) {
            "Benton" {return "BE"} #Benton Elementary
            "Eastwood" {return "EW"} #Eastwood Elementary
            "SB" {return "SB"} #Spainhower Primary School
            "SCCC" {return "SC"} #Saline County Career Center
            "High School" {return "HS"} #Example High School
            "BMS" {return "MS"} #Bueker Middle School
            "Butterfield" {return "BF"} #Butterfield ECC
            "Central Office" {return "CO"} #District Central Office
            "Northwest" {return "NW"} #Northwest School
            "Industrial Arts" {return "IA"} #Industrial Arts
            "Distribution Center" {return "DC"} #Distribution Center
            "TLC" {return "TLC"} #TLC
        }
}
function AddADUser($sAMAccountName,$name,$otherAttributes,$position,$password,$office){
    $storage = HomePath $position #Get the folder/ou to put the user in
    $offices = $office.ToUpper().Split(',') -replace " ", "" #If a staff member goes between multiple buildings, separate by , #toupper so that it isn't case sensitive
    $onlyoffice = $offices[0]
    if ($storage -eq "Support Staff") {
        $onlyoffice = $position
    }
    $path = "OU="+$onlyoffice+",OU="+$storage+","+$OUExtension #1:OU=2034,OU=Students,OU=Test,DC=test,DC=local 2:2034ccheck 3:CHECK01 CHECK
    $homepath = "\\"  + $fileserver + "\"+ $storage + "$\" + $sAMAccountName  #The example below assumes student home folders exist in a \\ExampleDC\student$\username structure
    New-ADUser -sAMAccountName $sAMAccountName -Name $name -Path $path -Enabled $true -CannotChangePassword $false -ChangePasswordAtLogon $true -AccountPassword $password -OtherAttributes $otherAttributes -HomeDirectory $homepath -HomeDrive "H:"#create user using $sAMAccountName and set attributes and assign it to the $user variable

    if ((Test-Path ($homepath)) -ne $true){ #If path doesn't exist already
		New-Item -ItemType directory -Path $homepath #creates a new directory at the path specified
		$acl = Get-Acl $homepath #retrieves the access control list 
		$permission = "$UserPerm\$sAMAccountName","Modify","ContainerInherit,ObjectInherit","None","Allow" #sets the $permission variable to an array
		$accessRule = New-Object System.Security.AccessControl.FileSystemAccessRule $permission #creates a new file system access rule object using $permission
		$acl.SetAccessRule($accessRule) #adds the newly created access rule to the access control list 
		$acl | Set-Acl $homepath #sets the updated access control list
	}
    write-host "Created user: $name at $homepath"
}

$TextInput = New-Object System.Management.Automation.Host.ChoiceDescription '&Textfile', 'Input Type: Textfile' #Choice option for reading from textfile
$UserInput = New-Object System.Management.Automation.Host.ChoiceDescription '&User Input', 'Input Type: User' #Choice option for reading from user input
$options = [System.Management.Automation.Host.ChoiceDescription[]]($TextInput, $UserInput) 
$title = 'Input Type'
$message = 'How would you like data to be entered?'
$result = $host.ui.PromptForChoice($title, $message, $options, 0)

switch ($result)
{
    0 {#Read from textfile
        $response = Invoke-WebRequest -Uri $weburl #Get the input from the weburl
        $doc = $response.ParsedHtml # Parse the HTML content
        $table = $doc.getElementsByTagName("table") | Select-Object -First 1 #Read the table from weburl
        $rows = $table.getElementsByTagName("tr") #Read the rows from the table from weburl
        $extractedInfo = @() # Create an array to store the extracted information
        
        foreach ($row in $rows) { # Loop through the rows and extract the desired information
            $columns = $row.getElementsByTagName("td") | Select-Object -ExpandProperty innerText 
            if ($columns) {
                $info = $columns[0..5] -join "`t" #create lines with tabs seperating info
                $extractedInfo += $info
            }
        } 
        $extractedInfo | Out-File -FilePath $sisexportfilestaff # Save the extracted information to a text file
        $sisfile = Import-Csv -delimiter "`t" -Path $sisexportfilestaff -header "givenName","sn","position","office","employeeid","accesscard","AccessLvl" #Read from the saved textfile from the online csv file
        $i = 0;
        foreach ($sisline in $sisfile) { #Read from textfile line by line

            if ($i -ne 0) {
                $givenName = $sisline.givenName #Set given name
                $sn = $sisline.sn #Set username
                $position = $sisline.position #Position
                $office = ChangeEntry ($sisline.office) #Building they work in
                $employeeid = $sisline.employeeid #EmployeeID
                $accesscard = $sisline.accesscard #accesscard
                $sAMAccountName = UniqueTest (($givenName[0] + $sn) -replace " ", "" -replace "\.\.", "." -replace "'", "" -replace "-", "" -replace "ó", "o" -replace ",", "" -replace "í", "i" ).ToLower() $givenName $sn $employeeid #Remove unnecessary characters/change to common ones then lower into uniform format
                $userPrincipalName = "$sAMAccountName$Domain" #Set User principle name 
                $mail = "$sAMAccountName$emaildomain" #Set the mail attribute for the account (if desired, usually helpful if you're synchronizing to Google Apps/Office 365)
                $displayname = "$givenName $sn" #Set display name
                $name = ($displayname -replace "\.\.", "." -replace "'", "" -replace "-", "" -replace "ó", "o" -replace ",", "" -replace "í", "i").ToUpper()
                $accesslvl = $sisline.AccessLvl
                $otherAttributes = @{'userPrincipalName' = "$userPrincipalName"; 'mail' = "$mail"; 'givenName' = "$givenName"; 'sn' = "$sn"; 'DisplayName' = "$displayname"; 'employeeID' = "$employeeID"; 'physicalDeliveryOfficeName' = "$office"; 'description' = "$position"; 'HomePhone' = $accesscard}
                $otherAttributes.description = [string]$otherAttributes.description #Needs to be a string for AD
                
                if ((Get-ADUser -Filter "EmployeeID -eq '$employeeID'") -eq $null) { #If new user - add
                    ADDADUser $sAMAccountName $name $otherAttributes $position $password $office
                } else { #if current user - update
                    UpdateADUser $employeeID $office $sAMAccountName $name $givenname $mail $sn $displayname $newhomedirectory $position $userPrincipalName
                }
                AddToGroups $employeeID $position $office #Add user to appropraite groups   
            }
            $i = 1   
        }
    }
    1 {
        $givenName = Read-Host -Prompt "First name: " #Set given name
        $sn = Read-Host -Prompt "Last name: " #Set username
        $position = Read-Host -Prompt "Position: " #Position
        $office = ChangeEntry (Read-Host -Prompt "Building: ") #Building they work in
        $employeeid = Read-Host -Prompt "EmployeeID: " #EmployeeID
        $accesscard = Read-Host -Prompt "Accesscard: " #Accesscard
        $accesslvl = Read-Host -Prompt "accesslvl: " #accesslvl
        $sAMAccountName = UniqueTest (($givenName[0] + $sn) -replace " ", "" -replace "\.\.", "." -replace "'", "" -replace "-", "" -replace "ó", "o" -replace ",", "" -replace "í", "i" ).ToLower() $givenName $sn $employeeid #Remove unnecessary characters/change to common ones then lower into uniform format
        $userPrincipalName = "$sAMAccountName$Domain"  
        $mail = "$sAMAccountName$emaildomain" #Set the mail attribute for the account (if desired, usually helpful if you're synchronizing to Google Apps/Office 365)
        $displayname = "$givenName $sn" #Set display name
        $name = ($displayname -replace "\.\.", "." -replace "'", "" -replace "-", "" -replace "ó", "o" -replace ",", "" -replace "í", "i").ToUpper()
        $otherAttributes = @{'userPrincipalName' = "$userPrincipalName"; 'mail' = "$mail"; 'givenName' = "$givenName"; 'sn' = "$sn"; 'DisplayName' = "$displayname"; 'employeeID' = "$employeeID"; 'physicalDeliveryOfficeName' = "$office"; 'description' = "$position"; 'HomePhone' = $accesscard}
        $otherAttributes.description = [string]$otherAttributes.description #Needs to be a string for AD
      
        if ((Get-ADUser -Filter "EmployeeID -eq '$employeeID'") -eq $null) { #If new user - add
            ADDADUser $sAMAccountName $name $otherAttributes $position $password $office
        } else { #if current user - update
            UpdateADUser $employeeID $office $sAMAccountName $name $givenname $mail $sn $displayname $newhomedirectory $position $userPrincipalName
        }
        AddToGroups $employeeID $position $office $accesslvl #Add user to appropraite groups
    }
}

#Delete the #'s in the following lines to add code to remove users not in textfile but in the AD. Moves them to a specific folder - in this case Unknown is the name of the fold

#$sisfile = Import-Csv -delimiter "`t" -Path $sisexportfilestaff -header "givenName","sn","position","office","employeeid" #Read from the saved textfile from the online csv file
#$ADUsers = Get-ADUser -Filter * -SearchBase $OUExtension -Properties HomeDirectory, EmployeeID, SamAccountName #Get the list of AD users
#$NotPresent = $sisfile.employeeid
#foreach ($ADUser in $ADUsers) { #Iterate through each AD user
#    $SamAccountName = $ADUser.SamAccountName
#    $employeeID = $ADUser.EmployeeID #Set employeeID
#    $HomeDirectory = $ADUser.HomeDirectory #Set Homedirectory
#    $DistinguishedName = $ADUser.DistinguishedName
#    if ($employeeID -notin $NotPresent -and $HomeDirectory -notlike '*Unknown*') {
#        Move-Item -Path $HomeDirectory -Destination $UnknownFolder -Force
#        Set-ADUser -Identity $DistinguishedName -HomeDirectory ($UnknownFolder+"\"+$SamAccountName) -SamAccountName $SamAccountName -Enabled $false #Change properties in AD
#        Move-ADObject -Identity $DistinguishedName -TargetPath $UnknownOU #Move AD t to Withdrawn OU
#        Write-Host "Not Found in sisfile`nHome directory: $HomeDirectory -> $UnknownFolder`nAD: $DistinguishedName -> $UnknownOU`n" #Write-Host adds to changelog
#    }
#}

Stop-Transcript #End log taking
