variable "location"   { 
  type = string
  default = "eastus" 
  }

variable "project_rg" { 
  type = string
  default = "rg-minimal-demo" 
  }

variable "tag_environment" { 
  type = string
   default = "Dev" 
   }

variable "tag_owner"       { 
  type = string
   default = "Savannah Fry" 
   }

variable "tag_costcenter"  { 
  type = string
  default = "PORTFOLIO" 
  }
