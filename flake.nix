{
  description = "dioxus";

  inputs = {
    nixpkgs = {
      url = "github:CathalMullan/nixpkgs/dioxus-cli-v0.6.0";
    };

    rust-overlay = {
      url = "github:oxalica/rust-overlay";

      inputs = {
        nixpkgs.follows = "nixpkgs";
      };
    };

    android-nixpkgs = {
      url = "github:tadfisher/android-nixpkgs";

      inputs = {
        nixpkgs.follows = "nixpkgs";
      };
    };
  };

  # nix flake show
  outputs =
    {
      nixpkgs,
      rust-overlay,
      android-nixpkgs,
      ...
    }:

    let
      perSystem = nixpkgs.lib.genAttrs nixpkgs.lib.systems.flakeExposed;

      systemPkgs = perSystem (
        system:

        import nixpkgs {
          inherit system;

          config = {
            allowUnfreePredicate =
              pkg:
              builtins.elem (nixpkgs.lib.getName pkg) [
                "Xcode.app"
              ];
          };

          overlays = [
            (import rust-overlay)

            (final: prev: {
              rust-toolchain = prev.rust-bin.stable.latest.default.override {
                targets = [
                  # Desktop
                  "aarch64-apple-darwin"
                  # Web
                  "wasm32-unknown-unknown"
                  # Android
                  "aarch64-linux-android"
                  "armv7-linux-androideabi"
                  "i686-linux-android"
                  "x86_64-linux-android"
                  # iOS
                  "aarch64-apple-ios-sim"
                  "aarch64-apple-ios"
                  "x86_64-apple-ios"
                ];

                extensions = [
                  "clippy"
                  "rust-analyzer"
                  "rust-docs"
                  "rust-src"
                  "rustfmt"
                ];
              };

              android-sdk = android-nixpkgs.sdk.${system} (
                sdkPkgs: with sdkPkgs; [
                  platform-tools
                  cmdline-tools-latest
                  emulator
                  ndk-25-2-9519653
                  platforms-android-33
                  platforms-android-34
                  build-tools-34-0-0
                  system-images-android-34-google-apis-arm64-v8a
                ]
              );
            })
          ];
        }
      );

      perSystemPkgs = f: perSystem (system: f (systemPkgs.${system}));
    in
    {
      devShells = perSystemPkgs (pkgs: {
        # nix develop
        default = pkgs.mkShellNoCC {
          name = "dioxus-shell";

          env = {
            NIX_PATH = "nixpkgs=${nixpkgs.outPath}";
            OPENSSL_NO_VENDOR = "1";

            # iOS
            CARGO_TARGET_AARCH64_APPLE_IOS_SIM_RUSTFLAGS = "-C linker=gcc";
          };

          shellHook = ''
            # iOS
            export SDKROOT="/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneSimulator.platform/Developer/SDKs/iPhoneSimulator.sdk"
            export DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer"

            # Android
            if [ ! -d "$HOME/.android/avd/Dioxus.avd" ]; then
              echo "Creating Android Virtual Device in '$HOME/.android/avd'"
              avdmanager create avd \
                --name "Dioxus" \
                --package "system-images;android-34;google_apis;arm64-v8a" \
                --device "pixel_5"
            fi

            echo ""
            echo "Desktop:"
            echo "  1. dx serve --example hello_world --platform desktop"
            echo ""
            echo "Web:"
            echo "  1. dx serve --example hello_world --platform web"
            echo ""
            echo "Android:"
            echo "  1. emulator -avd Dioxus"
            echo "  2. dx serve --example hello_world --platform android"
            echo ""
            echo "iOS:"
            echo "  1. xcrun simctl boot 'iPhone 15'"
            echo "  2. open -a Simulator"
            echo "  3. dx serve --example hello_world --platform ios"
            echo ""
          '';

          nativeBuildInputs = with pkgs; [
            pkg-config
            openssl
          ];

          buildInputs = with pkgs; [
            # Dioxus
            dioxus-cli

            # Rust
            rust-toolchain

            # Android
            android-sdk
            jdk

            # Nix
            nixfmt-rfc-style
            nixd
            nil
          ];
        };
      });
    };
}
