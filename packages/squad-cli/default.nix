{ lib
, buildNpmPackage
, fetchurl
}:

buildNpmPackage rec {
  pname = "squad-cli";
  version = "0.12.0";

  src = fetchurl {
    url = "https://registry.npmjs.org/@bradygaster/squad-cli/-/squad-cli-${version}.tgz";
    hash = "sha512-EK4eaquow9jeByr/HGmXnsMDeRC+8iiJ0N9mYSDBMnZKD3hp4zP8BzE6F7TfC9El8jaAlXvofiCsUTUC+CNMyw==";
  };

  sourceRoot = "package";

  npmDepsHash = "sha256-u77PLaQnZiyMB+D4Tu30cy+/b/ofyd65O5uw2mL5zN0=";
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
