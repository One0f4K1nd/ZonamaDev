#!/bin/bash
if [ -z "$BASH_VERSION" ]; then
    echo "** MUST RUN FROM bash, please run again from bash! **"
    exit 15
fi

ZONAMADEV_URL='https://github.com/One0f4K1nd/ZonamaDev'
ZONAMADEV_BRANCH='master'
OS='unknown'

main() {
    case $HOME in
	*' '* )
	    echo
	    echo 'Your $HOME has spaces in it:'
	    echo
	    echo "  HOME=[$HOME]"
	    echo
	    echo 'Vagrant is based on Ruby which has issues with spaces in $HOME'
	    echo
	    echo 'In order to use this system you must have a username without spaces'
	    echo 'or you must manually override HOME to a directory without spaces.'
	    echo
	    echo 'You could try working around this by doing the following:'
	    echo
	    echo '  mkdir /c/swgemudev'
	    echo '  export HOME=/c/swgemudev'
	    echo '  cd $HOME'
	    echo '  curl -Lk http://downloads.zonamaserver.org/zonamadev/bootstrap.sh | bash '"$@"
	    echo
	    echo 'However, every time you want to work with this system you will need to reset'
	    echo 'your HOME when you open the bash shell window.'
	    echo
	    echo '** Process aborted, Spaces in HOME **'
	    exit 13
	    ;;
    esac

    case $(uname -s) in
	Darwin ) OS='osx' ;;
	*Linux* ) OS='linux' ;;
	*_NT* ) OS='win';;
	* ) echo "Not sure what OS you are on, guessing Windows"; OS='win';;
    esac

    # Handle destroy or uninstall
    if [ "X$1" = "Xdestroy" -o "X$1" = "Xuninstall" ]; then
	if reset_zd "$1"; then
	    echo "######################################"
	    echo "## ZonamaDev Host Environment Reset ##"
	    echo "######################################"

	    if [ "X$1" = "Xuninstall" ]; then
		echo "** ZonamaDev has been uninstalled from this computer **"
		exit 0
	    fi
	else
	    echo "** Aborted by user **"
	    exit 14
	fi
        shift
    fi

    # Handle release {x.y}
    if [ "X$1" = "Xrelease" -a "X$2" != "X" ]; then
        shift
        ZONAMADEV_BRANCH="release-$1"
        shift
    fi

    # Handle branch {branchName}
    if [ "X$1" = "Xbranch" -a "X$2" != "X" ]; then
        shift
        ZONAMADEV_BRANCH="$1"
        shift
    fi

    if [ -z "${ZONAMADEV_BRANCH}" ]; then
        echo "ERROR: No branch to boot from?, GET HELP"
        exit 126
    fi

    echo "######################################"
    echo "## Using branch ${ZONAMADEV_BRANCH}"
    echo "######################################"

    check_versions

    # Used by fasttrack/upgrade.sh to verify host software versions
    if [ "X$1" = "Xcheck-versions" ]; then
        shift
        exit 0
    fi

    if [ -n "$1" ]; then
        [ "$1" != "help" ] && echo "** Unexpected arguments: [$@]"
        echo
        echo "Usage: $0 (help|destroy|uninstall|branch {branchName}|release {x.y})"
        echo
        exit 0
    fi

    # If we're under the ZonamaDev dir back out to parent
    cd ${PWD/ZonamaDev*/}

    echo "** ZDHOME=${PWD} **"

    ## Clone Repo
    echo "Using ${ZONAMADEV_URL} branch ${ZONAMADEV_BRANCH}"
    if git clone -b ${ZONAMADEV_BRANCH} ${ZONAMADEV_URL}; then
	:
    else
	case $PWD in
	*ZonamaDev* ) : ;;
	* ) if [ -d ZonamaDev ]; then
	        cd ZonamaDev
	    else
		echo "** Something is wrong, did you try and run this in the right directory? **"
		echo "** We suggest you run it from $HOME **"
		exit 1
	    fi
	    ;;
	esac

        git stash

        git fetch --all

	if git pull --all; then
	    :
	else
	    echo "** Failed to pull too, you might need help!"
	    exit 1
	fi

        if git checkout "${ZONAMADEV_BRANCH}"; then
            :
        else
            echo "** Failed to checkout branch ${ZONAMADEV_BRANCH}, GET HELP!"
            exit 125
        fi
    fi

    ## hand off to next script
    cd ${PWD/ZonamaDev*/}"/ZonamaDev/fasttrack"

    echo "** Running in $PWD **"

    exec ./setup.sh

    echo "** Something went wrong, get help **"

    exit 11
}

check_versions() {
    ## Check for git
    if git --version > /dev/null 2>&1; then
	:
    else
	eval install_git_$OS
    fi

    if [ "$OS" = "win" ]; then
	echo "** Checking for Git Bash **"
	check_gitbash_$OS
    fi

    echo "** Checking for VirtualBox **"
    check_virtualbox_$OS

    echo "** Checking for Vagrant **"
    check_vagrant_$OS

    return 0
}

