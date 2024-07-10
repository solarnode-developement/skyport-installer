#!/bin/bash

# Function to display copyright information
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

# Function to check for errors
check_error() {
  if [ $? -ne 0 ]; then
    echo "An error occurred during the previous step. Exiting..."
    exit 1
  fi
}

# Function to install Node.js version 20 LTS
install_nodejs() {
  if ! command -v node &> /dev/null; then
    read -p "Node.js is not installed. Would you like to install it now? (y/n): " install_node
    if [ "$install_node" == "y" ]; then
      if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        # Linux installation commands (for Ubuntu, Debian, CentOS)
        if [[ -f /etc/os-release ]]; then
          source /etc/os-release
          case "$ID" in
            ubuntu)
              if [[ "$VERSION_ID" == "24.04" || "$VERSION_ID" == "22.04" ]]; then
                echo "Ubuntu $VERSION_ID is supported."
              else
                echo "Ubuntu $VERSION_ID is not supported."
                exit 1
              fi
              ;;
            debian)
              if [[ "$VERSION_ID" == "11" || "$VERSION_ID" == "12" ]]; then
                echo "Debian $VERSION_ID is supported."
              else
                echo "Debian $VERSION_ID is not supported."
                exit 1
              fi
              ;;
            centos)
              if [[ "$VERSION_ID" == "7" || "$VERSION_ID" == "8" ]]; then
                echo "CentOS $VERSION_ID is supported."
              else
                echo "CentOS $VERSION_ID is not supported."
                exit 1
              fi
              ;;
            *)
              echo "Unsupported Linux distribution. Exiting..."
              exit 1
              ;;
          esac
        else
          echo "Unsupported Linux distribution. Exiting..."
          exit 1
        fi
      elif [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS installation commands
        if [[ $(sw_vers -productVersion | cut -d '.' -f 2) -ge 15 ]]; then
          echo "macOS $(sw_vers -productVersion) is supported."
        else
          echo "Unsupported macOS version. Exiting..."
          exit 1
        fi
      elif [[ "$OSTYPE" == "msys" || "$OSTYPE" == "cygwin" ]]; then
        # Windows installation commands (using Chocolatey)
        echo "Windows is supported."
      else
        echo "Unsupported operating system. Exiting..."
        exit 1
      fi

      # Install Node.js
      install_nodejs_actual
    else
      echo "Node.js is required for this script to run. Exiting..."
      exit 1
    fi
  else
    echo "Node.js version $(node -v) is already installed."
  fi
}

# Function to install Node.js based on OS
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
        echo "Unsupported Linux distribution. Exiting..."
        exit 1
        ;;
    esac
  elif [[ "$OSTYPE" == "darwin"* ]]; then
    brew install node@20
  elif [[ "$OSTYPE" == "msys" || "$OSTYPE" == "cygwin" ]]; then
    choco install nodejs-lts -y --version 20
  fi
  check_error
  echo "Node.js version $(node -v) installed."
}

# Function to install Skyport Panel
install_panel() {
  echo "Installing Skyport Panel..."
  # Clone repository
  sudo git clone https://github.com/skyportlabs/panel /var/www/skyport/panel
  check_error

  # Install dependencies
  cd /var/www/skyport/panel
  npm install
  check_error
  npm run seed
  check_error

  # Configure panel
  read -p "Enter the Panel port (default 3001): " panel_port
  panel_port=${panel_port:-3001}
  read -p "Enter the Panel domain (default localhost): " panel_domain
  panel_domain=${panel_domain:-localhost}

  # Get version from package.json
  panel_version=$(npm run -s get-version)
  check_error

  sudo bash -c "cat > /var/www/skyport/panel/config.json" <<EOL
{
  "port": $panel_port,
  "domain": "$panel_domain",
  "version": "$panel_version"
}
EOL
  check_error

  # Prompt for username and password
  read -p "Enter a username for the Skyport Panel: " username
  read -s -p "Enter a password for the Skyport Panel: " password
  echo

  # Create user with expect
  expect << EOF
  spawn sudo npm run createUser
  expect "Enter username:"
  send "$username\r"
  expect "Enter password:"
  send "$password\r"
  expect eof
EOF
  check_error

  # Start the Panel using pm2
  echo "Starting the Panel with pm2..."
  sudo pm2 start index.js --name skyport-panel
  sudo pm2 save
  sudo pm2 startup
  check_error

  echo "Skyport Panel installation complete."
  read -p "Press Enter to continue..."
}

