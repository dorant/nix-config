{
  description = "nix-config: standalone home-manager on Ubuntu, nix-darwin on macOS";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

    # The home-manager and nix-darwin releases must match the nixpkgs release;
    # each one's modules are written against that specific nixpkgs.
    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-darwin = {
      url = "github:nix-darwin/nix-darwin/nix-darwin-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Generic, project-independent agent skills, consumed as a plain source
    # tree rather than a flake. The agents module copies the ones it wants out
    # of skills/productivity/. Pinned here and updated with `nix flake update`.
    mattpocock-skills = {
      url = "github:mattpocock/skills";
      flake = false;
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      home-manager,
      nix-darwin,
      treefmt-nix,
      mattpocock-skills,
      ...
    }:
    let
      username = "bjorn";

      linuxSystem = "x86_64-linux";

      # Apple Silicon. Use "x86_64-darwin" on an Intel Mac.
      darwinSystem = "aarch64-darwin";

      systems = [
        linuxSystem
        darwinSystem
      ];
      forAllSystems = nixpkgs.lib.genAttrs systems;

      pkgsFor = forAllSystems (
        system:
        import nixpkgs {
          inherit system;
          config.allowUnfree = true;
        }
      );

      treefmtFor = forAllSystems (
        system:
        import ./treefmt.nix {
          inherit treefmt-nix;
          pkgs = pkgsFor.${system};
        }
      );

      # Repo tasks as flake apps, so CI and a local run execute the same
      # script with the same pinned tools on PATH.
      mkApp =
        system: name: runtimeInputs:
        let
          pkgs = pkgsFor.${system};
        in
        {
          type = "app";
          program = toString (
            pkgs.writeShellApplication {
              inherit name runtimeInputs;
              text = builtins.readFile ./scripts/${name}.sh;
            }
            + "/bin/${name}"
          );
        };
    in
    {
      # Hardware values live in home/users/bjorn/laptop.nix.
      # nix run home-manager/release-26.05 -- switch --flake .#bjorn
      homeConfigurations = {
        ${username} = home-manager.lib.homeManagerConfiguration {
          pkgs = pkgsFor.${linuxSystem};
          extraSpecialArgs = { inherit username mattpocock-skills; };
          modules = [ ./home/users/bjorn/laptop.nix ];
        };

        # stack1 through stack3: identical headless servers, so one config
        # serves all three. Apply on each with:
        #   nix run home-manager/release-26.05 -- switch --flake .#stack
        stack = home-manager.lib.homeManagerConfiguration {
          pkgs = pkgsFor.${linuxSystem};
          extraSpecialArgs = { inherit username mattpocock-skills; };
          modules = [ ./home/users/bjorn/server.nix ];
        };
      };

      # darwin-rebuild switch --flake .#mac
      darwinConfigurations.mac = nix-darwin.lib.darwinSystem {
        system = darwinSystem;
        specialArgs = { inherit username; };
        modules = [
          ./hosts/mac.nix
          home-manager.darwinModules.home-manager
          {
            nixpkgs.pkgs = pkgsFor.${darwinSystem};
            home-manager = {
              useGlobalPkgs = true;
              useUserPackages = true;
              backupFileExtension = "before-nix-darwin";
              # home/common takes username as a module argument.
              extraSpecialArgs = { inherit username mattpocock-skills; };
              users.${username}.imports = [ ./home/users/bjorn/mac.nix ];
            };
          }
        ];
      };

      # `nix flake check` runs these.
      checks = {
        # The one that matters: building the activation package evaluates every
        # module and shellchecks every helper script, without touching $HOME.
        ${linuxSystem} = {
          laptop = self.homeConfigurations.${username}.activationPackage;
          stack = self.homeConfigurations.stack.activationPackage;
          formatting = treefmtFor.${linuxSystem}.config.build.check self;
        };

        # The macOS configuration cannot be built from Linux, so it is scoped
        # to its own system and only checked when run on the Mac.
        ${darwinSystem} = {
          mac = self.darwinConfigurations.mac.system;
          formatting = treefmtFor.${darwinSystem}.config.build.check self;
        };
      };

      apps = forAllSystems (system: {
        lint = mkApp system "lint" (
          with pkgsFor.${system};
          [
            findutils
            gnugrep
            gnused
            coreutils
          ]
        );
      });

      # nix fmt
      formatter = forAllSystems (system: treefmtFor.${system}.config.build.wrapper);
    };
}
