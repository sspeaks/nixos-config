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

    backup = {
      enable = true;
      onCalendar = "*-*-* 03:30:00";
      retainCount = 14;
    };
  };

  services.postgresql.settings = {
    shared_buffers = "128MB";
    effective_cache_size = "2GB";
    work_mem = "4MB";
    maintenance_work_mem = "64MB";
    max_connections = 50;
  };
}
