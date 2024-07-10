#!/bin/bash

show_info() {
  echo "===================================================="
  echo " Skyport Panel and Daemon Installer Script"
  echo " Developed by: Ismam Ilahi (gaming_ismam#2616)"
  echo " Contact: https://discord.gg/BW6qNVKyZ2"
  echo "===================================================="
  echo " This script is provided as-is without any warranties."
  echo " Use it at your own risk."
  echo "===================================================="
}

check_error() {
  if [ $? -ne 0 ]; then
    echo "Error: $1. Exiting..."
    exit 1
  fi
}

install_nodejs() {
  if ! command -v node &> /dev/null; then
    read -p "Node.js is not installed. Would you like to install it now? (y/n): " install_node
    if [ "$install_node" == "y" ]; then
      if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        if [[ -f /etc/os-release ]]; then
          source /etc/os-release
          case "$ID" in
            ubuntu)
              if [[ "$VERSION_ID" == "24.04" || "$VERSION_ID" == "22.04" ]]; then
                echo "Ubuntu $VERSION_ID is supported."
              else
                echo "Error: Ubuntu $VERSION_ID is not supported."
                exit 1
              fi
              ;;
            debian)
              if [[ "$VERSION_ID" == "11" || "$VERSION_ID" == "12" ]]; then
                echo "Debian $VERSION_ID is supported."
              else
                echo "Error: Debian $VERSION_ID is not supported."
                exit 1
              fi
              ;;
            centos)
              if [[ "$VERSION_ID" == "7" || "$VERSION_ID" == "8" ]]; then
                echo "CentOS $VERSION_ID is supported."
              else
                echo "Error: CentOS $VERSION_ID is not supported."
                exit 1
              fi
              ;;
            *)
              echo "Error: Unsupported Linux distribution. Exiting..."
              exit 1
              ;;
          esac
        else
          echo "Error: Unsupported Linux distribution. Exiting..."
          exit 1
        fi
      elif [[ "$OSTYPE" == "darwin"* ]]; then
        if [[ $(sw_vers -productVersion | cut -d '.' -f 2) -ge 15 ]]; then
          echo "macOS $(sw_vers -productVersion) is supported."
        else
          echo "Error: Unsupported macOS version. Exiting..."
          exit 1
        fi
      elif [[ "$OSTYPE" == "msys" || "$OSTYPE" == "cygwin" ]]; then
        echo "Windows is supported."
      else
        echo "Error: Unsupported operating system. Exiting..."
        exit 1
      fi

      install_nodejs_actual
    else
      echo "Error: Node.js is required for this script to run. Exiting..."
      exit 1
    fi
  else
    echo "Node.js version $(node -v) is already installed."
  fi
}

install_nodejs_actual() {
  if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    case "$ID" in
      ubuntu|debian)
        curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
        sudo apt-get install -y nodejs
        ;;
      centos)
        curl -fsSL https://rpm.nodesource.com/setup_20.x | sudo -E bash -
        sudo yum install -y nodejs
        ;;
      *)
        echo "Error: Unsupported Linux distribution. Exiting..."
        exit 1
        ;;
    esac
  elif [[ "$OSTYPE" == "darwin"* ]]; then
    brew install node@20
  elif [[ "$OSTYPE" == "msys" || "$OSTYPE" == "cygwin" ]]; then
    choco install nodejs-lts -y --version 20
  fi
  check_error "Node.js installation"
  echo "Node.js version $(node -v) installed."
}


install_panel() {
  echo "Installing Skyport Panel..."
  sudo apt install git
  sudo git clone https://github.com/skyportlabs/panel /var/www/skyport/panel
  check_error "Cloning Skyport Panel repository"

  cd /var/www/skyport/panel
  npm install
  check_error "Installing npm dependencies for Skyport Panel"
  npm run seed
  check_error "Running seed for Skyport Panel"

  read -p "Enter the Panel port (default 3001): " panel_port
  panel_port=${panel_port:-3001}
  read -p "Enter the Panel domain (default localhost): " panel_domain
  panel_domain=${panel_domain:-localhost}

  sudo bash -c "cat > /var/www/skyport/panel/config.json" <<EOL
{
  "port": $panel_port,
  "domain": "$panel_domain",
  "version": "Latest"
}
EOL
  check_error "Writing config.json for Skyport Panel"

npm run createUser

  echo "Starting the Panel with pm2..."
  pm2 start index.js --name skyport-panel
  pm2 save
  pm2 startup
  check_error "Starting Skyport Panel with pm2"

  check_and_open_firewall_ports $panel_port
  echo "Skyport Panel installation complete."
  read -p "Press Enter to continue..."
}

