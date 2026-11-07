# nix-config

Nix flake managing an Ubuntu laptop (standalone home-manager), a macOS machine
(nix-darwin + home-manager) and a set of headless Linux servers from one set of
modules.

## What Nix owns, and what it does not

| Managed by Nix (home-manager)      | Left to apt                                |
| ---------------------------------- | ------------------------------------------ |
| All config files under `~/.config` | i3, i3lock, picom, rofi, dunst, i3blocks   |
| zsh, git, CLI tooling, fonts       | X server, display manager, GPU drivers     |
| The X helper scripts (`pkgs/`)     | nm-applet, blueman, pasystray, pavucontrol |
| Per-machine values                 | Chrome, Slack, Teams, Docker               |

i3 and friends stay on apt because they link against the distro's X server and
GPU drivers; nixpkgs builds would need `nixGL` wrapping and break on driver
upgrades. Config files have no such coupling, so home-manager generates them.

## Layout

```
flake.nix                      pinned inputs, one output per machine
pkgs/x-tools.nix               the X helper scripts, as packages
home/
  common/                      applied everywhere: cli, fonts, git, zsh
  modules/                     opt-in features, each behind my.<name>.enable
    machine/                   typed options for per-machine hardware values
    i3/ picom/ rofi/ dunst/    Ubuntu session config, each with its own assets
    aerospace/                 the i3 stand-in on macOS
  profiles/                    linux-desktop, darwin-desktop, server
  users/bjorn/                 laptop.nix, mac.nix, server.nix
hosts/mac.nix                  nix-darwin: macOS defaults, Homebrew casks
```

`common/` is unconditional. Each module in `modules/` declares its own `enable`
flag and contributes nothing until a profile switches it on. A file under
`users/` picks a profile and supplies that machine's hardware values. Every
module is imported on both platforms; platform-specific ones stay inert through
`mkIf`, so the i3 and AeroSpace modules never leak onto the wrong machine.

Per-machine values (xrandr outputs, touchpad name, wireless interface) are typed
options in `home/modules/machine`, set in `home/users/bjorn/laptop.nix`. Leaving
one out fails the build with the option name rather than writing an empty string
into a config file.

### Adding a machine

Add a file under `home/users/<name>/`, import a profile, set `my.machine` if the
profile needs it, then add one output to `flake.nix`. A desktop sets hardware
values through `my.machine`; a headless server imports `profiles/server.nix` and
sets nothing.

## Ubuntu laptop

### 1. Install Nix

```
curl -L https://nixos.org/nix/install | sh -s -- --daemon
mkdir -p ~/.config/nix
echo 'experimental-features = nix-command flakes' >> ~/.config/nix/nix.conf
```

Log out and back in, then check: `nix run nixpkgs#hello`

### 2. Install the session stack from apt

```
sudo apt update
sudo apt install -y i3 i3blocks i3lock picom rofi dunst \
     fonts-font-awesome scrot feh xautolock imagemagick \
     blueman pasystray pavucontrol network-manager-gnome \
     arandr x11-xserver-utils xinput
```

`picom` replaces the unpackaged `compton`; the old `compton.conf` is still valid
and is installed as `~/.config/picom.conf`.

### 3. Remove any existing dotfile symlinks

If an earlier stow-style setup symlinked `$HOME` paths into a dotfiles repo,
remove those links before the first activation:

```
find ~ -maxdepth 1 -type l -lname '*dotfiles*'
find ~/.config -maxdepth 2 -type l -lname '*dotfiles*'
rm ~/.zshrc ~/.config/i3 ~/.config/dunst ~/.config/rofi ~/.config/compton.conf
```

A _directory_ symlink such as `~/.config/i3 -> ~/git/dotfiles/i3` makes
home-manager resolve `~/.config/i3/config` to the repo's own file and back it
up, turning the input into a link to its own output. Recovering means
`git checkout` on the affected files and deleting the `.backup` copies.

### 4. Set the machine values

`username` in `flake.nix` names the configuration and is `bjorn` as committed;
the commands below spell that out because `.#<username>` is a shell redirect.

Fill in `my.machine` in `home/users/bjorn/laptop.nix`:

- `mainOutput` / `extraOutput` / `presentationOutput`: from `xrandr`
- `touchpadName`: from `xinput list`
- `wirelessInterface`: from `ip link`

Output names are driver-specific (`eDP-1` on Intel, `eDP-1-1` on Nvidia; externals
`DP-1` upward). Read them on the machine. An unset or misspelled value fails the
build with the option name.

