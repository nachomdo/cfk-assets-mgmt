resource "google_compute_network" "vpc" {
  name                            = "${var.project_id}-nm-vpc"
  auto_create_subnetworks         = "false"
  routing_mode                    = "GLOBAL"
  delete_default_routes_on_create = true
}

resource "google_compute_subnetwork" "subnet" {
  name                     = "${var.project_id}-nm-subnet"
  region                   = var.region
  network                  = google_compute_network.vpc.name
  ip_cidr_range            = "10.10.0.0/24"
  private_ip_google_access = true
}

resource "google_compute_route" "egress_internet" {
  name             = "nm-egress-internet"
  dest_range       = "0.0.0.0/0"
  network          = google_compute_network.vpc.name
  next_hop_gateway = "default-internet-gateway"
}

resource "google_compute_router" "router" {
  name    = "nm-test-router"
  region  = google_compute_subnetwork.subnet.region
  network = google_compute_network.vpc.name
}

resource "google_compute_router_nat" "nat_router" {
  name                               = "${google_compute_subnetwork.subnet.name}-nm-nat-router"
  router                             = google_compute_router.router.name
  region                             = google_compute_router.router.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "LIST_OF_SUBNETWORKS"

  subnetwork {
    name                    = google_compute_subnetwork.subnet.name
    source_ip_ranges_to_nat = ["ALL_IP_RANGES"]
  }

  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}

resource "google_compute_firewall" "ssh-rule" {
  name    = "cp-kafka-nm-ssh"
  network = google_compute_network.vpc.name
  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
  target_tags   = ["ansible", "kafka"]
  source_ranges = ["0.0.0.0/0"]
}

resource "google_compute_firewall" "brokers-rule" {
  name    = "cp-kafka-nm-brokers"
  network = google_compute_network.vpc.name
  allow {
    protocol = "tcp"
    ports    = ["9091", "9092", "9093", "8090"]
  }
  target_tags   = ["ansible", "kafka"]
  source_ranges = ["0.0.0.0/0"]
}

resource "google_dns_managed_zone" "private-zone" {
  name        = "nm-test-private-zone"
  dns_name    = "${var.domain_name}"
  description = "nm-test demo private DNS zone"

  visibility = "private"

  private_visibility_config {
    networks {
      network_url = google_compute_network.vpc.self_link
    }
  }
}
