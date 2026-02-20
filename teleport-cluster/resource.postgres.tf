# Step 1: Create a custom Certificate Authority (CA)
resource "tls_private_key" "ca_key" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "tls_self_signed_cert" "ca_cert" {
  private_key_pem = tls_private_key.ca_key.private_key_pem

  subject {
    common_name  = "Custom PostgreSQL CA"
    organization = "Terraform CA"
  }

  is_ca_certificate     = true
  validity_period_hours = 87600 # 10 years
  allowed_uses = [
    "cert_signing",
    "key_encipherment",
    "digital_signature",
  ]
}

# Step 2: Generate a server private key and CSR
resource "tls_private_key" "server_key" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "tls_cert_request" "server_csr" {
  private_key_pem = tls_private_key.server_key.private_key_pem

  subject {
    common_name  = "developer"
    organization = "Terraform Server"
  }

  dns_names = [
    "${var.resource_prefix}postgres-postgresql.${kubernetes_namespace_v1.teleport_cluster.metadata[0].name}",
    "${var.resource_prefix}postgres-postgresql.${kubernetes_namespace_v1.teleport_cluster.metadata[0].name}.svc.cluster.local"
  ]
}

# Step 3: Sign the server certificate with the CA
resource "tls_locally_signed_cert" "server_cert" {
  cert_request_pem   = tls_cert_request.server_csr.cert_request_pem
  ca_private_key_pem = tls_private_key.ca_key.private_key_pem
  ca_cert_pem        = tls_self_signed_cert.ca_cert.cert_pem

  validity_period_hours = 8760 # 1 year
  allowed_uses = [
    "client_auth",
    "key_encipherment",
    "digital_signature",
    "server_auth",
  ]
}

# Step 4: Create Kubernetes TLS secret with certs
resource "kubernetes_secret" "postgres_tls" {
  metadata {
    name      = "${var.resource_prefix}postgresql-tls"
    namespace = kubernetes_namespace_v1.teleport_cluster.metadata[0].name
  }

  data = {
    "ca.crt"  = <<EOF
${tls_self_signed_cert.ca_cert.cert_pem}
${data.http.teleport_db_ca.response_body}
    EOF
    "tls.crt" = tls_locally_signed_cert.server_cert.cert_pem
    "tls.key" = tls_private_key.server_key.private_key_pem
  }

  type = "Opaque"
}

