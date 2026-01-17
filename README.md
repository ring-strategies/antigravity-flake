# Google Antigravity NixOS Flake

A NixOS flake and module for running Google Antigravity on the Linux desktop.

## Usage

### Quick Run (without installation)

```bash
nix run github:ring-strategies/antigravity-flake
```

Or from a local checkout:

```bash
nix run .
```

### NixOS Module

Add to your `flake.nix`:

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    antigravity.url = "github:ring-strategies/antigravity-flake";
  };

  outputs = { self, nixpkgs, antigravity, ... }: {
    nixosConfigurations.your-host = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        antigravity.nixosModules.default
        {
          programs.antigravity = {
            enable = true;
            # Optional: Enable Wayland support
            # enableWayland = true;
            # Optional: Disable GPU acceleration
            # enableGpuAcceleration = false;
            # Optional: Additional command-line args
            # commandLineArgs = [ "--some-flag" ];
          };
        }
      ];
    };
  };
}
```

### Home Manager Module

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager.url = "github:nix-community/home-manager";
    antigravity.url = "github:ring-strategies/antigravity-flake";
  };

  outputs = { self, nixpkgs, home-manager, antigravity, ... }: {
    homeConfigurations.your-user = home-manager.lib.homeManagerConfiguration {
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
      modules = [
        antigravity.homeManagerModules.default
        {
          programs.antigravity = {
            enable = true;
            enableWayland = true;
          };
        }
      ];
    };
  };
}
```

### Standalone Package

Add to your NixOS configuration:

```nix
{
  inputs.antigravity.url = "github:ring-strategies/antigravity-flake";

  outputs = { self, nixpkgs, antigravity, ... }: {
    nixosConfigurations.your-host = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ({ pkgs, ... }: {
          environment.systemPackages = [
            antigravity.packages.x86_64-linux.default
          ];
        })
      ];
    };
  };
}
```

## Configuration Options

### `programs.antigravity.enable`

Whether to enable Google Antigravity.

**Type:** boolean
**Default:** `false`

### `programs.antigravity.package`

The Antigravity package to use.

**Type:** package
**Default:** The package from this flake

### `programs.antigravity.enableWayland`

Enable Wayland support via Ozone platform. This adds the `--enable-features=UseOzonePlatform --ozone-platform=wayland` flags.

**Type:** boolean
**Default:** `false`

### `programs.antigravity.enableGpuAcceleration`

Enable GPU acceleration. Set to `false` to add `--disable-gpu` flag.

**Type:** boolean
**Default:** `true`

### `programs.antigravity.commandLineArgs`

Additional command line arguments to pass to Antigravity.

**Type:** list of strings
**Default:** `[]`
**Example:** `[ "--disable-gpu" "--enable-features=UseOzonePlatform" ]`

## Building

```bash
nix build .#antigravity
```

## Development Shell

```bash
nix develop
```

## License

The packaging code is provided as-is. Google Antigravity itself is proprietary software.
