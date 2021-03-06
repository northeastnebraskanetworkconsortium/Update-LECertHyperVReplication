
Param(
    [string]$MainDomain,
    [switch]$UseExisting,
    [switch]$ForceRenew
)

function Logging {
    param([string]$Message)
    Write-Host $Message
    $Message >> $LogFile
}

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

Import-Module PKI
Import-Module Posh-Acme
#Import-Module WebAdministration
$LogFile = '.\UpdateHyperVReplicationSSL.log'
Get-Date | Out-File $LogFile -Append
if($UseExisting) {
    Logging -Message "Using Existing Certificate"
    $cert = get-pacertificate -MainDomain $MainDomain
}
else {
    if($ForceRenew) {
        Logging -Message "Starting Forced Certificate Renewal"
        $cert = Submit-Renewal -MainDomain $MainDomain -Force
    }
    else {
        Logging -Message "Starting Certificate Renewal"
        $cert = Submit-Renewal -MainDomain $MainDomain
    }
    Logging -Message "...Renew Complete!"
}

if($cert){
    Logging -Message "Importing certificate to Cert:\LocalMachine\My"
    Import-PfxCertificate -FilePath $cert.PfxFullChain -CertStoreLocation Cert:\LocalMachine\My -Password ('poshacme' | ConvertTo-SecureString -AsPlainText -Force)
       
    # Remove old certs
    ls Cert:\LocalMachine\My | ? Subject -eq "CN=$MainDomain" | ? NotAfter -lt $(get-date) | remove-item -Force
    
    # Update thumbrprint of replication certificate
    $vms = Get-VMReplication
    foreach ($vm in $vms) {
        Set-VMReplication -VMName $vm.Name -CertificateThumbprint $cert.Thumbprint
        Logging -Message "Changed replication cert for $($vm.Name)"
    }
}else{
    Logging -Message "No need to update certifcate" 
}
