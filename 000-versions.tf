terraform {
  required_version = "~> 1.5.5"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "4.78.0"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = "4.78.0"
    }
    time = {
      source  = "hashicorp/time"
      version = "0.9.1"
    }
  }
}
