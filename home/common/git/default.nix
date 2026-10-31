{ ... }:

{
  # 26.05 merged the old `aliases` and `extraConfig` options into a single
  # `settings` attrset that mirrors git's own config layout.
  programs.git = {
    enable = true;
    settings = {
      alias = {
        co = "checkout";
        br = "branch";
        ci = "commit";
        st = "status";
      };
      pager.branch = false;
      init.defaultBranch = "main";
    };
  };
}
