{
  pkgs ? import <nixpkgs> { },
  rustToolchain ? [
    pkgs.rustc
    pkgs.cargo
  ],
  debug ? false,
  gtk3 ? true,
  gtk4 ? true,
  qt5 ? false,
  qt6 ? true,
}:
let
  src = pkgs.lib.cleanSourceWith {
    src = ./.;
    filter =
      path: type:
      let
        baseName = baseNameOf path;
      in
      pkgs.lib.cleanSourceFilter path type
      && !(baseName == "build" && type == "directory")
      && !(baseName == "target" && type == "directory");
  };
  deps = import ./nix/deps.nix {
    inherit
      pkgs
      gtk3
      gtk4
      qt5
      qt6
      ;
  };
  kimeVersion = pkgs.lib.fileContents ./VERSION;
  cargoProfile = if debug then "debug" else "release";
  inherit (pkgs) lib rustPlatform;
  inherit (deps) llvmPackages;
in
llvmPackages.stdenv.mkDerivation {
  name = "kime";
  inherit src;
  buildInputs = deps.kimeBuildInputs;
  nativeBuildInputs =
    deps.kimeNativeBuildInputs
    ++ (lib.toList rustToolchain)
    ++ [
      rustPlatform.cargoSetupHook
      pkgs.makeBinaryWrapper
    ];
  version = kimeVersion;
  cargoDeps = rustPlatform.importCargoLock {
    lockFile = ./Cargo.lock;
  };
  LIBCLANG_PATH = "${llvmPackages.libclang.lib}/lib";
  dontWrapQtApps = true;

  mesonFlags = [
    "-Dcargo_profile=${cargoProfile}"
    (lib.mesonEnable "gtk3" gtk3)
    (lib.mesonEnable "gtk4" gtk4)
    (lib.mesonEnable "qt5" qt5)
    (lib.mesonEnable "qt6" qt6)
  ]
  ++ lib.optional qt5 "-Dqt5_plugindir=${placeholder "out"}/${pkgs.qt5.qtbase.qtPluginPrefix}"
  ++ lib.optional qt6 "-Dqt6_plugindir=${placeholder "out"}/${pkgs.qt6.qtbase.qtPluginPrefix}";

  postFixup = ''
    substituteInPlace $out/bin/kime-xdg-autostart \
      --replace-fail "/usr/bin/kime" "$out/bin/kime"

    substituteInPlace \
      $out/share/applications/kime.desktop \
      $out/etc/xdg/autostart/kime.desktop \
      --replace-fail "/usr/bin/kime-xdg-autostart" "$out/bin/kime-xdg-autostart"

    wrapProgram $out/bin/kime-wayland \
      --prefix LD_LIBRARY_PATH : "${pkgs.lib.makeLibraryPath [ pkgs.wayland ]}"

    wrapProgram $out/bin/kime-candidate-window \
      --prefix LD_LIBRARY_PATH : "${
        pkgs.lib.makeLibraryPath [
          pkgs.libGL
          pkgs.wayland
          pkgs.libxkbcommon
          pkgs.libxcb
          pkgs.libX11
          pkgs.libXcursor
          pkgs.libXi
          pkgs.libXrandr
        ]
      }"

    wrapProgram $out/bin/kime \
      --prefix PATH : "$out/bin"
  '';
  doCheck = true;
  checkPhase = ''
    cargo test ${if debug then "" else "--release"}
  '';
}
