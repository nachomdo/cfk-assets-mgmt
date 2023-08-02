
data "google_compute_default_service_account" "default" {
}

locals {
  access_config = {
    nat_ip       = ""
    network_tier = "STANDARD"
  }
}

data "cloudinit_config" "conf" {
  gzip          = false
  base64_encode = false

  part {
    content_type = "text/cloud-config"
    content      = file("${path.module}/ansible_cloud_init.yml")
    filename     = "conf.yaml"
  }
}

module "ansible_instance_template" {
  service_account = {
    email  = data.google_compute_default_service_account.default.email
    scopes = ["compute-ro", "storage-ro"]
  }
  source               = "terraform-google-modules/vm/google//modules/instance_template"
  version              = "8.0.1"
  machine_type         = var.bastion_instace_type
  source_image_project = "ubuntu-os-cloud"
  source_image_family  = var.os_image
  name_prefix          = "cp-ansible-"
  tags                 = ["ansible", "${var.project_id}-nm-ansible"]
  network              = google_compute_network.vpc.name
  subnetwork           = google_compute_subnetwork.subnet.name

  metadata = {
    ssh-keys       = "ubuntu:${file("~/.ssh/id_rsa.pub")}"
    enable-oslogin = "TRUE"
    user-data      = "${data.cloudinit_config.conf.rendered}"
  }
}

module "kafka_instance_template" {
  service_account = {
    email  = data.google_compute_default_service_account.default.email
    scopes = ["compute-ro", "storage-ro"]
  }
  source               = "terraform-google-modules/vm/google//modules/instance_template"
  version              = "8.0.1"
  machine_type         = var.kafka_instance_type
  source_image_project = "ubuntu-os-cloud"
  source_image_family  = var.os_image
  name_prefix          = "cp-kafka-"
  tags                 = ["kafka", "${var.project_id}-nm-kafka"]
  network              = google_compute_network.vpc.name
  subnetwork           = google_compute_subnetwork.subnet.name
  metadata = {
    ssh-keys       = "ubuntu:${file("~/.ssh/id_rsa.pub")}"
    enable-oslogin = "TRUE"
  }
}

module "umig_kafka" {
  source            = "terraform-google-modules/vm/google//modules/umig"
  project_id        = var.project_id
  version           = "8.0.1"
  subnetwork        = google_compute_subnetwork.subnet.name
  hostname          = "broker"
  num_instances     = 6
  instance_template = module.kafka_instance_template.self_link
  region            = var.region
}

module "umig_ansible" {
  source            = "terraform-google-modules/vm/google//modules/umig"
  project_id        = var.project_id
  version           = "8.0.1"
  subnetwork        = google_compute_subnetwork.subnet.name
  hostname          = "ansible"
  num_instances     = 1
  instance_template = module.ansible_instance_template.self_link
  region            = var.region
  access_config     = [[local.access_config]]
}