install_daemon() {
  echo "Installing Skyport Daemon..."
  sudo apt install git
  sudo git clone https://github.com/skyportlabs/skyportd /var/www/skyport/daemon
  check_error "Cloning Skyport Daemon repository"

  curl -sSL https://get.docker.com/ | CHANNEL=stable bash
  sudo mkdir -p /etc/apt/keyrings
  cd /var/www/skyport/daemon
  npm install
  check_error "Installing npm dependencies for Skyport Daemon"

  read -p "Enter the Panel's remote URL (default http://localhost:3001): " daemon_remote
  daemon_remote=${daemon_remote:-http://localhost:3001}
  read -p "Enter the Panel's access key: " daemon_access_key
  read -p "Enter the Daemon port (default 3000): " daemon_port
  daemon_port=${daemon_port:-3000}
  read -p "Enter the FTP IP (default localhost): " ftp_ip
  ftp_ip=${ftp_ip:-localhost}
  read -p "Enter the FTP port (default 3002): " ftp_port
  ftp_port=${ftp_port:-3002}

  sudo bash -c "cat > /var/www/skyport/daemon/config.json" <<EOL
{
  "remote": "$daemon_remote",
  "key": "$daemon_access_key",
  "port": $daemon_port,
  "ftp": {
    "ip": "$ftp_ip",
    "port": $ftp_port
  },
  "version": "Latest"
}
EOL
  check_error "Writing config.json for Skyport Daemon"

  echo "Starting the Daemon with pm2..."
  pm2 start index.js --name skyport-daemon
  pm2 save
  pm2 startup
  check_error "Starting Skyport Daemon with pm2"

  check_and_open_firewall_ports $daemon_port $ftp_port
  echo "Skyport Daemon installation complete."
  read -p "Press Enter to continue..."
}

check_and_open_firewall_ports() {
  if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    if command -v ufw &> /dev/null; then
      for port in "$@"; do
        echo "Opening port $port in firewall..."
        sudo ufw allow $port
      done
    fi
  else
    echo "Firewall configuration not supported on this OS."
  fi
}

uninstall_panel() {
  echo "Uninstalling Skyport Panel..."
  pm2 stop skyport-panel
  pm2 delete skyport-panel
  sudo rm -rf /var/www/skyport/panel
  echo "Skyport Panel uninstalled."
  read -p "Press Enter to continue..."
}

uninstall_daemon() {
  echo "Uninstalling Skyport Daemon..."
  pm2 stop skyport-daemon
  pm2 delete skyport-daemon
  sudo rm -rf /var/www/skyport/daemon
  echo "Skyport Daemon uninstalled."
  read -p "Press Enter to continue..."
}

update_panel() {
  echo "Updating Skyport Panel..."
  cd /var/www/skyport/panel
  sudo git pull origin master
  check_error "Pulling latest changes for Skyport Panel"
  npm install
  npm run seed
  npm run createUser
  check_error "Installing npm dependencies for Skyport Panel"
  pm2 restart skyport-panel
  check_error "Restarting Skyport Panel with pm2"
  echo "Skyport Panel updated."
  read -p "Press Enter to continue..."
}

update_daemon() {
  echo "Updating Skyport Daemon..."
  cd /var/www/skyport/daemon
  sudo git pull origin master
  check_error "Pulling latest changes for Skyport Daemon"
  npm install
  check_error "Installing npm dependencies for Skyport Daemon"
  pm2 restart skyport-daemon
  check_error "Restarting Skyport Daemon with pm2"
  echo "Skyport Daemon updated."
  read -p "Press Enter to continue..."
}

while true; do
  clear
  show_info
  echo "Choose an option:"
  echo "1: Install Skyport Panel"
  echo "2: Install Skyport Daemon (Wings)"
  echo "3: Install both Skyport Panel and Daemon"
  echo "4: Uninstall Skyport Panel"
  echo "5: Uninstall Skyport Daemon"
  echo "6: Update Skyport Panel (Take Database Backup, All Data Reset After Update)"
  echo "7: Update Skyport Daemon"
  echo "8: Exit"
  read -p "Enter your choice [1-8]: " choice

  case $choice in
    1)
      install_nodejs
      install_panel
      ;;
    2)
      install_nodejs
      install_daemon
      ;;
    3)
      install_nodejs
      install_panel
      install_daemon
      ;;
    4)
      uninstall_panel
      ;;
    5)
      uninstall_daemon
      ;;
    6)
      update_panel
      ;;
    7)
      update_daemon
      ;;
    8)
      echo "Exiting..."
      exit 0
      ;;
    *)
      echo "Invalid choice"
      ;;
  esac

  read -p "Press Enter to return to the menu..."
done
