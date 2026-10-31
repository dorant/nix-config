{ pkgs, ... }:

let
  # The San Francisco faces are Apple-licensed and the vendored FontAwesome
  # build predates the nixpkgs one, so both ship with this repo rather than
  # coming from nixpkgs. Some filenames contain spaces, so copy the directory
  # wholesale rather than globbing.
  vendored = pkgs.runCommand "vendored-fonts" { } ''
    mkdir -p $out/share/fonts/truetype
    cp -r ${./fonts}/. $out/share/fonts/truetype/
  '';
in
{
  home.packages = [ vendored ];

  fonts.fontconfig.enable = true;
}