# Function to install Skyport Daemon (Wings)
install_daemon() {
  echo "Installing Skyport Daemon..."
  # Clone repository
  sudo git clone https://github.com/skyportlabs/skyportd /var/www/skyport/daemon
  check_error

  # Install dependencies
  curl -sSL https://get.docker.com/ | CHANNEL=stable bash
  sudo mkdir -p /etc/apt/keyrings
  cd /var/www/skyport/daemon
  npm install
  check_error

  # Configure daemon
  read -p "Enter the Panel's remote URL (default http://localhost:3001): " daemon_remote
  daemon_remote=${daemon_remote:-http://localhost:3001}
  read -p "Enter the Panel's access key: " daemon_access_key
  read -p "Enter the Daemon port (default 3000): " daemon_port
  daemon_port=${daemon_port:-3000}
  read -p "Enter the FTP IP (default localhost): " ftp_ip
  ftp_ip=${ftp_ip:-localhost}
  read -p "Enter the FTP port (default 3002): " ftp_port
  ftp_port=${ftp_port:-3002}

  # Get version from package.json
  daemon_version=$(npm run -s get-version)
  check_error

  sudo bash -c "cat > /var/www/skyport/daemon/config.json" <<EOL
{
  "remote": "$daemon_remote",
  "key": "$daemon_access_key",
  "port": $daemon_port,
  "ftp": {
    "ip": "$ftp_ip",
    "port": $ftp_port
  },
  "version": "$daemon_version"
}
EOL
  check_error

  # Start the Daemon using pm2
  echo "Starting the Daemon with pm2..."
  sudo pm2 start index.js --name skyport-daemon
  sudo pm2 save
  check_error

  echo "Skyport Daemon installation complete."
  read -p "Press Enter to continue..."
}

# Function to uninstall Skyport Panel
uninstall_panel() {
  echo "Uninstalling Skyport Panel..."
  sudo pm2 stop skyport-panel
  sudo pm2 delete skyport-panel
  sudo rm -rf /var/www/skyport/panel
  echo "Skyport Panel uninstalled."
  read -p "Press Enter to continue..."
}

# Function to uninstall Skyport Daemon (Wings)
uninstall_daemon() {
  echo "Uninstalling Skyport Daemon..."
  sudo pm2 stop skyport-daemon
  sudo pm2 delete skyport-daemon
  sudo rm -rf /var/www/skyport/daemon
  echo "Skyport Daemon uninstalled."
  read -p "Press Enter to continue..."
}

# Function to update Skyport Panel
update_panel() {
  echo "Updating Skyport Panel..."
  cd /var/www/skyport/panel
  sudo git pull origin master
  check_error
  sudo npm install
  check_error
  sudo pm2 restart skyport-panel
  echo "Skyport Panel updated."
  read -p "Press Enter to continue..."
}

# Function to update Skyport Daemon (Wings)
update_daemon() {
  echo "Updating Skyport Daemon..."
  cd /var/www/skyport/daemon
  sudo git pull origin master
  check_error
  sudo npm install
  check_error
  sudo pm2 restart skyport-daemon
  echo "Skyport Daemon updated."
  read -p "Press Enter to continue..."
}

# Display menu
while true; do
  clear
  show_info
  echo "Choose an option:"
  echo "1: Install Skyport Panel"
  echo "2: Install Skyport Daemon (Wings)"
  echo "3: Install both Skyport Panel and Daemon"
  echo "4: Uninstall Skyport Panel"
  echo "5: Uninstall Skyport Daemon"
  echo "6: Update Skyport Panel"
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
