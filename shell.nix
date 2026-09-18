{
  pkgs ? import <nixpkgs> {
    config = {
      allowUnfree = true; # Still needed for some Android SDK components
      android_sdk.accept_license = true;
    };
  },
}:
let
  # Build a custom, minimal Android SDK
  androidEnv = pkgs.androidenv.composeAndroidPackages {
    buildToolsVersions = [
      "34.0.0"
      "35.0.0"
      "36.0.0"
      "37.0.0"
    ];
    platformVersions = [
      "34"
      "35"
      "36"
      "37"
    ];
    abiVersions = [ "x86_64" ]; # CPU architecture for the emulator
    includeNDK = true;
    ndkVersions = [ "28.2.13676358" ]; # Full version string for NDK 28.2 in nixpkgs [[11]]
    cmakeVersions = [ "3.22.1" ];

    # Toggle these based on your needs to save massive amounts of disk space:
    includeEmulator = true; # Set to false if you ONLY use a physical phone
    includeSources = false;
    includeSystemImages = false; # System images are HUGE (several GBs). Keep false unless you strictly need the emulator.
  };
in
pkgs.mkShell {
  packages = [
    pkgs.flutter
    androidEnv.androidsdk # The minimal CLI-based Android SDK

    # Essential tools for building and fetching dependencies
    pkgs.jdk17 # Modern Flutter/Android requires JDK 17
    pkgs.git
    pkgs.unzip
    pkgs.curl
  ];

  # Environment variables to tell Flutter and Gradle where everything is
  ANDROID_HOME = "${androidEnv.androidsdk}/libexec/android-sdk";
  ANDROID_SDK_ROOT = "${androidEnv.androidsdk}/libexec/android-sdk";
  JAVA_HOME = "${pkgs.jdk17}";

  # Optional: Helps Flutter find its own root
  FLUTTER_ROOT = "${pkgs.flutter}";
}
