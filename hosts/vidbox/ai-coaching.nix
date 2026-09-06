{ inputs
, config
, pkgs
, ...
}:
let
  artifacts = inputs.ai-coaching-dashboard.packages.${pkgs.stdenv.hostPlatform.system};
in
{
  services.aiCoaching = {
    enable = true;
    domain = "streams.sspeaks.net";
    bindAddress = "0.0.0.0";
    dataDir = "/var/lib/ai-coaching";
    secretsDir = "/var/lib/ai-coaching/secrets";

    network = {
      name = "ai-coaching";
      subnet = "10.89.1.0/24";
    };

    oidc = {
      enable = true;
      issuerUrl = "https://auth.sspeaks.net/application/o/ai-coaching/";
      clientID = "ai-coaching";
      clientSecretFile = config.sops.secrets.ai-coaching-oidc-client-secret.path;
      cookieSecretFile = config.sops.secrets.ai-coaching-oauth2-proxy-cookie-secret.path;
      redirectURL = "https://streams.sspeaks.net/oauth2/callback";
      scopes = [
        "openid"
        "email"
        "profile"
        "groups"
      ];
      emailClaim = "email";
      groupsClaim = "groups";
      emailDomains = [ "*" ];
      # authentik has no email-verification feature and since 2025.10 reports
      # email_verified = false rather than assert something it cannot prove.
      # Safe here because accounts are admin-provisioned in authentik and users
      # cannot self-register or change their own address; if that ever changes,
      # set this back to false, because the evidence ledger attributes entries
      # to this email.
      allowUnverifiedEmail = true;
      adminGroups = [ "quartet-members" ];
      editorGroups = [ ];
    };
    devAuth.enable = false;

    caddy = {
      enable = true;
      acmeEmail = null;
      externalTls = {
        enable = true;
        httpPort = 8080;
      };
    };

    proxyAuth.environmentFile = config.sops.secrets.ai-coaching-proxy-auth-env.path;

    postgresql = {
      enable = true;
      databaseName = "evidence";
      username = "evidence";
      passwordFile = config.sops.secrets.ai-coaching-postgresql-evidence-password.path;
    };

    speakr = {
      enable = true;
      hostPort = 8899;
      environmentFiles = [ config.sops.secrets.ai-coaching-speakr-env.path ];
    };

    evidenceApi = {
      enable = true;
      image = "ai-coaching/evidence-api:flake";
      imageFile = artifacts.evidence-api-image;
      environmentFiles = [ config.sops.secrets.ai-coaching-evidence-api-env.path ];
    };

    evidenceWorker = {
      enable = true;
      image = "ai-coaching/evidence-worker:flake";
      imageFile = artifacts.evidence-worker-image;
      environmentFiles = [ config.sops.secrets.ai-coaching-evidence-worker-env.path ];
    };

    webFrontend = {
      enable = true;
      mode = "staticRoot";
      staticRoot = artifacts.web-frontend;
    };

    # Backs the worker's http_json extraction provider. Enabling this makes the
    # module set EVIDENCE_EXTRACTION_PROVIDER and EVIDENCE_EXTRACTION_ENDPOINT
    # on the worker; the worker's EVIDENCE_EXTRACTION_API_KEY must equal this
    # container's EXTRACTION_GATEWAY_INBOUND_API_KEY.
    extractionGateway = {
      enable = true;
      image = "ai-coaching/extraction-gateway:flake";
      imageFile = artifacts.extraction-gateway-image;
      environmentFiles = [ config.sops.secrets.ai-coaching-extraction-gateway-env.path ];
    };

    backup = {
      enable = true;
      onCalendar = "*-*-* 03:30:00";
      retainCount = 14;
    };
  };

  # The aiCoaching module writes a pg_hba rule allowing the container subnet to
  # reach PostgreSQL, but never opens the host firewall for it, so the packets
  # are dropped before PostgreSQL ever sees them and the API hangs in
  # init_schema() until its startup probe times out. podman assigns the bridge
  # name, so the module cannot infer it; open the port on that interface here.
  networking.firewall.interfaces."podman1".allowedTCPPorts = [ 5432 ];

  services.postgresql.settings = {
    shared_buffers = "128MB";
    effective_cache_size = "2GB";
    work_mem = "4MB";
    maintenance_work_mem = "64MB";
    max_connections = 50;
  };
}
