{ lib
, buildNpmPackage
, fetchurl
}:

buildNpmPackage rec {
  pname = "squad-cli";
  version = "1.1.0";

  src = fetchurl {
    url = "https://registry.npmjs.org/@bradygaster/squad-cli/-/squad-cli-${version}.tgz";
    hash = "sha512-BrbyctLqv4KqhaOcT9/F097hBMJfqCLLHOPWn0fGFpz9X5g3Kj6+PGXkNRD6DCbuaIzCRhP61MUqpwZLq5Zqkg==";
  };

  sourceRoot = "package";

  npmDepsHash = "sha256-1O9P0mYvmEx0WW1KLEfZ9IkSMENfLYrn/SyTFj7XzJE=";
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
