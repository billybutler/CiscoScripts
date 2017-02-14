# $language = "VBScript"
# $interface = "1.0"
Dim FSO, Shell, deployed
Const ForReading = 1
Const ForWriting = 2
Const ForAppending = 8
Set FSO = CreateObject("scripting.filesystemobject")
Set Shell = CreateObject("WScript.Shell")
Set objSc = crt.Screen
Set objD = crt.Dialog
Set objSe = crt.Session
Set objW = crt.Window
Set objDictionary = CreateObject("Scripting.Dictionary")

'File containing a list of Router IPs to perform the change on. One IP per line.
HOSTIP = objD.Prompt("Enter folder name and Path to the hosts file","Folder Name & Path","U:\script\PHOTO-ACL\ACL-IP.txt")
Set SwitchIP = FSO.opentextfile(HOSTIP, ForReading, False)

'File containing a list of commands to perform on each router. One command per line.
CommandsFile = objD.Prompt("Enter folder name and Path to the commands file","Folder Name & Path","U:\script\PHOTO-ACL\Commands.csv")

User = objD.Prompt("Enter YOUR Username To Get into device"&Chr(13)&Chr(13)&_
"Same username used for all devices"," ","xxxxxxxxxx")

Pass = objD.Prompt("Enter password To Get into device"&Chr(13)&Chr(13)&_
"Password must be the same for all devices!"," ","xxx", TRUE)

Logfiles = objD.Prompt("Enter folder name and Path to save Log files In.","Folder Name & Path","U:\script\PHOTO-ACL\logs\")

missAclPhoto = 0

If FSO.FolderExists(Logfiles) Then
Else
	FSO.CreateFolder(Logfiles)
End IF
'<---- Adds a deployment start Time stamp to the summary log file.
Set Tempfile = FSO.OpenTextFile(Logfiles&"\Summary.txt",ForAppending, True)
tempfile.writeline "Deployment start - " & Now ()
tempfile.writeline "--------------"
TempFile.Close()

'<-------- Script Purpose: Deploy
'<-- 1. Update the Photo access control list (ACL) on all retail store routers (primary and secondary)
'<--------

'Start loop
While Not SwitchIP.atEndOfStream
	IP = SwitchIP.Readline()
	Set Config = FSO.opentextfile(CommandsFile, ForReading, False)
	save = 0
	counter = counter + 1
	
	'<-------------------- Device Connect sequence ---------------------------------> 
	On Error Resume Next
	crt.session.connect "/SSH2 /AcceptHostKeys /L " & User & " /PASSWORD " & Pass & " " & IP & " "
	On Error Goto 0
	If ( crt.Session.Connected ) Then
		objsc.Synchronous = True
		'<-------------------- Create logfile for command/logfile changes
		objse.logfilename = Logfiles&"\%Y%M%D-%h%m-"&IP&".cfg"
		objse.Log(True) '<-- This opens the logfile and captures the SecureCRT output to the timestamped ".cfg" file
		enablepass = objSc.waitforstrings(">", "#")
		objSc.Send "enable" & vbCr
		objSc.WaitForString":"
		objSc.Send Pass & vbCr
		objSc.WaitForString"#"
		objSc.Send "term length 0" & vbCr '<-- allows
		objSc.WaitForString"#"
		
		'<-------------------- END if Connect sequence ------------------------------->
		'<-------------------- Pre-test section -------------------------------------->
		
		'<---- PHOTO-ACL Section
		objSc.Send"sh ip access-list PHOTO-ACL" & VbCr 
		aclExists = objSc.WaitForString("Extended",5)
		if aclExists = TRUE then
			objSc.Send "conf t" & VbCr 
			objSc.WaitForString "(config" : objSc.WaitForString ")#" '<----------------------Command Check
			'<---- Read each config line in turn from the CSV file and send to the device
			ConfigLine = Config.ReadLine 'Read Header Row of CSV file
			While Not Config.atEndOfStream
				'Split Line Read into Command and Prompt
				ConfigLine = Split(Config.ReadLine,",")
				Command = ConfigLine(0)
				Prompt = ConfigLine(1)
				objSc.Send Command & VbCr
				PromptExpected = "(" & Prompt & ")#"
				objSc.WaitForString PromptExpected '<----------------------Command Check
			Wend

			objSc.Send "end" & VbCr
			objSc.WaitForString"#"
			save = save + 1
		else
			Set Tempfiledata = FSO.OpenTextFile(Logfiles&"\missing-ACL.txt",ForAppending, True)
			TempFiledata.writeline IP
			TempFiledata.Close()
			missAcl = missAcl + 1
		end if
		
		if save > 0 then
			objSc.Send "copy run start" & VbCr
			objSc.WaitForString"]?"
			objSc.Send VbCr
			objSc.WaitForString"#"
			deployed = deployed + 1
			Set Tempfiledata = FSO.OpenTextFile(Logfiles&"\ACL-Updated-list.txt",ForAppending, True)
			TempFiledata.writeline IP
			TempFiledata.Close()
		end if
		
		objSc.Send "exit" & vbCr
		objse.Log(False)
		objSc.Synchronous = False
		objSE.Disconnect
		
	Else
		Set Tempfile = FSO.OpenTextFile(Logfiles&"\NoConnect.txt",ForAppending, True)
		TempFile.writeline IP
		TempFile.Close()
	End IF

Wend

tFail = missAcl
tRolled = ""
tFRolled= ""

Set Tempfile = FSO.OpenTextFile(Logfiles&"\Summary.txt",ForAppending, True)
TempFile.writeline "Deployment Complete: " & Now ()
tempfile.writeline "--------------"
TempFile.writeline "Total Number of devices: " & counter
TempFile.writeline "Total Number of Updated: " & deployed
TempFile.writeline "Total Number of warnings: " & tFail
TempFile.writeline "Total Number of Rolled Back: N/A" & tRolled
TempFile.writeline "Rolled Back failed: N/A" & tFRolled
tempfile.writeline "--------------"
tempfile.writeline "Missing PHOTO-ACL: " & missAclPhoto
tempfile.writeline "--------------"
TempFile.Close()