variable mysql_admin {
    type = string
    description = "mysql admin user"
    default = "intellitectadmin"
}

variable mysql_admin_password {
    type = string
    description = "mysql admin password"
}

variable db_name {
    type = string
    description = "database name"
    default = "itltcwebdb"
}

# variable tags {
#     type = map({})
#     description = "resource tags"
#     default = {
#         Environment = "Production",
#         Provisioner = "Terraform",
#         Owner = "intellitect web"
#     }
# }

variable vm_admin {
    type = string
    description = "Admin user name"
    default = "intellitectadmin"
}

variable wp_admin_email {
    type = string
    default = "webadmin@intellitect.com"
}
variable wp_admin_password {
    type = string
}
variable wp_admin_user {
    type = string
    default = "webadmin@intellitect.com"
}
variable wp_admin_title {
    type = string
    default = "WordPress on Azure"
}
