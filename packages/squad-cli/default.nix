{ lib
, buildNpmPackage
, fetchurl
}:

buildNpmPackage rec {
  pname = "squad-cli";
  version = "0.13.1";

  src = fetchurl {
    url = "https://registry.npmjs.org/@bradygaster/squad-cli/-/squad-cli-${version}.tgz";
    hash = "sha512-ogfx2nhyx6fqMyqlaI5tDnOzUbRdh+a6Uh/rMQ0aNJwAXnvQp4N37Xp/eOTyB5CxcB7E34NBtAfCxyXbWSiS8w==";
  };

  sourceRoot = "package";

  npmDepsHash = "sha256-9+SheeoUDQsd+XF+P3s1uFabV6PBUMv830TBqoiV6Sk=";
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
