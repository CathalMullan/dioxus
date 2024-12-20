{
  description = "dioxus";

  inputs = {
    nixpkgs = {
      url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    };

    rust-overlay = {
      url = "github:oxalica/rust-overlay";

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
      ...
    }:

    let
      perSystem = nixpkgs.lib.genAttrs nixpkgs.lib.systems.flakeExposed;

      systemPkgs = perSystem (
        system:

        import nixpkgs {
          inherit system;

          overlays = [
            (import rust-overlay)

            (final: prev: {
              rustToolchain = prev.rust-bin.stable."1.79.0".minimal.override {
                targets = [ "wasm32-unknown-unknown" ];
                extensions = [
                  "clippy"
                  "rust-analyzer"
                  "rust-docs"
                  "rust-src"
                  "rustfmt"
                ];
              };
            })
          ];
        }
      );

      perSystemPkgs = f: perSystem (system: f (systemPkgs.${system}));
    in
    {
      devShells = perSystemPkgs (pkgs: {
        # nix develop
        default = pkgs.mkShell {
          name = "dioxus-shell";

          env = {
            NIX_PATH = "nixpkgs=${nixpkgs.outPath}";

            RUSTC_WRAPPER = "${pkgs.sccache}/bin/sccache";
            CARGO_INCREMENTAL = "0";

            OPENSSL_NO_VENDOR = "1";
          };

          buildInputs = with pkgs; [
            # Rust
            rustToolchain
            sccache
            pkg-config
            cacert
            openssl
            glib
            gtk3
            libsoup_3
            webkitgtk_4_1
            xdotool

            # WASM
            (wasm-bindgen-cli.override {
              version = "0.2.99";
              hash = "sha256-1AN2E9t/lZhbXdVznhTcniy+7ZzlaEp/gwLEAucs6EA=";
              cargoHash = "sha256-DbwAh8RJtW38LJp+J9Ht8fAROK9OabaJ85D9C/Vkve4=";
            })

            # TOML
            taplo

            # Nix
            nixfmt-rfc-style
            nixd
            nil
          ];
        };
      });
    };
}
