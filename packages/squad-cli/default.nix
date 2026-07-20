{ lib
, buildNpmPackage
, fetchurl
}:

buildNpmPackage rec {
  pname = "squad-cli";
  version = "0.11.0";

  src = fetchurl {
    url = "https://registry.npmjs.org/@bradygaster/squad-cli/-/squad-cli-${version}.tgz";
    hash = "sha512-Dg+r6mlHJqpRfIhHnoQ9qV5M5wRW73L2PQSPT0LSUi2thiFiMtyfl9onn4SHm2TYdMQdWzJMg2EvMUyFkviF1w==";
  };

  sourceRoot = "package";

  npmDepsHash = "sha256-O96MKiZNWkMtPApBx1JI2tWtm58s5pXuOdEo6YghIOY=";
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
