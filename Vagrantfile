# SNet - AI-Guided CTF
#
# Usage:
#   vagrant up                       # SNet1 scenario (default)
#   SNET=2 vagrant up                # SNet2 scenario
#   SNET=3 vagrant up                # SNet3 scenario
#   SNET=all vagrant up              # All scenarios
#   SNET=1,2 vagrant up              # Multiple scenarios
#   SNET=2 vagrant provision claude  # Add SNet2 to existing claude VM
#
# VMs created:
#   Always:  claude (AI trainer), kali (attacker)
#   SNET=1:  snet1-target
#   SNET=2:  snet2-target, snet2-zabbix
#   SNET=3:  (TBD)
#
# Prerequisites:
#   - VirtualBox 7.0+
#   - Vagrant (https://developer.hashicorp.com/vagrant/install)
#   - Anthropic API key for the AI trainer
#
# WSL2 users: install Vagrant inside WSL (Linux binary), not Windows.
#   export VAGRANT_WSL_ENABLE_WINDOWS_ACCESS="1"
#   export PATH="$PATH:/mnt/c/Program Files/Oracle/VirtualBox"

SNET_RAW = ENV.fetch('SNET', '1')
# Parse SNET: "1", "2", "3", "1,2", "all"
SNET_ACTIVE = if SNET_RAW == 'all'
  ['1', '2', '3']
else
  SNET_RAW.split(',').map(&:strip)
end

# GitHub Releases base URLs (one per scenario)
SNET1_RELEASE = "https://github.com/hrmtz/SNet/releases/download/v1.1.0"
SNET2_RELEASE = "https://github.com/hrmtz/SNet2/releases/download/v1.0.0"
# SNET3_RELEASE = "https://github.com/hrmtz/SNet3/releases/download/v1.0.0"

