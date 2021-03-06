#support functions

Function Get-OS {

[cmdletbinding()]
Param(
[Parameter(Position = 0,ValueFromPipeline)]
[Alias("cn")]
[ValidateNotNullorEmpty()]
[string[]]$Computername = $env:computername
)

Begin {

    #save current verbose color value
    $saved = $host.privatedata.VerboseForegroundColor
    #set color for begin block
    $host.privatedata.VerboseForegroundColor = "green"
    Write-Verbose "$(Get-Date -Format "hh:mm:ss:ffff") [BEGIN  ] Starting $($MyInvocation.Mycommand)" 
    
    #define some execution metadata
    $meta = "Execution context = User:$($env:userdomain)\$($env:username) Computer:$($env:computername) PSVersion:$($PSVersionTable.PSVersion)"
    Write-Verbose "$(Get-Date -Format "hh:mm:ss:ffff") [BEGIN  ] $meta"

    #define hashtable of parameters to splat to Get-CimInstance
    $paramHash = @{
        ClassName = 'Win32_OperatingSystem'        ErrorAction = 'Stop'     } 

    #set color for process block
    $host.privatedata.VerboseForegroundColor = "yellow"

} #begin

Process {

    Foreach ($computer in $Computername) {
        Write-Verbose "$(Get-Date -Format "hh:mm:ss:ffff") [PROCESS] Connecting to $Computer"  
        $paramHash.Computername = $Computer
        Try {
            Write-Verbose "$(Get-Date -Format "hh:mm:ss:ffff") [PROCESS] Running Get-CimInstance"  

            $data = Get-CimInstance @paramHash 
            
            Write-Verbose "$(Get-Date -Format "hh:mm:ss:ffff") [PROCESS] Creating output"  

            Switch ($data.producttype) {
                1 { $prodType = "Desktop"}
                2 { $prodType = "DomainController"}
                3 { $prodType = "Server"}
                default {
                    #this should never happen but just in case
                    $prodType = $data.ProductType
                    }
            } #close Switch

            [pscustomobject]@{
                Computername = $data.CSName
                Name = $data.caption
                Version = $data.version
                Build = $data.buildnumber
                InstallDate = $data.installDate
                Age = (Get-Date) - $data.installdate
                OSArch = $data.OSArchitecture
                Type = $ProdType
            }

            #INSERTING A RANDOM SLEEP FOR THE SAKE OF DEMONSTRATION
            Start-Sleep -Seconds (Get-Random -Maximum 5 -Minimum 1)
        } #try

        Catch  {
            Write-Warning "Failed to get OS data for $($Computer.toUpper()). $($_.Exception.Message)"
        } #catch

    } #Foreach

} #process

End {
    
    #set color for end block
    $host.privatedata.VerboseForegroundColor = "cyan"
    Write-Verbose "$(Get-Date -Format "hh:mm:ss:ffff") [END    ] Ending $($MyInvocation.Mycommand)"

    #restore color
    $host.privatedata.VerboseForegroundColor = $saved

} #end

} #close Get-OS function


Function Get-SysInfo {

[cmdletbinding()]

Param(
[Parameter(Position=0,Mandatory,ValueFromPipeline=$True)]
[ValidateNotNullorEmpty()]
[string]$Computername,
[pscredential]$Credential
)

Begin {
    Write-Verbose "[BEGIN  ] Starting: $($MyInvocation.Mycommand)"  
} #begin


Process {
     Write-Verbose "[PROCESS] Processing $($Computername.toUpper())"  

     Write-Verbose "[PROCESS] Creating a CIMSession"  
     Try {
        $cimsess = New-CimSession @psboundparameters
     }
     Catch {
        Write-Warning "Failed to create a session to $($Computername.toUpper()). $($_.Exception.message)"
        Remove-Variable cimsess
     }

     If ($cimsess) {
        Write-Verbose "[PROCESS] Querying information from WMI"  
        $os = Get-CimInstance Win32_OperatingSystem -CimSession $cimsess
        $cs = Get-CimInstance Win32_ComputerSystemProduct -CimSession $cimsess
        $running = Get-CimInstance Win32_Service -filter "State='running'" -CimSession $cimsess
        $procs = Get-CimInstance Win32_Process -Property Name -CimSession $cimsess
    
        [pscustomobject]@{
            Computername = $os.CSName
            OS = $os.Caption
            System = ("{0} {1} ({2})" -f $cs.Vendor,$cs.Name,$cs.version)
            Services = $Running.Count
            Processes = $Procs.count
            Location = $global:demolocation
        }

        Write-Verbose "[PROCESS] Removing CIMSession"  
        $cimsess | Remove-CimSession
    } #if
 } #close Process

 End {
     Write-Verbose "[END    ] Ending: $($MyInvocation.Mycommand)"
 } #end
} #close function