# Step 6: ConfigMap for PostgreSQL init script (auto-provisioning setup)
resource "kubernetes_config_map" "postgres_custom_init" {
  metadata {
    name      = "${var.resource_prefix}postgres-custom-init"
    namespace = kubernetes_namespace_v1.teleport_cluster.metadata[0].name
  }

  data = {
    "setup.sh" = <<-EOF
      #!/bin/bash
      set -e
      PGPASSWORD="$POSTGRESQL_POSTGRES_PASSWORD" psql -U postgres -d teleport_db -v ON_ERROR_STOP=1 <<SQL
      CREATE USER "teleport-admin" LOGIN SUPERUSER;
      CREATE ROLE "admin" NOLOGIN;
      GRANT "admin" TO "teleport-admin" WITH ADMIN OPTION;
      GRANT ALL PRIVILEGES ON DATABASE teleport_db TO "admin";
      GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO "admin";
      GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO "admin";
      ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL PRIVILEGES ON TABLES TO "admin";
      ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL PRIVILEGES ON SEQUENCES TO "admin";
      CREATE ROLE "read_only" NOLOGIN;
      GRANT "read_only" TO "teleport-admin" WITH ADMIN OPTION;
      GRANT CONNECT ON DATABASE teleport_db TO "read_only";
      GRANT USAGE ON SCHEMA public TO "read_only";
      GRANT SELECT ON ALL TABLES IN SCHEMA public TO "read_only";
      GRANT SELECT ON ALL SEQUENCES IN SCHEMA public TO "read_only";
      ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO "read_only";
      ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON SEQUENCES TO "read_only";

      -- Create top 100 movies table
      CREATE TABLE IF NOT EXISTS top_movies (
        rank INTEGER PRIMARY KEY,
        title VARCHAR(255) NOT NULL,
        year INTEGER NOT NULL,
        director VARCHAR(255) NOT NULL
      );

      INSERT INTO top_movies (rank, title, year, director) VALUES
        (1, 'The Shawshank Redemption', 1994, 'Frank Darabont'),
        (2, 'The Godfather', 1972, 'Francis Ford Coppola'),
        (3, 'The Dark Knight', 2008, 'Christopher Nolan'),
        (4, 'The Godfather Part II', 1974, 'Francis Ford Coppola'),
        (5, '12 Angry Men', 1957, 'Sidney Lumet'),
        (6, 'Schindlers List', 1993, 'Steven Spielberg'),
        (7, 'The Lord of the Rings: The Return of the King', 2003, 'Peter Jackson'),
        (8, 'Pulp Fiction', 1994, 'Quentin Tarantino'),
        (9, 'The Lord of the Rings: The Fellowship of the Ring', 2001, 'Peter Jackson'),
        (10, 'The Good, the Bad and the Ugly', 1966, 'Sergio Leone'),
        (11, 'Forrest Gump', 1994, 'Robert Zemeckis'),
        (12, 'Fight Club', 1999, 'David Fincher'),
        (13, 'The Lord of the Rings: The Two Towers', 2002, 'Peter Jackson'),
        (14, 'Inception', 2010, 'Christopher Nolan'),
        (15, 'Star Wars: Episode V - The Empire Strikes Back', 1980, 'Irvin Kershner'),
        (16, 'The Matrix', 1999, 'Lana Wachowski'),
        (17, 'Goodfellas', 1990, 'Martin Scorsese'),
        (18, 'One Flew Over the Cuckoos Nest', 1975, 'Milos Forman'),
        (19, 'Se7en', 1995, 'David Fincher'),
        (20, 'Its a Wonderful Life', 1946, 'Frank Capra'),
        (21, 'The Silence of the Lambs', 1991, 'Jonathan Demme'),
        (22, 'Saving Private Ryan', 1998, 'Steven Spielberg'),
        (23, 'City of God', 2002, 'Fernando Meirelles'),
        (24, 'Interstellar', 2014, 'Christopher Nolan'),
        (25, 'Life Is Beautiful', 1997, 'Roberto Benigni'),
        (26, 'The Green Mile', 1999, 'Frank Darabont'),
        (27, 'Star Wars: Episode IV - A New Hope', 1977, 'George Lucas'),
        (28, 'Terminator 2: Judgment Day', 1991, 'James Cameron'),
        (29, 'Back to the Future', 1985, 'Robert Zemeckis'),
        (30, 'Spirited Away', 2001, 'Hayao Miyazaki'),
        (31, 'The Pianist', 2002, 'Roman Polanski'),
        (32, 'Psycho', 1960, 'Alfred Hitchcock'),
        (33, 'Parasite', 2019, 'Bong Joon-ho'),
        (34, 'Gladiator', 2000, 'Ridley Scott'),
        (35, 'The Lion King', 1994, 'Roger Allers'),
        (36, 'Leon: The Professional', 1994, 'Luc Besson'),
        (37, 'American History X', 1998, 'Tony Kaye'),
        (38, 'The Departed', 2006, 'Martin Scorsese'),
        (39, 'Whiplash', 2014, 'Damien Chazelle'),
        (40, 'The Prestige', 2006, 'Christopher Nolan'),
        (41, 'The Usual Suspects', 1995, 'Bryan Singer'),
        (42, 'Casablanca', 1942, 'Michael Curtiz'),
        (43, 'Harakiri', 1962, 'Masaki Kobayashi'),
        (44, 'The Intouchables', 2011, 'Olivier Nakache'),
        (45, 'Modern Times', 1936, 'Charlie Chaplin'),
        (46, 'Cinema Paradiso', 1988, 'Giuseppe Tornatore'),
        (47, 'Once Upon a Time in the West', 1968, 'Sergio Leone'),
        (48, 'Rear Window', 1954, 'Alfred Hitchcock'),
        (49, 'Alien', 1979, 'Ridley Scott'),
        (50, 'City Lights', 1931, 'Charlie Chaplin'),
        (51, 'Apocalypse Now', 1979, 'Francis Ford Coppola'),
        (52, 'Memento', 2000, 'Christopher Nolan'),
        (53, 'Django Unchained', 2012, 'Quentin Tarantino'),
        (54, 'Indiana Jones and the Raiders of the Lost Ark', 1981, 'Steven Spielberg'),
        (55, 'WALL-E', 2008, 'Andrew Stanton'),
        (56, 'The Lives of Others', 2006, 'Florian Henckel von Donnersmarck'),
        (57, 'Sunset Boulevard', 1950, 'Billy Wilder'),
        (58, 'Paths of Glory', 1957, 'Stanley Kubrick'),
        (59, 'The Shining', 1980, 'Stanley Kubrick'),
        (60, 'The Great Dictator', 1940, 'Charlie Chaplin'),
        (61, 'Witness for the Prosecution', 1957, 'Billy Wilder'),
        (62, 'Aliens', 1986, 'James Cameron'),
        (63, 'American Beauty', 1999, 'Sam Mendes'),
        (64, 'The Dark Knight Rises', 2012, 'Christopher Nolan'),
        (65, 'Grave of the Fireflies', 1988, 'Isao Takahata'),
        (66, 'Oldboy', 2003, 'Park Chan-wook'),
        (67, 'Toy Story', 1995, 'John Lasseter'),
        (68, 'Das Boot', 1981, 'Wolfgang Petersen'),
        (69, 'Amadeus', 1984, 'Milos Forman'),
        (70, 'Princess Mononoke', 1997, 'Hayao Miyazaki'),
        (71, 'Coco', 2017, 'Lee Unkrich'),
        (72, 'Avengers: Endgame', 2019, 'Anthony Russo'),
        (73, 'The Hunt', 2012, 'Thomas Vinterberg'),
        (74, 'Good Will Hunting', 1997, 'Gus Van Sant'),
        (75, 'Requiem for a Dream', 2000, 'Darren Aronofsky'),
        (76, 'Toy Story 3', 2010, 'Lee Unkrich'),
        (77, '3 Idiots', 2009, 'Rajkumar Hirani'),
        (78, 'Come and See', 1985, 'Elem Klimov'),
        (79, 'High and Low', 1963, 'Akira Kurosawa'),
        (80, 'Singin in the Rain', 1952, 'Stanley Donen'),
        (81, 'Capernaum', 2018, 'Nadine Labaki'),
        (82, 'Inglourious Basterds', 2009, 'Quentin Tarantino'),
        (83, '2001: A Space Odyssey', 1968, 'Stanley Kubrick'),
        (84, 'Braveheart', 1995, 'Mel Gibson'),
        (85, 'Full Metal Jacket', 1987, 'Stanley Kubrick'),
        (86, 'A Beautiful Mind', 2001, 'Ron Howard'),
        (87, 'Snatch', 2000, 'Guy Ritchie'),
        (88, 'Eternal Sunshine of the Spotless Mind', 2004, 'Michel Gondry'),
        (89, 'Scarface', 1983, 'Brian De Palma'),
        (90, 'The Truman Show', 1998, 'Peter Weir'),
        (91, 'Heat', 1995, 'Michael Mann'),
        (92, 'Ikiru', 1952, 'Akira Kurosawa'),
        (93, 'A Clockwork Orange', 1971, 'Stanley Kubrick'),
        (94, 'Up', 2009, 'Pete Docter'),
        (95, 'Taxi Driver', 1976, 'Martin Scorsese'),
        (96, 'Reservoir Dogs', 1992, 'Quentin Tarantino'),
        (97, 'To Kill a Mockingbird', 1962, 'Robert Mulligan'),
        (98, 'The Sting', 1973, 'George Roy Hill'),
        (99, 'Lawrence of Arabia', 1962, 'David Lean'),
        (100, 'Vertigo', 1958, 'Alfred Hitchcock');
      SQL
    EOF
  }
}

