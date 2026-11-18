{
  description = "Sourcefour — native Git history browser";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }:
    let
      # Start with the platform verified by this fork.
      systems = [ "x86_64-linux" ];
      forAllSystems = nixpkgs.lib.genAttrs systems;
      pkgsFor = system: import nixpkgs { inherit system; };
    in
    {
      packages = forAllSystems (system:
        let
          pkgs = pkgsFor system;
          sourcefour = pkgs.callPackage ./nix/package.nix { };
        in
        {
          inherit sourcefour;
          default = sourcefour;
        });

      apps = forAllSystems (system: {
        default = {
          type = "app";
          program = "${self.packages.${system}.default}/bin/sourcefour";
          meta.description = "Browse Git history in a native window";
        };
      });

      devShells = forAllSystems (system:
        let
          pkgs = pkgsFor system;
          package = self.packages.${system}.default;
        in
        {
          default = pkgs.mkShell {
            inputsFrom = [ package ];
            packages = with pkgs; [
              cargo
              cargo-nextest
              clippy
              ffmpeg
              git
              just
              nixpkgs-fmt
              openssh
              python3
              rustc
              rustfmt
              xdg-utils
            ];
            shellHook = ''
              export LD_LIBRARY_PATH="${package.runtimeLibraryPath}''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
            '';
          };
        });

      checks = forAllSystems (system:
        let
          pkgs = pkgsFor system;
          package = self.packages.${system}.default;
        in
        {
          inherit package;
          # Reuse upstream's real-window smoke test with a software Vulkan GPU.
          gui = pkgs.runCommand "sourcefour-gui-smoke"
            {
              nativeBuildInputs = [ pkgs.xvfb-run pkgs.openbox pkgs.xwininfo ];
              VK_DRIVER_FILES = "${pkgs.mesa}/share/vulkan/icd.d/lvp_icd.x86_64.json";
            } ''
            export HOME="$TMPDIR/home"
            mkdir -p "$HOME"
            xvfb-run -a bash ${./.github/scripts/smoke-linux.sh} ${package}/bin/sourcefour
            touch "$out"
          '';
          cli = pkgs.runCommand "sourcefour-cli-smoke" { } ''
            ${package}/bin/sourcefour --help > help.txt
            grep -F 'usage: sourcefour' help.txt
            if ${package}/bin/sourcefour --not-a-real-option > error.txt 2>&1; then
              echo "Sourcefour accepted an invalid option" >&2
              exit 1
            else
              test "$?" -eq 2
            fi
            touch "$out"
          '';
        });

      formatter = forAllSystems (system: (pkgsFor system).nixpkgs-fmt);
    };
}
