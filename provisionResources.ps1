# --- start ---

# variables

$studentName="david"

$rgName="${studentName}-events-aadb2c-rg"

# -- vm
$vmName="${studentName}-events-aadb2c-vm"

$vmAdminUsername="student"
$vmAdminPassword='LaunchCode-@zure1'

$vmSize="Standard_B2s"
$vmImage="$(az vm image list --query "[? contains(urn, 'Ubuntu')] | [0].urn")"

# -- kv
$kvName="${studentName}-events-aadb2c-kv"
$kvSecretName='ConnectionStrings--Default'
$kvSecretValue='server=localhost;port=3306;database=coding_events;user=coding_events;password=launchcode'

# set az location default

az configure --default location=eastus

# RG: provision

az group create -n "$rgName"

# set az rg default

az configure --default group=$rgName

# VM: provision

# capture vm output for splitting
az vm create -n $vmName --size $vmSize --image $vmImage --admin-username $vmAdminUsername --admin-password $vmAdminPassword --authentication-type password --assign-identity

# set az vm default

az configure --default vm=$vmName

# get the (identity)
$vmId=$(az vm identity show --query principalId)

# get the (ip)
$vmIp=$(az vm show -d --query publicIps)

# VM: add NSG rule for port 443 (https)

az vm open-port --port 443

# KV: provision

az keyvault create -n $kvName --enable-soft-delete false --enabled-for-deployment true

# KV: set secret

az keyvault secret set --vault-name $kvName --description 'connection string' --name $kvSecretName --value $kvSecretValue

# KV: grant access to VM

az keyvault set-policy --name $kvName --object-id $vmId --secret-permissions list get

# Update Ip in deliver-deploy
((get-content -path deliver-deploy.sh -Raw) -replace 'public_ip',$vmIp) | Set-Content deliver-deploy.sh


# VM setup-and-deploy script

az vm run-command invoke --command-id RunShellScript --scripts '@.\vm-configuration-scripts\1configure-vm.sh' '@.\vm-configuration-scripts\2configure-ssl.sh' 'deliver-deploy.sh'


# finished print out IP address

echo "VM available at $vmIp"

# --- end ---