### 5. Build before switching

Flakes only read files git knows about, so stage new files first:

```
git add -N .
nix build .#homeConfigurations.bjorn.activationPackage
```

This evaluates every module and runs shellcheck over the helper scripts without
touching `$HOME`, leaving only a `result` symlink.

### 6. Activate

```
nix run home-manager/release-26.05 -- switch --flake .#bjorn
```

home-manager refuses to overwrite files it does not own, so the first activation
stops on the existing `~/.zshrc`, `~/.config/i3/config`,
`~/.config/dunst/dunstrc` and `~/.config/rofi/config.rasi`. Move them aside, or
rename each to `<file>.backup`:

```
nix run home-manager/release-26.05 -- switch --flake .#bjorn -b backup
```

After that, `home-manager switch --flake .#bjorn` is enough.

### 7. Make zsh the login shell

Nix-installed zsh is not in `/etc/shells`, so `chsh` refuses it. Either install
the apt zsh as the login shell (home-manager still drives its config):

```
sudo apt install zsh
chsh -s /usr/bin/zsh
```

or, if `/etc/passwd` is centrally managed, add to `~/.bashrc`:

```
if [ -t 1 ]; then exec zsh; fi
```

### 8. Select the i3 session

Pick i3 at the login screen (the small gear). On older releases, set
`user-session=i3` in `/etc/lightdm/lightdm.conf`.

### 9. Install Docker

The coding-agent containers and the kind cluster need Docker, which Nix does not
own. Install Docker Engine from its apt repository following
https://docs.docker.com/engine/install/ubuntu/#install-using-the-repository:

```
# Add Docker's official GPG key
sudo apt update
sudo apt install -y ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

# Add the repository to apt sources
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt update

sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin
```

Then add your user to the `docker` group and re-log for it to take effect:

```
sudo usermod -aG docker "$USER"
```

Group membership on the socket is what the coding-agent grants assume.

## macOS

### 1. Install Nix and Homebrew

Nix as above. Homebrew must be installed by hand once; nix-darwin manages the
cask list but not Homebrew itself:

```
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

### 2. Activate

Recent nix-darwin requires root for system activation, and the bootstrap
command must carry the experimental-features flags because root's Nix config
does not have them yet:

```
sudo nix --extra-experimental-features "nix-command flakes" run nix-darwin -- switch --flake .#mac
```

On a fresh macOS install, `/etc/bashrc` and `/etc/zshrc` exist with Apple's
default content. nix-darwin refuses to overwrite files it did not create, so
rename them first:

```
sudo mv /etc/bashrc /etc/bashrc.before-nix-darwin
sudo mv /etc/zshrc /etc/zshrc.before-nix-darwin
```

nix-darwin writes its own versions and sources the originals at the bottom, so
nothing in those files is lost. Then re-run the activation command above.

Then for later changes:

```
sudo darwin-rebuild switch --flake .#mac
```

Set `darwinSystem`
in `flake.nix` to `x86_64-darwin` on an Intel Mac.

There is no i3 on macOS; `home/modules/aerospace` configures AeroSpace, which
tiles similarly and needs no SIP changes. Keybindings mirror the i3 ones where
macOS allows it (Alt substitutes for i3's Mod4, which macOS reserves).

## Servers

`stack1` through `stack3` are identical headless `x86_64-linux` boxes wanting the
CLI tooling (`go`, `kubectl`, `kind`, `helm`, zsh, git) at the same pinned
versions and nothing graphical. One config
(`home/users/bjorn/server.nix`, importing `profiles/server.nix`) serves all three
through the single `stack` flake output.

### 1. Install Nix

As for the laptop; the daemon install needs `sudo` once per server:

```
curl -L https://nixos.org/nix/install | sh -s -- --daemon
mkdir -p ~/.config/nix
echo 'experimental-features = nix-command flakes' >> ~/.config/nix/nix.conf
```

Log out and back in.

### 2. Activate

Referencing the flake straight from GitHub, so no clone is needed:

```
nix run home-manager/release-26.05 -- switch --flake github:dorant/nix-config#stack
```

Add `-b backup` on the first run if an existing `~/.zshrc` is in the way. After
that, `home-manager switch --flake github:dorant/nix-config#stack` is enough.