# Helper: auto-download and assemble split box from GitHub Releases
def split_box_trigger(vm, box_name, base_url, parts: ['aa', 'ab'], file_prefix: nil)
  file_prefix ||= box_name
  vm.trigger.before :up do |trigger|
    trigger.name = "Download #{box_name} box"
    trigger.ruby do |env, machine|
      unless system("vagrant box list | grep -qF '#{box_name}'")
        puts "Downloading and assembling #{box_name} box..."
        parts.each { |p| system("curl -L -o /tmp/#{file_prefix}.part-#{p} '#{base_url}/#{file_prefix}.box.part-#{p}'") }
        system("cat #{parts.map { |p| "/tmp/#{file_prefix}.part-#{p}" }.join(' ')} > /tmp/#{file_prefix}.box")
        system("vagrant box add '#{box_name}' /tmp/#{file_prefix}.box")
        system("rm -f #{parts.map { |p| "/tmp/#{file_prefix}.part-#{p}" }.join(' ')} /tmp/#{file_prefix}.box")
      end
    end
  end
end

Vagrant.configure("2") do |config|

  # Disable default synced folder (not needed, avoids guest additions dependency)
  config.vm.synced_folder ".", "/vagrant", disabled: true

  # ===================================================================
  # Claude VM (AI Trainer) — shared across scenarios, multi-network
  # To add a new scenario: add a private_network line with 10.0.N.5
  # ===================================================================
  config.vm.define "claude", primary: true do |c|
    c.vm.box = "snet-claude"
    c.vm.box_url = "#{SNET1_RELEASE}/snet-claude.box"
    c.vm.hostname = "cage"
    c.vm.network "private_network", ip: "10.0.1.5", virtualbox__intnet: "SNet-Net"
    c.vm.network "private_network", ip: "10.0.2.5", virtualbox__intnet: "SNet2-Net"
    c.vm.network "private_network", ip: "10.0.3.5", virtualbox__intnet: "SNet3-Net"
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

    # Fetch/update scenario repos + trainer overlay (SNET-aware)
    c.vm.provision "shell", privileged: false, env: { "SNET" => SNET_RAW }, inline: <<-'SHELL'
      # Build scenario list from SNET (e.g. "1", "2", "1,2", "all")
      SCENARIOS=""
      if [ "$SNET" = "all" ]; then
        SCENARIOS="SNet SNet2 SNet3"
      else
        for n in $(echo "$SNET" | tr ',' ' '); do
          case "$n" in
            1) SCENARIOS="$SCENARIOS SNet" ;;
            2) SCENARIOS="$SCENARIOS SNet2" ;;
            3) SCENARIOS="$SCENARIOS SNet3" ;;
          esac
        done
      fi
      SCENARIOS=$(echo "$SCENARIOS" | xargs)  # trim

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

      # Overlay trainer config
      TRAINER_REPO="https://github.com/hrmtz/SNet-Claude.git"
      if [ -d "$HOME/.snet-claude" ]; then
        git -C "$HOME/.snet-claude" checkout -- . 2>/dev/null || true
        git -C "$HOME/.snet-claude" pull --ff-only 2>/dev/null || true
      else
        git clone "$TRAINER_REPO" "$HOME/.snet-claude" 2>/dev/null || true
      fi

      # Copy scenario-specific files (CLAUDE.md, enc files)
      for s in $SCENARIOS; do
        if [ -d "$HOME/$s" ]; then
          cp -r "$HOME/.snet-claude/.claude" "$HOME/$s/" 2>/dev/null || true
          if [ -d "$HOME/.snet-claude/$s" ]; then
            cp "$HOME/.snet-claude/$s/CLAUDE.md" "$HOME/$s/" 2>/dev/null || true
            cp "$HOME/.snet-claude/$s/"*.enc "$HOME/$s/" 2>/dev/null || true
          fi
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
                read -p "  API Key: " _key
                if [ -n "$_key" ]; then
                    if [[ "$_key" != sk-ant-* ]]; then
                        echo "  Warning: Key doesn't start with 'sk-ant-'. Proceeding anyway."
                    fi
                    echo "export ANTHROPIC_API_KEY='$_key'" >> "$HOME/.bashrc"
                    export ANTHROPIC_API_KEY="$_key"
                    unset _key
                    echo ""
                    echo "  API key saved."
                fi
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

  # ===================================================================
  # Kali VM (attacker) — shared across scenarios, multi-network
  # To add a new scenario: add a private_network line with 10.0.N.10
  # Use 'snet-switch N' on Kali to activate the right NIC
  # ===================================================================
  config.vm.define "kali" do |k|
    k.vm.box = "kalilinux/rolling"
    k.vm.hostname = "kali"
    k.vm.network "private_network", ip: "10.0.1.10", virtualbox__intnet: "SNet-Net"
    k.vm.network "private_network", ip: "10.0.2.10", virtualbox__intnet: "SNet2-Net"
    k.vm.network "private_network", ip: "10.0.3.10", virtualbox__intnet: "SNet3-Net"
    k.vm.network "forwarded_port", guest: 22, host: 3022, id: "kali-ssh"
    k.vm.provider "virtualbox" do |vb|
      vb.memory = 4096
      vb.cpus = 4
      vb.name = "SNet-Kali"
      vb.gui = false
    end

    # UX patches: rlwrap, tmux, Guest Additions, HiDPI, snet-switch
    k.vm.provision "shell", privileged: true, path: "provision_kali.sh"
  end

  # ===================================================================
  # SNet1 Target (conditional)
  # ===================================================================
  if SNET_ACTIVE.include?('1')
    config.vm.define "snet1-target" do |t|
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

      split_box_trigger(t, "hrmtz/snet1-target", SNET1_RELEASE, file_prefix: "snet1-target")
    end
  end

  # ===================================================================
  # SNet2 Target (conditional)
  # ===================================================================
  if SNET_ACTIVE.include?('2')
    config.vm.define "snet2-target" do |t|
      t.vm.box = "hrmtz/snet2-target"
      t.vm.box_url = "#{SNET2_RELEASE}/snet2-target.box"
      t.vm.hostname = "target"
      t.vm.network "private_network", ip: "10.0.2.20", virtualbox__intnet: "SNet2-Net"
      t.ssh.insert_key = false
      t.vm.boot_timeout = 10
      t.vm.provider "virtualbox" do |vb|
        vb.memory = 512
        vb.cpus = 1
        vb.name = "SNet2-Target"
        vb.gui = false
      end
    end
  end

  # ===================================================================
  # SNet2 Zabbix (conditional)
  # ===================================================================
  if SNET_ACTIVE.include?('2')
    config.vm.define "snet2-zabbix" do |z|
      z.vm.box = "hrmtz/snet2-zabbix"
      z.vm.hostname = "zabbix"
      z.vm.network "private_network", ip: "10.0.2.30", virtualbox__intnet: "SNet2-Net"
      z.vm.provider "virtualbox" do |vb|
        vb.memory = 1024
        vb.cpus = 1
        vb.name = "SNet2-Zabbix"
        vb.gui = false
      end

      split_box_trigger(z, "hrmtz/snet2-zabbix", SNET2_RELEASE, file_prefix: "snet2-zabbix")
    end
  end

  # ===================================================================
  # SNet3 (TBD — add VMs here)
  # Pattern: 10.0.3.x on SNet3-Net
  # ===================================================================
  # if SNET_ACTIVE.include?('3')
  #   config.vm.define "snet3-target" do |t|
  #     t.vm.box = "snet3-target"
  #     t.vm.box_url = "#{SNET3_RELEASE}/snet3-target.box"
  #     t.vm.hostname = "target"
  #     t.vm.network "private_network", ip: "10.0.3.20", virtualbox__intnet: "SNet3-Net"
  #     t.ssh.insert_key = false
  #     t.vm.boot_timeout = 10
  #     t.vm.provider "virtualbox" do |vb|
  #       vb.memory = 512
  #       vb.cpus = 1
  #       vb.name = "SNet3-Target"
  #       vb.gui = false
  #     end
  #   end
  # end

end
