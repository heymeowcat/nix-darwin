{
  description = "Heymeowcat Darwin Nix Configuration";
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nix-darwin.url = "github:LnL7/nix-darwin";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
  };
  outputs = inputs@{ self, nix-darwin, nixpkgs, home-manager }:
  let
    configuration = { pkgs, config, ... }: {
      nixpkgs.config.allowUnfree = true;

      
      # System packages
      environment.systemPackages = with pkgs; [
        mkalias
        neovim
        tmux
        oh-my-posh
        ripgrep
        fd
        nodejs
        nodePackages.typescript
        nodePackages.typescript-language-server
      ];

      # Fonts
      fonts.packages = [
        (pkgs.nerdfonts.override { fonts = [ "JetBrainsMono" ]; })
      ];

      # Activation script for applications
      system.activationScripts.applications.text = let
        env = pkgs.buildEnv {
          name = "system-applications";
          paths = config.environment.systemPackages;
          pathsToLink = "/Applications";
        };
      in
        pkgs.lib.mkForce ''
          echo "setting up /Applications..." >&2
          rm -rf /Applications/Nix\ Apps
          mkdir -p /Applications/Nix\ Apps
          find ${env}/Applications -maxdepth 1 -type l -exec readlink '{}' + |
          while read src; do
            app_name=$(basename "$src")
            echo "copying $src" >&2
            ${pkgs.mkalias}/bin/mkalias "$src" "/Applications/Nix Apps/$app_name"
          done
        '';

      # Nix configuration
      services.nix-daemon.enable = true;
      nix.settings.experimental-features = "nix-command flakes";

      # Shell configuration
      programs.zsh.enable = true;

      # System configuration
      system.configurationRevision = self.rev or self.dirtyRev or null;
      system.stateVersion = 4;
      nixpkgs.hostPlatform = "aarch64-darwin";

      # Home Manager configuration
        users.users.vidurafernando = {
          name = "vidurafernando";
          home = "/Users/vidurafernando";
        };

        home-manager.users.vidurafernando = { pkgs, ... }: {
        home.stateVersion = "24.05";

        # Alacritty configuration
        programs.alacritty = {
          enable = true;
          settings = {
            window = {
              padding = {
                x = 10;
                y = 10;
              };
            };
            font = {
              normal = {
                family = "JetBrainsMono Nerd Font";
                style = "Regular";
              };
              size = 16.0;
            };
            colors = {
              primary = {
                background = "#282c34";
                foreground = "#abb2bf";
              };
            };
          };
        };

        # tmux configuration
        programs.tmux = {
          enable = true;
          extraConfig = ''
            set -g default-terminal "screen-256color"
            set -g status-style bg=default
            set -g status-left "#[fg=blue]#S "
            set -g status-right "#[fg=yellow]%H:%M "
            set -g window-status-current-style fg=green
            set -g mouse on
          '';
        };

        # Oh My Posh configuration
        programs.oh-my-posh = {
          enable = true;
          enableZshIntegration = true;
          useTheme = "1_shell";
        };

        # Neovim configuration
        programs.neovim = {
          enable = true;
          viAlias = true;     
          vimAlias = true;
          extraConfig = ''
            set number
            set relativenumber
            set tabstop=4
            set shiftwidth=4
            set expandtab
            set smartindent
            set termguicolors
            colorscheme gruvbox
          '';
          plugins = with pkgs.vimPlugins; [
            vim-nix
            gruvbox
            nvim-lspconfig
            nvim-treesitter.withAllGrammars
            telescope-nvim
            lualine-nvim
            vim-fugitive
          ];
          extraPackages = with pkgs; [
            lua-language-server
            nil  # Nix language server
          ];
          extraLuaConfig = ''
            -- LSP Configuration
            local lspconfig = require('lspconfig')
            lspconfig.tsserver.setup{}
            lspconfig.nil_ls.setup{}  -- Setup for Nix language server

            -- Treesitter configuration
            require'nvim-treesitter.configs'.setup {
              highlight = {
                enable = true,
              },
            }

            -- Telescope configuration
            local telescope = require('telescope')
            telescope.setup{}

            -- Keybindings
            vim.api.nvim_set_keymap('n', '<leader>ff', '<cmd>Telescope find_files<cr>', {noremap = true})
            vim.api.nvim_set_keymap('n', '<leader>fg', '<cmd>Telescope live_grep<cr>', {noremap = true})

            -- Lualine configuration
            require('lualine').setup {
              options = {
                theme = 'gruvbox'
              }
            }
          '';
        };

        # Zsh configuration
        programs.zsh = {
          enable = true;
          initExtra = ''
            source $(brew --prefix)/opt/chruby/share/chruby/chruby.sh
            source $(brew --prefix)/opt/chruby/share/chruby/auto.sh
            chruby ruby-3.1.3
            export PATH="/usr/local/opt/openjdk/bin:$PATH"
            export ANDROID_HOME=$HOME/Library/Android/sdk
            export PATH=$PATH:$ANDROID_HOME/emulator
            export PATH=$PATH:$ANDROID_HOME/platform-tools
            export PYENV_ROOT="$HOME/.pyenv"
            [[ -d $PYENV_ROOT/bin ]] && export PATH="$PYENV_ROOT/bin:$PATH"
            eval "$(pyenv init -)"
            eval "$(oh-my-posh init zsh)"
            export PATH="$HOME/.cargo/bin:$PATH"
            export PATH="$HOME/.deno/bin:$PATH"
            export BUN_INSTALL="$HOME/.bun" 
            export PATH="$BUN_INSTALL/bin:$PATH" 
          '';
        };
      };
    };
  in
  {
    darwinConfigurations."Viduras-MacBook-Pro" = nix-darwin.lib.darwinSystem {
      modules = [
        configuration
        home-manager.darwinModules.home-manager
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
        }
      ];
    };
    darwinPackages = self.darwinConfigurations."Viduras-MacBook-Pro".pkgs;
  };
}