`kind` needs a container runtime: install Docker Engine and add your user to the
`docker` group as in the laptop's "Install Docker" step, following
https://docs.docker.com/engine/install/ubuntu/#install-using-the-repository.
Without the group membership `kind create cluster` cannot reach the socket.

## Day to day

```
# Update inputs
nix flake update                  # all
nix flake update nixpkgs          # one

# Apply
home-manager switch --flake .#bjorn        # Ubuntu
sudo darwin-rebuild switch --flake .#mac   # macOS

# Roll back
home-manager generations
/nix/store/<hash>-home-manager-generation/activate
```

`flake.lock` pins every input so all machines resolve identical versions until
updated deliberately. Commit it.

## Checking before switching

```
nix flake check   # builds the laptop activation package, runs treefmt
nix run .#lint    # structural checks
nix fmt           # format every file
```

`nix flake check` evaluates every module and runs shellcheck without touching
`$HOME`; the macOS checks only run on the Mac. `nix fmt` runs treefmt (nixfmt,
shfmt, shellcheck, prettier) and backs the `formatting` check, so CI and local
runs agree. `nix run .#lint` enforces what the option system cannot:

- every module under `home/modules` is imported by `home/modules/default.nix`
- every module is enabled by some profile, so none is dead code
- every enable flag a profile sets names a real module
- no xrandr output or interface name is hardcoded outside `home/modules/machine`

CI runs all three on push and weekly. `.pre-commit-config.yaml` wires the same
formatter and lint into a git hook; `pre-commit install` to enable it.

## Coding agents

Kiro and Claude Code run in containers built outside this flake
(`containers/kiro-cli/Dockerfile`); home-manager owns their configuration and the
wrappers that launch them.

The steering rules live once, in `home/modules/agents/rules/`, as tool-agnostic
markdown. The module adapts them per tool: Kiro reads a directory mounted at
`~/.kiro/steering`; Claude reads a single `CLAUDE.md` concatenated from the same
files. Editing a rule needs no image rebuild.

### The GitHub token

The wrappers pass a GitHub token into the container as `GH_TOKEN`, read from
`GH_VALKEY_OPERATOR_READONLY_TOKEN`. That value is kept out of git and the
world-readable Nix store: zsh's `~/.zshenv` sources `~/.config/gh_secrets.env`
if it exists, reaching interactive and non-interactive shells alike.

Create the file by hand on each machine that runs the agents; activation does
not create it, and a missing file just leaves `GH_TOKEN` empty:

```
install -m 600 /dev/null ~/.config/gh_secrets.env
cat > ~/.config/gh_secrets.env <<'EOF'
export GH_VALKEY_OPERATOR_READONLY_TOKEN=ghp_your_token_here
EOF
```

To copy it to another machine, keep the owner-only permissions:

```
ssh <host> 'mkdir -p ~/.config'
scp ~/.config/gh_secrets.env <host>:~/.config/gh_secrets.env
ssh <host> 'chmod 600 ~/.config/gh_secrets.env'
```

### What isolates what

The container user is uid 1000, the same as the host user, so running as
non-root is not a boundary against your own files. The isolation comes from the
mount list: only the current project is mounted, so `~/.ssh`, `~/.aws` and the
rest of `$HOME` are absent.

That makes the Docker socket the thing to guard: anything holding it can start a
privileged container that mounts `/`. Hence four commands with different grants:

| Command     | Grants                                              | For                        |
| ----------- | --------------------------------------------------- | -------------------------- |
| `kiro-cli`  | project, plus read-only kubeconfig                  | everyday work              |
| `kiro-fi`   | the above read-write, plus the Docker socket        | cluster creation, builds   |
| `claude`    | project, plus host network and read-only kubeconfig | code work, testing on kind |
| `claude-fi` | the above read-write, plus the Docker socket        | fault injection            |

The `-fi` wrappers carry the Docker socket because cluster creation, image
builds (`docker build`, `kind load`) and fault injection (`crictl`, `nsenter`)
need it; everyday work does not, so it stays off the plain wrappers.

`--network host` on the Claude wrappers is needed because a kind cluster's
kubeconfig names `127.0.0.1`, which inside a container is the container.
Exposing host network services is a much smaller grant than the socket.

## Not covered by this flake

- rbenv, pnpm, cargo and per-language `PATH` entries. Use `direnv` with a
  per-project `flake.nix` instead; `programs.direnv` is enabled in
  `home/common/cli`.
- Docker Engine. Installed from Docker's apt repository, not Nix; see the
  "Install Docker" step under Ubuntu laptop.