install_git_win() {
    echo "** Please download and install git-for-windows at: https://git-for-windows.github.io/"
    echo "** When that is complete, please use Git Bash shell to run this script again"
    exit 0
}

install_git_osx() {
    echo "** Please download XCode for OSX at: https://developer.apple.com/xcode/downloads/"
    open https://developer.apple.com/xcode/downloads/
    echo "** When that is complete, please restart this script."
    exit 0
}

install_git_linux() {
    # Assume deb for now?
    sudo apt-get install git < /dev/tty

    if git --version > /dev/null 2>&1; then
	:
    else
	echo "** Failed to install git, **ABORT**"
	exit 12
    fi
}

check_gitbash_win() {
    local ver_min="4.3.0"
    local ver=$("${vbm}" --version)

    if [ -z "${MSYSTEM}" ]; then
        echo "** MUST RUN FROM GITBASH SHELL NOT CYGWIN, ABORTING **"
        exit 16
    fi

    if version_error "${ver_min}" "${BASH_VERSION}"; then
	echo "Unsupported version of BASH (${BASH_VERSION}), please upgrade to BASH 4.3.x+"
	exit 1
    fi

    for i in tty mktemp sed scp ssh find cygpath
    do
	if type -P $i > /dev/null; then
	    :
	else
	    echo "** You're missing the $i command, you need to upgrade git for windows"
	    echo "** Please download and install the latest from: https://git-for-windows.github.io/"
	    exit 1
	fi
    done

    echo "** BASH_VERSION: ${BASH_VERSION} **"

    return 0
}

check_virtualbox_win() {
    local ver_min="5.2.14"
    local ve=$(wmic cpu get VirtualizationFirmwareEnabled/value | grep TRUE)

    if [ -z "$ve" ]; then
	echo "############################################################################"
	echo "## ERROR: YOU MUST ENABLE VIRTUALIZATION IN YOUR BIOS BEFORE YOU CONTINUE ##"
	echo "############################################################################"
	echo
	echo "** Unless you know what you're doing most likely you will not be able to start the VM **"
	echo
	if yorn "Do you want to stop and fix the BIOS setting now?"; then
	    echo "** Please close this window, boot into your BIOS, enable virtualization and try again **"
	    exit 202
	fi
	echo
	echo "** USER IGNORING VT WARNING **"
	wmic cpu get VirtualizationFirmwareEnabled/value
	echo "*****"
    fi

    if [ -z "$VBOX_INSTALL_PATH" -a -z "$VBOX_MSI_INSTALL_PATH" ]; then
	echo -e "** You need to install VirtualBox for windows **\n"

	if yorn "Would you like me to take you to: https://www.virtualbox.org/wiki/Downloads?"; then
	    explorer "https://www.virtualbox.org/wiki/Downloads"
	fi

	echo "** Please close this window, install VirtualBox, REBOOT and try again **"
	exit 1
    fi

    local ver=$("${VBOX_MSI_INSTALL_PATH:-${VBOX_INSTALL_PATH}}/VBoxManage" --version)

    if version_error "${ver_min}" "${ver}"; then
        echo "Unsupported version of virtualbox ($ver), please upgrade to ${ver_min} or higher"
	exit 1
    fi

    echo "** Virtualbox version $ver **"

    return 0
}

check_virtualbox_linux() {
    local ver_min="5.2.14"
    local vbm=$(type -P VBoxManage)

    if [ -z "${vbm}" ]; then
        echo -e "** You need to install VirtualBox (${ver_min} or higher) for Linux **\n"

	echo -e '** Please go to https://www.virtualbox.org/wiki/Linux_Downloads and follow directions there to install virtualbox'

	echo -e '** After you have virtualbox installed re-try this command.'

	exit 1
    fi

    local ver=$("${vbm}" --version)

    if version_error "${ver_min}" "${ver}"; then
        echo "Unsupported version of virtualbox ($ver), please upgrade to ${ver_min} or higher"
	exit 1
    fi

    echo "** Virtualbox version $ver **"

    return 0
}

check_virtualbox_osx() {
    local ver_min="5.2.14"
    local vbm=$(type -P VBoxManage)

    if [ -z "${vbm}" ]; then
        echo -e "** You need to install VirtualBox (${ver_min} or higher) for OSX**\n"

	echo -e '** Please go to https://www.virtualbox.org/wiki/Linux_Downloads and follow directions there to install virtualbox'

	echo -e '** After you have virtualbox installed re-try this command.'

	exit 1
    fi

    local ver=$("${vbm}" --version)

    if version_error "${ver_min}" "${ver}"; then
        echo "Unsupported version of virtualbox ($ver), please upgrade to ${ver_min} or higher"
	exit 1
    fi

    echo "** Virtualbox version $ver **"
}

