# SNet - AI-Guided CTF
# Usage: vagrant up
#
# Prerequisites:
#   - VirtualBox 7.0+
#   - Vagrant (https://developer.hashicorp.com/vagrant/install)
#   - Anthropic API key for the AI trainer
#
# WSL2 users: install Vagrant inside WSL (Linux binary), not Windows.
#   export VAGRANT_WSL_ENABLE_WINDOWS_ACCESS="1"
#   export PATH="$PATH:/mnt/c/Program Files/Oracle/VirtualBox"

Vagrant.configure("2") do |config|

  # Disable default synced folder (not needed, avoids guest additions dependency)
  config.vm.synced_folder ".", "/vagrant", disabled: true

  # --- AI Trainer (Claude Code) ---
  config.vm.define "claude", primary: true do |c|
    c.vm.box = "hrmtz/snet-claude"
    c.vm.hostname = "cage"
    c.vm.network "private_network", ip: "10.0.1.5", virtualbox__intnet: "SNet-Net"
    c.vm.network "forwarded_port", guest: 22, host: 2222, id: "claude-ssh"
    c.vm.provider "virtualbox" do |vb|
      vb.memory = 1024
      vb.cpus = 1
      vb.name = "SNet-Claude"
      vb.gui = false
    end
    c.ssh.username = "snet"
    c.ssh.insert_key = true

    # Install Node.js and Claude Code
    c.vm.provision "shell", privileged: true, inline: <<-'SHELL'
      curl -fsSL https://deb.nodesource.com/setup_22.x | bash -
      apt-get install -y nodejs
      npm install -g @anthropic-ai/claude-code
    SHELL

    # Fetch/update SNet scenarios from GitHub
    c.vm.provision "shell", privileged: false, inline: <<-'SHELL'
      SCENARIOS="SNet SNet2"
      for s in $SCENARIOS; do
        if [ -d "$HOME/$s" ]; then
          echo "Updating $s..."
          git -C "$HOME/$s" checkout -- . 2>/dev/null || true
          git -C "$HOME/$s" pull --ff-only 2>/dev/null || true
        else
          echo "Cloning $s..."
          git clone "https://github.com/hrmtz/$s.git" "$HOME/$s" 2>/dev/null || true
        fi
      done
    SHELL

    # Login script: API key prompt + scenario selection
    c.vm.provision "shell", privileged: true, inline: <<-'SHELL'
      cat > /etc/profile.d/snet-apikey.sh << 'EOF'
# SNet AI Trainer Setup (sourced by /etc/profile.d/ on login)

if [ ! -f "$HOME/.anthropic_key_set" ] && [ -t 0 ] && [ -t 1 ]; then
    echo ""
    echo "========================================="
    echo "  SNet AI Trainer Setup"
    echo "========================================="
    echo ""
    echo "  Enter your Anthropic API key."
    echo "  Get one at: https://console.anthropic.com/"
    echo ""

    while true; do
        read -sp "  API Key: " _key
        echo ""

        if [ -z "$_key" ]; then
            echo "  Key cannot be empty. Try again."
            continue
        fi

        if [[ "$_key" != sk-ant-* ]]; then
            echo "  Warning: Key doesn't start with 'sk-ant-'. Proceeding anyway."
        fi

        break
    done

    echo "export ANTHROPIC_API_KEY='$_key'" >> "$HOME/.bashrc"
    export ANTHROPIC_API_KEY="$_key"
    unset _key
    touch "$HOME/.anthropic_key_set"

    echo ""
    echo "  Key saved."
    echo ""
fi

