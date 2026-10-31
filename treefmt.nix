{ treefmt-nix, pkgs }:

# One entry point for every formatter, exposed as both `nix fmt` and a flake
# check so CI enforces the same thing a local run produces.
treefmt-nix.lib.evalModule pkgs {
  projectRootFile = "flake.nix";

  # dircolors.conf and the vendored i3lock-fancy-multimonitor directory are
  # upstream content kept verbatim.
  settings.global.excludes = [
    "flake.lock"
    "home/common/zsh/dircolors.conf"
    "home/modules/i3/i3lock-fancy-multimonitor/**"
    "*.ttf"
    "*.jpg"
    "*.png"
  ];

  programs = {
    # The package named `nixfmt` is the RFC 166 style; `nixfmt-classic` is the
    # old one.
    nixfmt.enable = true;
    shellcheck.enable = true;
    shfmt.enable = true;
    prettier.enable = true;
  };

  settings.formatter = {
    prettier.includes = [
      "*.md"
      "*.yaml"
      "*.yml"
      "*.json"
    ];
    # The vendored i3lock-fancy-multimonitor directory, including its `lock`
    # script, is excluded globally above, so these globs do not reach it.
    shellcheck.includes = [
      "*.sh"
      "bin/*"
    ];
    shfmt.includes = [
      "*.sh"
      "bin/*"
    ];
  };
}
