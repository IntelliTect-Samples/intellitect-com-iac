# IntelliTect.com infrastructure provisioning

Prerequisites
- Azure SSH Key
- Subscription id
- AD Account with contributor access

# Notes
Beware when migrating to new Flexible Server as it seems default MySQL server settings are no longer compatible
Executing azuremysqlmigfinal.sh works were as straight mydumper/myloader does not

https://github.com/Azure/azure-mysql/blob/master/azuremysqltomysqlmigrate/README.md


# References
vm ssh key support
https://github.com/hashicorp/terraform-provider-azurerm/issues/15135

https://docs.microsoft.com/en-us/azure/mysql/concepts-migrate-mydumper-myloader

https://docs.microsoft.com/en-us/azure/mysql/concepts-migrate-mydumper-myloader

https://docs.microsoft.com/en-us/azure/app-service/provision-resource-terraform

https://docs.microsoft.com/en-us/azure/mysql/howto-migrate-single-flexible-minimum-downtime

