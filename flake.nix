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
    in
    {
      nixosModules.default = import ./module.nix;
      overlays.default = _: prev: { inherit (self.packages.${prev.system}) xin xin-status; };
      packages = forAllSystems (system:
        let
          version = "1.0.0";
          pkgs = nixpkgsFor.${system};
        in
        {
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

          xin-status = with pkgs;
            buildGoModule rec {
              pname = "xin-status";
              inherit version;

              src = ./.;

              vendorHash = "sha256-xmfCLcvCda31i1z+acOqA8IRq9ImexHQorbYulX07/I=";
              proxyVendor = true;

              nativeBuildInputs = [ pkg-config copyDesktopItems ];
              buildInputs = fyneBuildDeps pkgs;


              buildPhase = ''
                ${fyne}/bin/fyne package
              '';

              installPhase = ''
                mkdir -p $out
                pkg="$PWD/${pname}.tar.xz"
                cd $out
                tar --strip-components=1 -xvf $pkg
              '';
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
              (_: prev: { inherit (self.packages.${prev.system}) xin xin-status; })
            ];
          };

        in
        {
          xin = pkgs.testers.runNixOSTest {
            name = "xin-check";
            testScript = ''
              machine.start()
              machine.wait_for_unit("multi-user.target")

              result = machine.succeed("xin | jq -r '.cpu_usage' | grep -E '[0-9]+\.[0-9]+'")
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
                  programs.xin.enable = true;
                };
            };
          };
        });
    };
}