# Step 7: Helm deploy PostgreSQL with TLS
resource "helm_release" "postgresql" {
  name       = "${var.resource_prefix}postgres"
  namespace  = kubernetes_namespace_v1.teleport_cluster.metadata[0].name
  repository = "oci://registry-1.docker.io/bitnamicharts"
  chart      = "postgresql"
  # version    = "latest"

  wait = false

  values = [
    <<EOF
image:
  registry: docker.io
  repository: bitnamilegacy/postgresql
  tag: latest
volumePermissions:
  image:
    registry: docker.io
    repository: bitnamilegacy/os-shell
    tag: latest
tls:
  enabled: true
  preferServerCiphers: true
  certificatesSecret: ${kubernetes_secret.postgres_tls.metadata[0].name}
  certFilename: tls.crt
  certKeyFilename: tls.key
  certCAFilename: ca.crt

auth:
  username: developer
  password: changeme
  postgresPassword: changeme-postgres
  database: teleport_db

primary:
  extraVolumes:
    - name: custom-init
      configMap:
        name: ${kubernetes_config_map.postgres_custom_init.metadata[0].name}
        defaultMode: 0755
  extraVolumeMounts:
    - name: custom-init
      mountPath: /docker-entrypoint-initdb.d
  pgHbaConfiguration: |-
    local all all trust
    hostssl all teleport-admin all cert
    hostssl all developer all md5
    hostssl all all all cert
  persistence:
      enabled: false
  shmVolume:
    enabled: true
  extraFlags:
    - "-c ssl=on"
    - "-c ssl_ca_file=/opt/bitnami/postgresql/certs/ca.crt"
    - "-c ssl_cert_file=/opt/bitnami/postgresql/certs/tls.crt"
    - "-c ssl_key_file=/opt/bitnami/postgresql/certs/tls.key"
  persistentVolumeClaimRetentionPolicy:
    enabled: true
    whenDeleted: Delete
    whenScaled: Retain

EOF
  ]
}

# ---------------------------------------------------------------------------- #
# Teleport Role
# ---------------------------------------------------------------------------- #
resource "kubectl_manifest" "teleport_role_postgresql" {
  yaml_body = <<EOF
apiVersion: resources.teleport.dev/v1
kind: TeleportRoleV7
metadata:
  annotations:
    teleport.dev/keep: "true"
  finalizers:
    - resources.teleport.dev/deletion
  name: "${var.resource_prefix}postgresql"
  namespace: ${helm_release.teleport_cluster.namespace}
spec:
  options:
    create_db_user_mode: keep
  allow:
    db_labels:
      db: postgres
    db_names:
      - "teleport_db"
      - "*"
    db_roles:
      - "admin"
      - "read_only"
    EOF
}
