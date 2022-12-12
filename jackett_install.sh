#! /bin/bash
compareVersions() {
        downloaded_version=$1
        latest_version=$2

        downloaded_version_dec=`echo ${downloaded_version} | tr --delete v.
        latest_version_dec=`echo ${latest_version} | tr --delete v.

        if [ ${downloaded_version_dec} -eq ${latest_version_dec} ]; then
                echo "Downloaded"
        elif [ ${downloaded_version_dec} -gt ${latest_version_dec} ]; then
                echo "Downloaded"
        else
                echo "Remote"
        fi
}

downloadJackett() {
        download_url=$1
        remote_version=$( getLatestJacketVersion ${download_url} )
        rm -f /opt/packages/Jackett.Binaries.LinuxARM64.*.tar.gz
        wget -O Jackett.Binaries.LinuxARM64.${remote_version}.tar.gz -P /opt/packages/ ${download_url}
}

getDownloadedVersion() {
        downloaded_file=`ls /opt/packages/Jackett.Binaries.LinuxARM64.*.tar.gz`
        IFS=. read -r application category architecture major minor revision tar gz <<< ${downloaded_file}

        if [ ${downloaded_file} == "" ]; then
                echo "0.0.0"
        else
                echo ${major}.${minor}.${revision}
        fi
}

getDownloadURL() {
        download_url=`curl -s https://api.github.com/repos/Jackett/Jackett/releases | grep Jackett.Binaries.LinuxARM64.tar.gz | grep browser_download_url | head -1 | cut -d \" -f 4`

        echo ${download_url}
}

getLatestJackettVersion() {
        download_url=$1
        IFS=/ read -r protocol seperator domain group repo category link version file <<< ${download_url}

        echo ${version}
}

installJackett() {
        downloaded_version=$1
        # Extract package
        tar xvzf /opt/packages/Jackett.Binaries.LinuxARM64.${downloaded_version}.tar.gz -C /tmp/

        # Remove existing installation
        rm -rf /opt/jackett/

        # Move new installation
        mv /tmp/Jackett /opt/jackett/
        chown drewsturgiss:drewsturgiss /opt/jackett/

        # Start service
        sudo systemctl stop jackett
        sudo systemctl start jackett
        sudo systemctl status jackett
}

manageInstall() {
        # Get the download URL for the latest Jackett version
        download_url=`getDownloadURL`

        # Determine the version number for the installed Jackett version
        downloaded_version=`getDownloadedVersion`

        # Determine the version number for the latest available Jackett version
        remote_version=`getLatestJackettVersion ${download_url}`

        # Determine if this system is running the latest Jackett version. If not, download the latest jacket version.
        latest_version=`compareVersions ${downloaded_version} ${latest_version}`
        if [ ${latest_version} == "Remote" ]; then
                downloadJackett ${download_url}
        fi

        # Install the downloaded Jackett version
        installJackett ${downloaded_version}
}

if ! systemctl is-active --quiet jackett; then
        echo "Jackett is down, reinstalling"
        manageInstall
else
        echo "Jackett is running, doing nothing"
fi

case "$(pgrep jackett | head -n 1 | wc -w)" in

0)  echo "Jackett is down"
    manageInstall
1)  check=$(curl -m 10 -s -w "%{http_code}\n" -L  http://127.0.0.1:15000 -o /dev/null)
    if [[ $check == 200 || $check == 403 ]]; then
        #service online
        echo "Jackett service responding"
    else
        echo "Jackett is running but not responding"
                manageInstall
    fi
    ;;
*)  echo "Jackett Unexpected result"
        manageInstall
    ;;
esac
