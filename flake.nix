{
  outputs = inputs:
    inputs.flake-parts.lib.mkFlake {inherit inputs;} {
      systems = inputs.nixpkgs.lib.systems.flakeExposed;

      debug = true;
      imports = with inputs; [
        flake-root.flakeModule
        treefmt-nix.flakeModule
        pre-commit-hooks.flakeModule
      ];

      perSystem = {
        pkgs,
        config,
        lib,
        system,
        ...
      }: let
        # Zig flake helper
        # Check the flake.nix in zig2nix project for more options:
        # <https://github.com/Cloudef/zig2nix/blob/master/flake.nix>
        env = inputs.zig2nix.outputs.zig-env.${system} {zig = pkgs.zigpkgs."master-2024-08-02";};
        system-triple = env.lib.zigTripleFromString system;
      in rec {
        _module.args.pkgs = import inputs.nixpkgs {
          inherit system;
          overlays = [inputs.zig.overlays.default];
        };

        pre-commit.settings.hooks.treefmt.enable = true;

        treefmt.config = {
          inherit (config.flake-root) projectRootFile;
          flakeCheck = false;
          programs = {
            alejandra.enable = true;
            zig = {
              enable = true;

              package = pkgs.zigpkgs."master-2024-08-02";
            };
          };
        };

        packages.target = lib.genAttrs env.lib.allTargetTriples (target:
          env.packageForTarget target {
            src = lib.cleanSource ./.;

            # nativeBuildInputs = with env.pkgs; [];
            # buildInputs = with env.pkgsForTarget target; [];

            zigPreferMusl = true;
            zigDisableWrap = true;
          });

        # nix build .
        packages.default = packages.target.${system-triple}.override {
          # Prefer nix friendly settings.
          zigPreferMusl = false;
          zigDisableWrap = false;
        };

        # For bundling with nix bundle for running outside of nix
        # example: https://github.com/ralismark/nix-appimage
        apps.bundle.target = lib.genAttrs env.lib.allTargetTriples (target: let
          pkg = packages.target.${target};
        in {
          type = "app";
          program = "${pkg}/bin/master";
        });

        # default bundle
        apps.bundle.default = apps.bundle.target.${system-triple};

        devShells.default = pkgs.mkShell {
          inputsfrom = [config.pre-commit.devShell];
          packages = with pkgs; [
            zigpkgs."master-2024-08-02"
            glfw
            shaderc
            vulkan-headers
            vulkan-loader
            vulkan-tools

            vulkan-validation-layers
            renderdoc # graphics debugger
            tracy # graphics profiler
            vulkan-tools-lunarg #vkconfig
          ];

          LD_LIBRARY_PATH = lib.makeLibraryPath (with pkgs; [glfw freetype vulkan-loader vulkan-validation-layers]);
        };
      };
    };
  inputs = {
    nixpkgs.url = "nixpkgs/nixpkgs-unstable";
    flake-root.url = "github:srid/flake-root";
    flake-parts.url = "github:hercules-ci/flake-parts";
    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    pre-commit-hooks = {
      url = "github:cachix/pre-commit-hooks.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    zig = {
      url = "github:mitchellh/zig-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    zig2nix = {
      url = "github:Cloudef/zig2nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
}