# NjSlyr mod helper: download and write to .claude/CLAUDE.md
_apply_njslyr() {
    local _dir="$1"
    local _njslyr_url="https://gist.githubusercontent.com/hrmtz/0ca8f840c9e4f3db8f475fbdc78a3dc2/raw/njslyr.md"
    local _target="$_dir/.claude/CLAUDE.md"
    local _marker="## 忍殺モード"
    if grep -q "$_marker" "$_target" 2>/dev/null; then
        echo "  ◆NjSlyr Mod already active◆"
    else
        echo "  Downloading NjSlyr mod..."
        if curl -fsSL "$_njslyr_url" -o /tmp/njslyr.md 2>/dev/null; then
            mkdir -p "$_dir/.claude"
            sed -n '/^## 忍殺モード/,$ p' /tmp/njslyr.md >> "$_target"
            echo "  ◆NjSlyr Mod activated◆"
        else
            echo "  Warning: Failed to download NjSlyr mod. Starting without it."
        fi
        rm -f /tmp/njslyr.md
    fi
}

# Scenario selection on every interactive login
if [ -t 0 ] && [ -t 1 ]; then
    _dirs=()
    for d in "$HOME"/SNet*; do
        [ -d "$d" ] && _dirs+=("$(basename "$d")")
    done

    if [ ${#_dirs[@]} -eq 0 ]; then
        echo "  No SNet scenarios found. Run 'claude' manually."
    elif [ ${#_dirs[@]} -eq 1 ]; then
        _scenario_dir="$HOME/${_dirs[0]}"
        echo ""
        echo "  Mode:"
        echo "    1) Normal"
        echo "    2) NjSlyr (Ninja Slayer mod)"
        echo ""
        read -p "  Select mode [1-2]: " _mode
        if [ "$_mode" = "2" ]; then
            _apply_njslyr "$_scenario_dir"
        fi
        cd "$_scenario_dir" && claude
    else
        echo "  Available scenarios:"
        for i in "${!_dirs[@]}"; do
            echo "    $((i+1))) ${_dirs[$i]}"
        done
        echo "    njslyr) Ninja Slayer mod"
        echo ""
        while true; do
            read -p "  Select scenario [1-${#_dirs[@]}/njslyr]: " _choice
            if [ "$_choice" = "njslyr" ]; then
                echo ""
                echo "  Select scenario for NjSlyr mod:"
                for i in "${!_dirs[@]}"; do
                    echo "    $((i+1))) ${_dirs[$i]}"
                done
                echo ""
                while true; do
                    read -p "  Select scenario [1-${#_dirs[@]}]: " _sc
                    if [[ "$_sc" =~ ^[0-9]+$ ]] && [ "$_sc" -ge 1 ] && [ "$_sc" -le ${#_dirs[@]} ]; then
                        _scenario_dir="$HOME/${_dirs[$((_sc-1))]}"
                        _apply_njslyr "$_scenario_dir"
                        cd "$_scenario_dir" && claude
                    else
                        echo "  Invalid choice. Try again."
                    fi
                done
            elif [[ "$_choice" =~ ^[0-9]+$ ]] && [ "$_choice" -ge 1 ] && [ "$_choice" -le ${#_dirs[@]} ]; then
                cd "$HOME/${_dirs[$((_choice-1))]}" && claude
            else
                echo "  Invalid choice. Try again."
            fi
        done
    fi
fi
EOF
    SHELL
  end

  # --- Kali Linux (attacker) ---
  config.vm.define "kali" do |k|
    k.vm.box = "kalilinux/rolling"
    k.vm.hostname = "kali"
    k.vm.network "private_network", ip: "10.0.1.10", virtualbox__intnet: "SNet-Net"
    k.vm.network "forwarded_port", guest: 22, host: 3022, id: "kali-ssh"
    k.vm.provider "virtualbox" do |vb|
      vb.memory = 2048
      vb.cpus = 2
      vb.name = "SNet-Kali"
      vb.gui = false
    end
  end

  # --- Target (server to hack) ---
  config.vm.define "target" do |t|
    t.vm.box = "hrmtz/snet1-target"
    t.vm.hostname = "target"
    t.vm.network "private_network", ip: "10.0.1.20", virtualbox__intnet: "SNet-Net"
    t.ssh.insert_key = false
    t.vm.boot_timeout = 10
    t.vm.provider "virtualbox" do |vb|
      vb.memory = 512
      vb.cpus = 1
      vb.name = "SNet1-Target"
      vb.gui = false
    end
  end

end
