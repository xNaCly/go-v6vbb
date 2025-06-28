{
  description = "Go wrapper for v6.vbb.transport.rest for the public transportation system of Berlin & Brandenburg, VBB. ";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = {
    self,
    nixpkgs,
    flake-utils,
  }:
    flake-utils.lib.eachDefaultSystem (system: let
      pkgs = import nixpkgs {inherit system;};

      openapiSpec = pkgs.fetchurl {
        url = "https://v6.vbb.transport.rest/.well-known/service-desc";
        sha256 = "sha256-ssXNJ/T+NmvabM8O9ymPaPLBu0mcGOkKcmbDRVsrDDI=";
      };

      # patch because https://github.com/derhuerst/vbb-rest/issues/69
      patchedSpec = pkgs.runCommand "patched-service-desc.json" {buildInputs = [pkgs.jq];} ''
        cp ${openapiSpec} spec.json
        jq '
                  def walk(f):
                    . as $in
                    | if type == "object" then
                        reduce keys[] as $key
                          ( {}; . + { ($key): ($in[$key] | walk(f)) } ) | f
                      elif type == "array" then map(walk(f)) | f
                      else f
                    end;

                  walk(
                    if type == "object" and .name? == "pretty" and .in? == "path"
                    then .in = "query"
                    else .
                    end
                  )
                ' spec.json > $out
      '';

      oapi-codegen = pkgs.oapi-codegen;
    in {
      devShells.default = pkgs.mkShell {
        buildInputs = [pkgs.go oapi-codegen pkgs.jq];

        shellHook = ''
          oapi-codegen \
            -generate "client,types" \
            -package vbb \
            -o ./vbb/vbb.gen.go \
            ${patchedSpec}
          go mod tidy
        '';
      };
    });
}
