{ fetchFromGitHub, buildHomeAssistantComponent }:
buildHomeAssistantComponent rec {
  owner = "cavefire";
  domain = "openid";
  version = "1.2.0";
  name = "hass-openid";
  src = fetchFromGitHub {
    owner = "cavefire";
    repo = "hass-openid";
    rev = "1.2.0";
    sha256 = "sha256-tfdTwUWE8dUwN6zie5jPJF3SVa+GngWZwj4MiXEUwAA=";
  };
  # dependencies = [
  #    http
  #    auth
  #  ];
}
