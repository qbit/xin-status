{
  description = "xin-status: a management tool for NixOS machines.";

  inputs.nixpkgs.url = "nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }:
    let
      supportedSystems =
        [ "x86_64-linux" "x86_64-darwin" "aarch64-linux" "aarch64-darwin" ];
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;
      nixpkgsFor = forAllSystems (system: import nixpkgs { inherit system; });
      fyneBuildDeps = pkgs: with pkgs; [
        glfw
        libGL
        libGLU
        pkg-config
        xorg.libXcursor
        xorg.libXi
        xorg.libXinerama
        xorg.libXrandr
        xorg.libXxf86vm
        xorg.xinput

        wayland
        libxkbcommon
      ];
      overlayFunc = _: prev: { inherit (self.packages.${prev.system}) xin xin-status xin-check-restart; };
    in
    {
      nixosModules.default = import ./module.nix;
      overlays.default = overlayFunc;
      packages = forAllSystems (system:
        let
          version = "1.0.1";
          pkgs = nixpkgsFor.${system};
          mkPkg = { pname, useWayland ? true, ... }@args:
            with pkgs;
            buildGoModule (args // {
              inherit pname version;

              src = ./.;

              vendorHash = "sha256-NkNmgxT3jnZC0+vWBDDnmwLPIo55lEtuv22nmM0hkXE=";
              proxyVendor = true;

              nativeBuildInputs = [ pkg-config copyDesktopItems ];
              buildInputs = fyneBuildDeps pkgs;


              buildPhase = if useWayland then ''
                ${fyne}/bin/fyne package --tags wayland
              '' else ''
                ${fyne}/bin/fyne package
              '';

              installPhase = ''
                mkdir -p $out
                pkg="$PWD/xin-status.tar.xz"
                cd $out
                tar --strip-components=1 -xvf $pkg
              '';
            });
        in
        {
          xin-check-restart = pkgs.writeScriptBin "xin-check-restart" ''
            #!${pkgs.perl}/bin/perl

            use strict;
            use warnings;

            use feature 'say';

            my @booted = split("/", `readlink -f /run/booted-system/kernel`);
            my @current = split("/", `readlink -f /run/current-system/kernel`);

            if ($booted[3] ne $current[3]) {
            	say "Restart required!";
            	say "old: $booted[3]";
            	say "new: $current[3]";
                  exit 1;
            } else {
            	say "system is clean..";
            }
          '';
          xin = with pkgs;
            perlPackages.buildPerlPackage {
              pname = "xin";
              inherit version;
              src = ./xin;
              buildInputs = with pkgs; [ perlPackages.JSON procps gawk git ];
              outputs = [ "out" "dev" ];

              installPhase = ''
                mkdir -p $out/bin
                install xin.pl $out/bin/xin
              '';
            };

          xin-status = mkPkg {
            pname = "xintray";
          };
          xin-status-x11 = mkPkg {
            pname = "xin-status-x11";
            useWayland = false;
          };
          default = self.packages.${system}.xin;
        });

      devShells = forAllSystems (system:
        let pkgs = nixpkgsFor.${system};
        in {
          default = pkgs.mkShell {
            shellHook = ''
              PS1='\u@\h:\@; '
              nix run github:qbit/xin#flake-warn
              echo "Go `${pkgs.go}/bin/go version`"
            '';
            buildInputs = with pkgs; [
              go
              gopls
              go-tools
              nilaway
              go-font
            ] ++ (fyneBuildDeps pkgs);
          };
        });

      checks = forAllSystems (system:
        let
          pkgs = import nixpkgs {
            inherit system;
            overlays = [
              overlayFunc
            ];
          };

        in
        {
          xin = pkgs.testers.runNixOSTest {
            name = "xin-check";
            testScript = ''
              machine.start()
              machine.wait_for_unit("multi-user.target")

              # if anything comes out over stderr this will make jq barf
              result = machine.succeed("xin 2>&1 | jq")
            '';
            nodes = {
              xin = { config, pkgs, lib, ... }:
                {
                  imports = [
                    ./module.nix
                  ];

                  boot.loader.systemd-boot.enable = true;
                  boot.loader.efi.canTouchEfiVariables = true;

                  environment.systemPackages = with pkgs; [
                    jq
                  ];

                  nix = {
                    extraOptions = ''
                      experimental-features = nix-command flakes
                    '';
                  };

                  programs.xin.enable = true;
                };
            };
          };
        });
    };
}
