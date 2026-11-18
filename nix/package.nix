{ lib
, rustPlatform
, pkg-config
, cmake
, makeWrapper
, copyDesktopItems
, makeDesktopItem
, fontconfig
, freetype
, libxcb
, libx11
, libxkbcommon
, libglvnd
, wayland
, vulkan-loader
, openssl
, zlib
, git
, openssh
, ffmpeg
, xdg-utils
}:

let
  manifest = lib.importTOML ../Cargo.toml;
  # GPUI loads some graphics libraries dynamically, so linking alone does not
  # retain them in the runtime search path. Do not bundle host GPU drivers.
  runtimeLibraryPath = lib.makeLibraryPath [
    fontconfig
    freetype
    libxcb
    libx11
    libxkbcommon
    libglvnd
    wayland
    vulkan-loader
  ];
  runtimePath = lib.makeBinPath [ git openssh ffmpeg xdg-utils ];
in
rustPlatform.buildRustPackage {
  pname = "sourcefour";
  version = manifest.workspace.package.version;

  # Keep packaging/docs edits from rebuilding the Rust application.
  src = lib.fileset.toSource {
    root = ../.;
    fileset = lib.fileset.unions [
      ../Cargo.toml
      ../Cargo.lock
      ../apps
      ../crates
    ];
  };
  cargoHash = "sha256-unGVySUjNV6xMpfbInaDxPHB3RvphErlMt3z+S9Dqr8=";

  nativeBuildInputs = [
    pkg-config
    cmake
    makeWrapper
    copyDesktopItems
    rustPlatform.bindgenHook
  ];

  buildInputs = [
    fontconfig
    freetype
    libxcb
    libx11
    libxkbcommon
    libglvnd
    wayland
    vulkan-loader
    openssl
    zlib
  ];

  cargoBuildFlags = [ "-p" "sourcefour" ];
  # Upstream runs Rust tests with nextest, never cargo test. The development
  # shell provides `just check`; flake checks cover the installed CLI instead.
  doCheck = false;
  dontUseCmakeConfigure = true;
  strictDeps = true;

  desktopItems = [
    (makeDesktopItem {
      name = "sourcefour";
      desktopName = "Sourcefour";
      comment = "Browse Git history";
      exec = "sourcefour %f";
      icon = "sourcefour";
      categories = [ "Development" "RevisionControl" ];
      terminal = false;
      startupNotify = true;
    })
  ];

  postInstall = ''
    install -Dm644 apps/sourcefour/assets/icon/Sourcefour.png \
      "$out/share/icons/hicolor/512x512/apps/sourcefour.png"
  '';

  postFixup = ''
    wrapProgram "$out/bin/sourcefour" \
      --prefix LD_LIBRARY_PATH : "${runtimeLibraryPath}" \
      --suffix PATH : "${runtimePath}"
  '';

  passthru = { inherit runtimeLibraryPath; };

  meta = {
    description = manifest.workspace.package.description;
    homepage = "https://github.com/HelgeSverre/sourcefour";
    license = lib.licenses.mit;
    mainProgram = "sourcefour";
    platforms = [ "x86_64-linux" ];
  };
}
