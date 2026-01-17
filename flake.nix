{
  description = "Google Antigravity - A flake for running Google Antigravity on NixOS";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    let
      supportedSystems = [ "x86_64-linux" ];

      # Package definition that can be used across the flake
      mkAntigravity = { pkgs }:
        let
          version = "1.14.2";
          pname = "antigravity";

          src = pkgs.fetchurl {
            url = "https://edgedl.me.gvt1.com/edgedl/release2/j0qc3/antigravity/stable/1.14.2-6046590149459968/linux-x64/Antigravity.tar.gz";
            sha256 = "0jd4ir8iw4yhljkv6dgb9h4idypyrxqxs91cjpva2rzw3q609yyz";
          };

          # Runtime dependencies for the Electron app
          runtimeLibs = with pkgs; [
            # GTK and related
            gtk3
            glib
            gdk-pixbuf
            pango
            cairo
            atk
            at-spi2-atk
            at-spi2-core

            # X11
            xorg.libX11
            xorg.libXcomposite
            xorg.libXdamage
            xorg.libXext
            xorg.libXfixes
            xorg.libXrandr
            xorg.libxcb
            xorg.libxkbfile

            # System libraries
            dbus
            expat
            nspr
            nss
            cups
            libdrm
            mesa
            libxkbcommon
            alsa-lib
            systemd # for libudev

            # Graphics
            libGL
            libGLU
            vulkan-loader

            # Additional commonly needed libs
            libsecret
            libnotify
            stdenv.cc.cc.lib
          ];

        in pkgs.stdenv.mkDerivation {
          inherit pname version src;

          nativeBuildInputs = with pkgs; [
            autoPatchelfHook
            makeWrapper
            wrapGAppsHook3
            copyDesktopItems
          ];

          buildInputs = runtimeLibs;

          dontConfigure = true;
          dontBuild = true;
          dontWrapGApps = true;

          sourceRoot = ".";

          installPhase = ''
            runHook preInstall

            mkdir -p $out/opt/antigravity
            cp -r Antigravity/* $out/opt/antigravity/

            # Create wrapper script
            mkdir -p $out/bin
            makeWrapper $out/opt/antigravity/antigravity $out/bin/antigravity \
              "''${gappsWrapperArgs[@]}" \
              --prefix LD_LIBRARY_PATH : "${pkgs.lib.makeLibraryPath runtimeLibs}" \
              --prefix LD_LIBRARY_PATH : "$out/opt/antigravity" \
              --prefix PATH : "${pkgs.lib.makeBinPath [ pkgs.xdg-utils ]}" \
              --set ELECTRON_IS_DEV 0

            # Install icon
            mkdir -p $out/share/icons/hicolor/512x512/apps
            cp $out/opt/antigravity/resources/app/resources/linux/code.png \
               $out/share/icons/hicolor/512x512/apps/antigravity.png

            # Install desktop file
            mkdir -p $out/share/applications
            cat > $out/share/applications/antigravity.desktop <<EOF
            [Desktop Entry]
            Name=Google Antigravity
            Comment=Google Antigravity Application
            Exec=$out/bin/antigravity %U
            Icon=antigravity
            Type=Application
            Categories=Development;Utility;
            StartupNotify=true
            StartupWMClass=Antigravity
            MimeType=x-scheme-handler/antigravity;
            EOF

            # Install shell completions
            mkdir -p $out/share/bash-completion/completions
            mkdir -p $out/share/zsh/site-functions
            if [ -f $out/opt/antigravity/resources/completions/bash/antigravity ]; then
              cp $out/opt/antigravity/resources/completions/bash/antigravity \
                 $out/share/bash-completion/completions/antigravity
            fi
            if [ -f $out/opt/antigravity/resources/completions/zsh/_antigravity ]; then
              cp $out/opt/antigravity/resources/completions/zsh/_antigravity \
                 $out/share/zsh/site-functions/_antigravity
            fi

            runHook postInstall
          '';

          meta = with pkgs.lib; {
            description = "Google Antigravity";
            homepage = "https://google.com";
            license = licenses.unfree;
            platforms = [ "x86_64-linux" ];
            mainProgram = "antigravity";
          };
        };

    in
    {
      # NixOS module
      nixosModules.default = { config, lib, pkgs, ... }:
        let
          cfg = config.programs.antigravity;
        in
        {
          options.programs.antigravity = {
            enable = lib.mkEnableOption "Google Antigravity";

            package = lib.mkOption {
              type = lib.types.package;
              default = mkAntigravity { inherit pkgs; };
              defaultText = lib.literalExpression "pkgs.antigravity";
              description = "The Antigravity package to use.";
            };

            commandLineArgs = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              default = [ ];
              example = [ "--disable-gpu" "--enable-features=UseOzonePlatform" "--ozone-platform=wayland" ];
              description = "Additional command line arguments to pass to Antigravity.";
            };

            enableWayland = lib.mkOption {
              type = lib.types.bool;
              default = false;
              description = "Enable Wayland support via Ozone platform.";
            };

            enableGpuAcceleration = lib.mkOption {
              type = lib.types.bool;
              default = true;
              description = "Enable GPU acceleration.";
            };
          };

          config = lib.mkIf cfg.enable {
            environment.systemPackages =
              let
                finalArgs = cfg.commandLineArgs
                  ++ lib.optionals cfg.enableWayland [
                    "--enable-features=UseOzonePlatform"
                    "--ozone-platform=wayland"
                  ]
                  ++ lib.optionals (!cfg.enableGpuAcceleration) [
                    "--disable-gpu"
                  ];

                wrappedPackage = if finalArgs == [ ] then cfg.package else
                  pkgs.symlinkJoin {
                    name = "antigravity-wrapped";
                    paths = [ cfg.package ];
                    buildInputs = [ pkgs.makeWrapper ];
                    postBuild = ''
                      wrapProgram $out/bin/antigravity \
                        --add-flags "${lib.escapeShellArgs finalArgs}"
                    '';
                  };
              in
              [ wrappedPackage ];

            # Enable necessary services for Electron apps
            services.dbus.enable = lib.mkDefault true;

            # XDG portal for file dialogs, etc.
            xdg.portal = {
              enable = lib.mkDefault true;
            };
          };
        };

      # Home-manager module for per-user configuration
      homeManagerModules.default = { config, lib, pkgs, ... }:
        let
          cfg = config.programs.antigravity;
        in
        {
          options.programs.antigravity = {
            enable = lib.mkEnableOption "Google Antigravity";

            package = lib.mkOption {
              type = lib.types.package;
              default = mkAntigravity { inherit pkgs; };
              defaultText = lib.literalExpression "pkgs.antigravity";
              description = "The Antigravity package to use.";
            };

            commandLineArgs = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              default = [ ];
              example = [ "--disable-gpu" ];
              description = "Additional command line arguments to pass to Antigravity.";
            };

            enableWayland = lib.mkOption {
              type = lib.types.bool;
              default = false;
              description = "Enable Wayland support via Ozone platform.";
            };

            enableGpuAcceleration = lib.mkOption {
              type = lib.types.bool;
              default = true;
              description = "Enable GPU acceleration.";
            };

            settings = lib.mkOption {
              type = lib.types.attrs;
              default = { };
              description = "Settings to write to Antigravity's config file.";
            };
          };

          config = lib.mkIf cfg.enable {
            home.packages =
              let
                finalArgs = cfg.commandLineArgs
                  ++ lib.optionals cfg.enableWayland [
                    "--enable-features=UseOzonePlatform"
                    "--ozone-platform=wayland"
                  ]
                  ++ lib.optionals (!cfg.enableGpuAcceleration) [
                    "--disable-gpu"
                  ];

                wrappedPackage = if finalArgs == [ ] then cfg.package else
                  pkgs.symlinkJoin {
                    name = "antigravity-wrapped";
                    paths = [ cfg.package ];
                    buildInputs = [ pkgs.makeWrapper ];
                    postBuild = ''
                      wrapProgram $out/bin/antigravity \
                        --add-flags "${lib.escapeShellArgs finalArgs}"
                    '';
                  };
              in
              [ wrappedPackage ];
          };
        };

    } // flake-utils.lib.eachSystem supportedSystems (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          config.allowUnfree = true;
        };
      in
      {
        packages = {
          antigravity = mkAntigravity { inherit pkgs; };
          default = self.packages.${system}.antigravity;
        };

        apps = {
          antigravity = {
            type = "app";
            program = "${self.packages.${system}.antigravity}/bin/antigravity";
          };
          default = self.apps.${system}.antigravity;
        };

        # Development shell for testing
        devShells.default = pkgs.mkShell {
          buildInputs = [ self.packages.${system}.antigravity ];
        };
      }
    );
}
