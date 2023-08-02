terraform {
  required_version = ">=0.12.0"
}

# GKE cluster
resource "google_container_cluster" "primary" {
  name     = "${var.project_id}-nacho-gke"
  location = var.region

  remove_default_node_pool = true
  initial_node_count       = 1

  network    = google_compute_network.vpc.name
  subnetwork = google_compute_subnetwork.subnet.name
}

# Separately Managed Node Pool
resource "google_container_node_pool" "primary_nodes" {
  name       = "${var.project_id}-nacho-gke-nodes"
  location   = var.region
  cluster    = google_container_cluster.primary.name
  node_count = var.gke_num_nodes

  autoscaling {
    min_node_count = 1
    max_node_count = 4
  }

  node_config {
    oauth_scopes = [
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring",
      "https://www.googleapis.com/auth/ndev.clouddns.readwrite",
    ]

    labels = {
      env = var.project_id
    }

    # preemptible  = true
    machine_type = var.gke_nodes_instance_type
    tags         = ["gke-node", "${var.project_id}-nm-gke"]
    metadata = {
      disable-legacy-endpoints = "true"
    }
  }
}

resource "google_gke_hub_membership" "membership" {
  membership_id = "nm-test-membership"
  project       = var.project_id
  endpoint {
    gke_cluster {
      resource_link = "//container.googleapis.com/${google_container_cluster.primary.id}"
    }
  }
  provider = google-beta
}

resource "google_gke_hub_feature_membership" "feature_member" {
  location   = "global"
  feature    = "configmanagement"
  project    = var.project_id
  membership = google_gke_hub_membership.membership.membership_id
  configmanagement {
    version = "1.15.0"
    policy_controller {
      enabled = true
      template_library_installed = true
      referential_rules_enabled  = true
    }
    config_sync {
      source_format = "unstructured"
      git {
        sync_repo   = "https://github.com/nachomdo/cfk-assets-mgmt.git"
        sync_branch = "main"
        policy_dir  = "gitops"
        secret_type = "none"
      }
    }
  }
  provider = google-beta
}

resource "google_gke_hub_feature" "mesh" {
  name     = "servicemesh"
  location = "global"
  project  = var.project_id
  provider = google-beta
}

resource "google_gke_hub_feature_membership" "istio_member" {
  location   = "global"
  feature    = google_gke_hub_feature.mesh.name
  project    = var.project_id
  membership = google_gke_hub_membership.membership.membership_id
  mesh {
    management = "MANAGEMENT_AUTOMATIC"
  }
  provider = google-beta
}

resource "google_service_account" "external_dns_sa" {
  account_id   = "nm-test-external-dns-sa"
  display_name = "A service account for external-dns"
}

resource "google_project_iam_member" "external-dns-gsa" {
  project = var.project_id
  role    = "roles/dns.admin"
  member  = "serviceAccount:${google_service_account.external_dns_sa.email}"
}

resource "google_service_account_iam_binding" "external-dns-ksa" {
  service_account_id = google_service_account.external_dns_sa.name
  role               = "roles/iam.workloadIdentityUser"

  members = [
    "serviceAccount:${var.project_id}.svc.id.goog[external-dns/external-dns]",
  ]
}

output "kafka_brokers" {
  value = module.umig_kafka.instances_details[*].network_interface[0].network_ip
}

output "ansible_node" {
  value = module.umig_ansible.instances_details[0].network_interface[0].access_config[0].nat_ip
}