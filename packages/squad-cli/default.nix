{ lib
, buildNpmPackage
, fetchurl
}:

buildNpmPackage rec {
  pname = "squad-cli";
  version = "0.13.0";

  src = fetchurl {
    url = "https://registry.npmjs.org/@bradygaster/squad-cli/-/squad-cli-${version}.tgz";
    hash = "sha512-gsMbYy76M5B30cHmupXrn1pEkFFcb5pZN++y1y5BNA8fmMLKLF3mXU3zCRYw5aW19xvxRF63SiMAqx9MRZgtWg==";
  };

  sourceRoot = "package";

  npmDepsHash = "sha256-phW6siBKrfYHEvgPHMksM4OdlwrPdnugQE7eUSjvc8A=";
  npmInstallFlags = [ "--omit=dev" ];

  postPatch = ''
    cp ${./package-lock.json} package-lock.json
  '';

  buildPhase = ''
    runHook preBuild
    node scripts/patch-esm-imports.mjs
    node scripts/patch-ink-rendering.mjs
    runHook postBuild
  '';

  meta = {
    description = "Command-line interface for the Squad multi-agent runtime";
    homepage = "https://github.com/bradygaster/squad";
    license = lib.licenses.mit;
    mainProgram = "squad";
  };
}
