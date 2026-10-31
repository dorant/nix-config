{
  config,
  pkgs,
  lib,
  mattpocock-skills,
  ...
}:

let
  cfg = config.my.agents;

  # The rules in ./rules are tool-agnostic prose: how to write comments, how to
  # format text, which git commands are allowed. Each agent below adapts them
  # to its own layout, so the content is written once.
  #
  # cp -L dereferences, because these are mounted into containers that do not
  # have /nix/store and so cannot follow a store symlink.
  rulesDir = pkgs.runCommand "agent-rules" { } ''
    mkdir -p $out
    cp -L ${./rules}/*.md $out/
  '';

  # Generic, project-independent skills, laid out as one <name>/SKILL.md
  # directory per skill. Both Kiro (~/.kiro/skills) and Claude (~/.claude/skills)
  # read this layout. Project-specific skills do not live here: they belong in
  # the project repo under .kiro/skills or .claude/skills, which both agents
  # already see through the mounted working directory.
  #
  # The mattpocock skills come from the pinned source tree, under
  # skills/productivity/<name>. cp -L dereferences the store symlinks for the
  # same reason as rulesDir: the containers have no /nix/store to follow.
  mattpocockSkills = [
    "grill-me"
    "grilling"
    "teach"
    "wait-what"
    "writing-for-agents"
  ];
  skillsDir = pkgs.runCommand "agent-skills" { } ''
    mkdir -p $out
    ${lib.concatMapStringsSep "\n" (name: ''
      cp -rL ${mattpocock-skills}/skills/productivity/${name} $out/${name}
      chmod -R u+w $out/${name}
    '') mattpocockSkills}
  '';

  # Claude reads one context file rather than a directory, so the rules are
  # concatenated under a heading naming their source.
  claudeContext = pkgs.runCommand "claude-md" { } ''
    {
      echo "# Working agreements"
      echo
      echo "Generated from home/modules/agents/rules. Edit there, not here."
      for f in ${rulesDir}/*.md; do
        echo
        cat "$f"
      done
    } > $out
  '';

  # Kiro's default agent. autoAllowReadonly covers the generic read-only case;
  # allowedCommands adds the specific build/render/inspect commands that look
  # mutating to that heuristic but only touch the local tree. Everything here
  # either reads state or produces local output; nothing mutates a remote or
  # runs arbitrary code. The list is adapted from the Claude Code permissions
  # allowlist in the reference config, translated to Kiro's schema.
  #
  # Mounted read-only and selected with `--agent default` rather than written
  # into settings/cli.json, which Kiro owns and rewrites itself.
  kiroAgent = pkgs.writeText "default-agent.json" (
    builtins.toJSON {
      name = "default";
      description = "Default agent with a read-only command allowlist.";

      # @builtin grants every built-in tool the installed Kiro version ships,
      # rather than a hand-listed set. The names were version-specific (1.x had
      # fs_read/fs_write/execute_bash; 2.x renamed them read/write/shell), so an
      # explicit list silently loses tools on an upgrade: the renamed ones stop
      # resolving and the shell tool goes missing. @builtin tracks the rename.
      # What the agent may do without prompting is governed by allowedTools and
      # toolsSettings below, not by this field.
      tools = [ "@builtin" ];

      # Steering and the host project's docs are always loaded; skills are
      # discovered and loaded on demand via the skill:// scheme.
      #
      # Steering and the generic skills live under $HOME/.kiro (mounted into the
      # container from the flake), so they use absolute paths. The project's own
      # docs and any project-local skills are relative to the working directory.
      # Projects lay their skills out under .agents/skills, .kiro/skills or
      # .claude/skills, so all three are globbed. .agents/skills is listed first
      # as the preferred layout; whether order decides a same-name collision
      # across these dirs is undocumented, and in practice a project uses one.
      resources = [
        "file://AGENTS.md"
        "file://README.md"
        "file:///home/${cfg.containerUser}/.kiro/steering/**/*.md"
        "skill:///home/${cfg.containerUser}/.kiro/skills/**/SKILL.md"
        "skill://.agents/skills/**/SKILL.md"
        "skill://.kiro/skills/**/SKILL.md"
        "skill://.claude/skills/**/SKILL.md"
      ];

      # Read-only built-ins auto-approved; the mutating ones (write, shell) still
      # prompt, except for the shell commands allowlisted below. Names are the
      # 2.x built-ins (read, not fs_read; shell, not execute_bash).
      allowedTools = [
        "read"
        "grep"
        "glob"
        "introspect"
        "todo_list"
      ];

      toolsSettings = {
        shell = {
          autoAllowReadonly = true;
          # Entries are regexes that appear to be matched against the whole
          # command, so a bare "gh pr view" only allows the command with no
          # arguments. The `( [^;&|`$<>()\n\r]*)?( 2>&1)?` suffix admits any
          # arguments free of shell metacharacters and newlines, so a chained
          # "gh pr view 1; rm ..." does not match, plus the trailing 2>&1 that
          # agents append.
          allowedCommands = [
            # git (read-only)
            "git status( [^;&|`$<>()\\n\\r]*)?( 2>&1)?"
            "git diff"
            "git show"
            "git log"
            # --no-pager is how agents get diff output without a pager waiting
            # for input.
            "git --no-pager diff( [^;&|`$<>()\\n\\r]*)?( 2>&1)?"
            # Prints an object's type, size or contents; writes nothing.
            "git cat-file( [^;&|`$<>()\\n\\r]*)?( 2>&1)?"
            # Worktrees, limited to what the git steering rules permit: list,
            # and add under .worktrees/ at an existing ref. The path must
            # directly follow `add`, which keeps out -b/-B (create or reset a
            # branch) and --force, and the ref may not start with "-". remove,
            # prune and move are left to prompt.
            "git worktree list( [^;&|`$<>()\\n\\r]*)?( 2>&1)?"
            "git worktree add( --detach)? \\.worktrees/[A-Za-z0-9][A-Za-z0-9._-]* [^-;&|`$<>()\\n\\r ][^;&|`$<>()\\n\\r ]*( 2>&1)?"
            # Computes a common ancestor and prints it; never moves a ref.
            "git merge-base( [^;&|`$<>()\\n\\r]*)?( 2>&1)?"
            # gh (read-only)
            "gh pr view( [^;&|`$<>()\\n\\r]*)?( 2>&1)?"
            "gh pr diff( [^;&|`$<>()\\n\\r]*)?( 2>&1)?"
            "gh search"
            # Filesystem listing. find is allowed only because deniedCommands
            # below rejects its acting and file-writing options.
            "ls( [^;&|`$<>()\\n\\r]*)?( 2>&1)?"
            "find( [^;&|`$<>()\\n\\r]*)?( 2>&1)?"
            # Go, all subcommands. Broader than a build/test/vet list: go run,
            # go generate and go install execute code and fetch modules.
            "go( [^;&|`$<>()\\n\\r]*)?( 2>&1)?"
            "gofmt"
            # kind, all subcommands. Only does anything in kiro-fi, which mounts
            # the Docker socket kind needs; elsewhere it fails to reach Docker.
            # Includes `kind delete cluster`, which removes a cluster outright.
            "kind( [^;&|`$<>()\\n\\r]*)?( 2>&1)?"
            # make, for the operator's build harness: envtest provisioning, code
            # generation, manifests. Runs arbitrary recipes, so it is as broad a
            # grant as `go` above; accepted for the same reason.
            "make"
            # Helm (local render / lint)
            "helm template"
            "helm lint"
            "helm version"
            # kubectl (read-only verbs only; no apply/delete/patch/scale/exec, so
            # the agent can inspect the cluster but not mutate it).
            "kubectl get"
            "kubectl describe"
            "kubectl logs"
            "kubectl explain"
            "kubectl version"
            "kubectl api-resources"
            "kubectl config get-contexts"
            "kubectl config current-context"
          ];
          # find options that delete files, run commands or write files. These
          # make an otherwise read-only find act on the filesystem, and an
          # allowedCommands regex cannot exclude them (no lookahead).
          deniedCommands = [
            "find( .*)? -(delete|exec|execdir|ok|okdir|fprint|fprint0|fprintf|fls)( .*)?"
          ];
        };
      };
    }
  );

  # Shared by every wrapper: the project directory, and nothing else from the
  # host filesystem. The short mount list is the actual isolation boundary, not
  # the container's non-root user, whose uid matches the host user's.
  #
  # The project mounts at the same absolute path it has on the host, so paths
  # in agent output and error messages match what you see outside the
  # container, and Kiro's per-directory session history is keyed to the real
  # project path. Two projects sharing a basename but living in different
  # directories therefore get separate histories, which a basename-only scheme
  # could not guarantee.
  #
  # $HOME inside the container stays /home/${cfg.containerUser}; only the
  # working directory mirrors the host. The config mounts below live under that
  # home and are unaffected.
  baseMounts = ''
    -v "$PWD:$PWD" \
    -w "$PWD" \
  '';

  # Kubernetes access for working against a cluster created on the host.
  #
  # --network host is required because a kind cluster publishes its API server
  # on a host port and its kubeconfig names 127.0.0.1, which inside a container
  # is the container. It exposes host network services to the container, which
  # is a far smaller grant than the Docker socket: it cannot start privileged
  # containers on the host.
  #
  # mode is "ro" for wrappers that only read the kubeconfig (so `kubectl config
  # use-context` cannot change the host's current context) and "rw" for kiro-fi,
  # where `kind create cluster` must write the new cluster's credentials and the
  # config.lock beside them. A read-only mount fails kind at the final step with
  # "config.lock: read-only file system".
  kubeMounts = user: mode: ''
    --network host \
    -v "$HOME/.kube:/home/${user}/.kube:${mode}" \
    -e KUBECONFIG="/home/${user}/.kube/config" \
  '';

  # The host Docker socket, for the fault-injection / build wrappers. Mounting
  # the socket alone is not enough: the container user is uid 1000 with no
  # supplementary groups, but the socket is typically root:docker mode 0660, so
  # a bare mount gives "permission denied". --group-add with the socket's own
  # gid, read off the host at run time, lets that user talk to it without
  # hardcoding a gid that differs across hosts. stat -L follows the symlink
  # /var/run usually is.
  socketMount = ''
    -v /var/run/docker.sock:/var/run/docker.sock \
    --group-add "$(stat -Lc '%g' /var/run/docker.sock)" \
  '';

  # Hardening that costs nothing for these workloads. Capabilities are already
  # empty for a non-root process; dropping the bounding set stops any being
  # regained, and no-new-privileges blocks setuid escalation.
  hardening = ''
    --cap-drop=ALL \
    --security-opt=no-new-privileges \
    --pids-limit=2048 \
  '';

  # dockerArgs are flags for `docker run` and precede the image name.
  # command is passed to the containerised program and follows it, ahead of
  # any arguments the user supplied.
  #
  # resumeExtra, when set, is appended only when the user passed no arguments
  # of their own. It lets the bare `kiro-cli` resume the current project's
  # session while leaving `kiro-cli chat`, `kiro-cli --resume-picker` and the
  # like to run exactly as typed.
  mkWrapper =
    {
      name,
      image,
      dockerArgs ? "",
      configMounts ? "",
      command ? "",
      resumeExtra ? "",
      setup ? "",
    }:
    pkgs.writeShellApplication {
      inherit name;
      runtimeInputs = [
        pkgs.docker
        pkgs.git
      ];
      text = ''
        # No arguments: append the resume flag. Any argument: pass it verbatim
        # and add nothing, so an explicit invocation is never second-guessed.
        extra=""
        if [ "$#" -eq 0 ]; then
          extra="${resumeExtra}"
        fi

        ${setup}

        # A git worktree's .git is a file pointing at the main clone's
        # .git/worktrees/<name>, which lives outside $PWD and so is not covered
        # by the $PWD mount. Without it the worktree's gitdir pointer dangles
        # inside the container and git operations fail. Mount the common git
        # dir read-only at its real path so the pointer resolves. Empty for a
        # normal clone, where .git is a directory inside $PWD already.
        worktree_mount=()
        if common_git=$(git -C "$PWD" rev-parse --git-common-dir 2>/dev/null); then
          common_git=$(realpath "$common_git")
          case "$common_git" in
            "$PWD"/*) ;;  # already inside the mounted working directory
            *) worktree_mount=(-v "$common_git:$common_git:ro") ;;
          esac
        fi

        exec docker run -it --rm \
          ${hardening} ${baseMounts} ${configMounts} ${dockerArgs} \
          "''${worktree_mount[@]}" \
          ${image} ${command} ''${extra:+$extra} "$@"
      '';
    };
in
{
  options.my.agents = {
    enable = lib.mkEnableOption ''
      wrappers and configuration for the containerised coding agents. The
      container images are built outside this flake; only their configuration
      and invocation are managed here
    '';

    containerUser = lib.mkOption {
      type = lib.types.str;
      default = "user";
      description = ''
        Username inside the agent images, which determines the home directory
        the config mounts land in.
      '';
    };

    kiro = {
      enable = lib.mkEnableOption "the Kiro CLI container wrappers";

      image = lib.mkOption {
        type = lib.types.str;
        default = "kiro-cli:latest";
        description = "Image tag for the Kiro CLI container.";
      };
    };

    claude = {
      enable = lib.mkEnableOption "the Claude Code container wrappers";

      image = lib.mkOption {
        type = lib.types.str;
        default = "claude:latest";
        description = "Image tag for the Claude Code container.";
      };

      containerUser = lib.mkOption {
        type = lib.types.str;
        default = "node";
        description = ''
          The Claude image runs as a different user than the Kiro image, so its
          config mounts need their own home path.
        '';
      };
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages =
      lib.optionals cfg.kiro.enable [
        # Kiro. Steering rules are mounted read-only from the store; general
        # state and credentials stay in the kiro-config volume. Per-session
        # conversation history is written under ~/.kiro/sessions, outside
        # ~/.local/share, so that directory is bind-mounted from the host's own
        # ~/.kiro/sessions. The project mounts at its host path, so the cwd each
        # session records is a real host path and a host-run Kiro sees the same
        # sessions.
        #
        # `chat --agent default` is appended to the image's ENTRYPOINT
        # (`kiro-cli --classic`). --agent selects the mounted default.json rather
        # than relying on chat.defaultAgent in cli.json, which Kiro owns.
        #
        # A bare `kiro-cli` adds --resume, continuing the current project's last
        # session (or starting fresh when there is none; --resume is a no-op
        # then). Per-project mounting (see baseMounts) keys that history to this
        # project. To start a new session instead, run `kiro-cli chat`; any
        # explicit argument suppresses the implicit --resume.
        (mkWrapper {
          name = "kiro-cli";
          image = cfg.kiro.image;
          configMounts = ''
            -v kiro-config:/home/${cfg.containerUser}/.local/share/ \
            -v "$HOME/.kiro/sessions:/home/${cfg.containerUser}/.kiro/sessions" \
            -v ${rulesDir}:/home/${cfg.containerUser}/.kiro/steering:ro \
            -v ${skillsDir}:/home/${cfg.containerUser}/.kiro/skills:ro \
            -v ${kiroAgent}:/home/${cfg.containerUser}/.kiro/agents/default.json:ro \
          '';
          dockerArgs =
            kubeMounts cfg.containerUser "ro" + ''-e GH_TOKEN="$GH_VALKEY_OPERATOR_READONLY_TOKEN"'';
          command = "chat --agent default";
          resumeExtra = "--resume";
          # Docker creates a missing bind-mount source as root, which the
          # uid-1000 container user then cannot write to.
          setup = ''mkdir -p "$HOME/.kiro/sessions"'';
        })

        # Fault-injection / build Kiro: everything the everyday kiro-cli has, plus
        # the host Docker socket. The socket is needed to `docker build` the
        # operator image and `kind load` it onto the cluster nodes, and for
        # crictl/nsenter fault injection inside the kind node. It is root-
        # equivalent on the host (anything holding it can start a privileged
        # container that mounts /), so it rides a separate, deliberately-named
        # command rather than the default agent. kind is in the image (see the
        # Dockerfile) but unused by the plain kiro-cli path.
        (mkWrapper {
          name = "kiro-fi";
          image = cfg.kiro.image;
          configMounts = ''
            -v kiro-config:/home/${cfg.containerUser}/.local/share/ \
            -v "$HOME/.kiro/sessions:/home/${cfg.containerUser}/.kiro/sessions" \
            -v ${rulesDir}:/home/${cfg.containerUser}/.kiro/steering:ro \
            -v ${skillsDir}:/home/${cfg.containerUser}/.kiro/skills:ro \
            -v ${kiroAgent}:/home/${cfg.containerUser}/.kiro/agents/default.json:ro \
          '';
          dockerArgs =
            kubeMounts cfg.containerUser "rw"
            + socketMount
            + ''
              -e GH_TOKEN="$GH_VALKEY_OPERATOR_READONLY_TOKEN" \
            '';
          command = "chat --agent default";
          resumeExtra = "--resume";
          # Docker creates a missing bind-mount source as root, which the
          # uid-1000 container user then cannot write to.
          setup = ''mkdir -p "$HOME/.kiro/sessions"'';
        })
      ]
      ++ lib.optionals cfg.claude.enable [
        # Everyday Claude: project directory plus cluster access, so a PR can be
        # deployed to the host's kind cluster and inspected over the API.
        (mkWrapper {
          name = "claude";
          image = cfg.claude.image;
          configMounts = ''
            -v claude-config:/home/${cfg.claude.containerUser}/.claude \
            -v ${claudeContext}:/home/${cfg.claude.containerUser}/.claude/CLAUDE.md:ro \
            -v ${skillsDir}:/home/${cfg.claude.containerUser}/.claude/skills:ro \
          '';
          dockerArgs = kubeMounts cfg.claude.containerUser "ro";
        })

        # Fault injection needs the host Docker socket, because crictl and
        # nsenter have to run inside the kind node container. The socket is
        # equivalent to root on the host: anything holding it can start a
        # privileged container that mounts /. Hence a separate command, so the
        # grant is visible at the call site rather than applying to all agent
        # work.
        (mkWrapper {
          name = "claude-fi";
          image = cfg.claude.image;
          configMounts = ''
            -v claude-config:/home/${cfg.claude.containerUser}/.claude \
            -v ${claudeContext}:/home/${cfg.claude.containerUser}/.claude/CLAUDE.md:ro \
            -v ${skillsDir}:/home/${cfg.claude.containerUser}/.claude/skills:ro \
          '';
          dockerArgs = kubeMounts cfg.claude.containerUser "rw" + socketMount;
        })
      ];

    # The same rules the containers get, for agents running directly on the
    # host. Writable paths are left alone: Kiro rewrites settings/cli.json
    # itself, and a store symlink there would make it fail.
    home.file =
      lib.optionalAttrs cfg.kiro.enable {
        ".kiro/steering".source = rulesDir;
        ".kiro/skills".source = skillsDir;
        ".kiro/agents/default.json".source = kiroAgent;
      }
      // lib.optionalAttrs cfg.claude.enable {
        ".claude/CLAUDE.md".source = claudeContext;
        ".claude/skills".source = skillsDir;
      };
  };
}
