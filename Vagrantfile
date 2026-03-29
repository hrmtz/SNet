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
    # c.vm.box = "hrmtz/snet-claude"
    c.vm.box = "snet-claude"
    c.vm.box_url = "https://github.com/hrmtz/SNet/releases/download/v1.1.0/snet-claude.box"
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
    echo "  How do you want to authenticate?"
    echo ""
    echo "    1) API Key (paste your sk-ant-... key)"
    echo "    2) Subscription (Claude Pro/Max - browser login)"
    echo ""

    while true; do
        read -p "  Select [1-2]: " _auth
        case "$_auth" in
            1)
                echo ""
                echo "  Get a key at: https://console.anthropic.com/"
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
                echo ""
                echo "  API key saved."
                break
                ;;
            2)
                echo ""
                echo "  Subscription mode. Claude will open a browser for login on first run."
                break
                ;;
            *)
                echo "  Invalid choice. Try again."
                ;;
        esac
    done

    touch "$HOME/.anthropic_key_set"
    echo ""
fi

# Scenario selection on every interactive login
if [ -t 0 ] && [ -t 1 ]; then
    _dirs=()
    for d in "$HOME"/SNet*; do
        [ -d "$d" ] && _dirs+=("$(basename "$d")")
    done

    if [ ${#_dirs[@]} -eq 0 ]; then
        echo "  No SNet scenarios found. Run 'claude' manually."
    elif [ ${#_dirs[@]} -eq 1 ]; then
        cd "$HOME/${_dirs[0]}" && claude
    else
        echo "  Available scenarios:"
        for i in "${!_dirs[@]}"; do
            echo "    $((i+1))) ${_dirs[$i]}"
        done
        echo ""
        while true; do
            read -p "  Select scenario [1-${#_dirs[@]}]: " _choice
            if [[ "$_choice" =~ ^[0-9]+$ ]] && [ "$_choice" -ge 1 ] && [ "$_choice" -le ${#_dirs[@]} ]; then
                cd "$HOME/${_dirs[$((_choice-1))]}" && claude
                break
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
  # Target box is split into 2 parts on GitHub Releases due to 2GB limit.
  # This trigger downloads and reassembles automatically before first use.
  config.vm.define "target" do |t|
    # t.vm.box = "hrmtz/snet1-target"
    t.vm.box = "snet1-target"
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

    t.trigger.before :up do |trigger|
      trigger.name = "Download target box"
      trigger.ruby do |env, machine|
        box_exists = system("vagrant box list | grep -q 'snet1-target'")
        unless box_exists
          puts "Downloading and assembling snet1-target box..."
          base_url = "https://github.com/hrmtz/SNet/releases/download/v1.1.0"
          system("curl -L -o /tmp/snet1-target.part-aa '#{base_url}/snet1-target.box.part-aa'")
          system("curl -L -o /tmp/snet1-target.part-ab '#{base_url}/snet1-target.box.part-ab'")
          system("cat /tmp/snet1-target.part-aa /tmp/snet1-target.part-ab > /tmp/snet1-target.box")
          system("vagrant box add snet1-target /tmp/snet1-target.box")
          system("rm -f /tmp/snet1-target.part-aa /tmp/snet1-target.part-ab /tmp/snet1-target.box")
        end
      end
    end
  end

end