check_vagrant_base() {
    local ver_min="2.1.2"
    local ver=$(vagrant --version | cut -d' ' -f2 2> /dev/null)

    if [ -z "$ver" ]; then
        if [ -n "$(type -P vagrant)" ]; then
            echo -e "** You might have a broken version of vagrant installed\n\nvagrant -v"

            vagrant -v

            if yorn "Is the version of vagrant installed ${ver_min} or higher?"; then
                echo "** Please note that you could have problems unless you downgrade to ${ver_min}"
                return 0
            else
                echo "** Please close this window, install Vagrant ${ver_min} or higher and try again **"
                exit 1
            fi
        fi

	echo -e "** You need to install Vagrant ${ver_min} or higher **\n"

	if yorn "Would you like me to take you to: https://www.vagrantup.com/downloads.html?"; then
	    explorer "https://www.vagrantup.com/downloads.html"
	fi

	echo "** Please close this window, install Vagrant and try again **"
	exit 1
    fi

    if version_error "${ver_min}" "${ver}"; then
	echo "Unsupported version of Vagrant ($ver), please upgrade to v${ver_min} or higher"
        exit 1
    fi

    echo "** Vagrant version $ver **"

    return 0
}

check_vagrant_win() {
    check_vagrant_base
    return $?
}

check_vagrant_osx() {
    check_vagrant_base
    return $?
}

check_vagrant_linux() {
    check_vagrant_base

    local dp=$(type -P dpkg)

    if [ -z "${dp}" ]; then
	echo "** WARNING: Without dpkg we can not check for zlib, you may need to manually install it for vagrant to work **"
    else
	if dpkg -s zlib1g-dev > /dev/null 2>&1; then
	    :
	else
	    echo "** please make sure zlib1g-dev is installed **"
	    exit
	fi
    fi

    return 0
}

reset_zd() {
    echo "##################################################################################"
    echo "## WARNING THIS WILL REMOVE ALL ZonamaDev VM's AND REMOVE YOUR ZonamaDev FOLDER ##"
    echo "##################################################################################"

    local msg="Are you sure you want to destroy the old setup?"

    if [ "X$1" = "Xuninstall" ]; then
	msg="Are you sure you want to uninstall ZonamaDev?"
    fi

    if yorn "\n${msg}"; then
	:
    else
	return 1
    fi

    (
	cd /
	echo "** Checking for ZonamaDev vagrant VM images..."
	found=false
	vagrant global-status|grep ZonamaDev|while read id name provider state dir
	 do
	     echo "Destroy VMid $id from $dir"
	     vagrant destroy "${id}" --force
	     found=true
	 done

	 if $found; then
	     echo "** Removed all ZonamaDev VM images **"
	 else
	     echo "** No ZonamaDev VM images where found **"
	 fi
    )

    echo "** Removing any cached copies of base box **"
    vagrant box list | awk '/^zonama/ { print $1 }' | while read basebox
    do
        vagrant box remove ${basebox} --all --force
    done

    echo "** Looking for the ZonamaDev host directory..."
    local found_zd=false
    for i in "$PWD" "$HOME"
    do
	local zddir="${i}/ZonamaDev"
	if [ -d "${zddir}" ]; then
	    echo "** Removing ${zddir} **"
	    rm -fr "${zddir}"
	    found_zd=true
	fi
    done

    if $found_zd; then
	echo "** Removed ZonamaDev host directory **"
    else
	echo "** Did not find the ZonamaDev host directory **"
    fi

    if [ -d ~/.vagrant.d ]; then
	echo "** Removing vagrant settings directory **"
	rm -fr ~/.vagrant.d
    fi

    return 0
}

yorn() {
  local yorn
  if tty -s; then
      echo -n -e "$@ Y\b" > /dev/tty
      read yorn < /dev/tty
      case $yorn in
	[Nn]* ) return 1;;
      esac
  fi

  return 0
}

version_error() {
    local want="$1"
    local have="$2"

    read have_maj have_min have_sub have_misc <<<${have//[^0-9]/ }
    read want_maj want_min want_sub want_misc <<<${want//[^0-9]/ }

    if [ "${have_maj}" -lt "${want_maj}" ]; then
        return 0
    fi

    if [ "${have_maj}" -gt "${want_maj}" ]; then
        return 1
    fi

    if [ "${have_min}" -gt "${want_min}" ]; then
        return 2
    fi

    if [ "${have_sub}" -gt "${want_sub}" ]; then
        return 3
    fi

    if [ "${have_maj}" -eq "${want_maj}" -a "${have_min}" -eq "${want_min}" -a "${have_sub}" -eq "${want_sub}" ]; then
        return 4
    fi

    return 0
}

main "$@" < /dev/tty

exit 0
