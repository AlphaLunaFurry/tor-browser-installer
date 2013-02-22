#!/usr/bin/env bash
# A simple script that installs the Tor Browser Bundle.

folder=$(cd "$(dirname "$0")" && pwd)
arch=$(uname -m)
name=tor-browser
lang_file="$folder/files/LANG"
tmp_dir=/tmp/tor-browser-installer
source_files=("$folder/files/$name.sh" "$folder/files/$name.desktop" "$folder/files/$name.png")
dest_files=("/usr/bin/$name" "/usr/share/applications/$name.desktop" "/usr/share/pixmaps/$name.png")

# text colors
echo_bld()
{
    echo -e "==> \033[1m"$@"\033[00m";
}
echo_g()
{
    echo -e "==> \033[0;32m"$@"\033[00m";
}
echo_r()
{
    echo -e "==> \033[0;31m"$@"\033[00m\n" >&2; exit 1;
}

language()
{
    # check if the 'files' directory is present
    if [[ ! -d $folder/files ]]; then
        echo
        echo_r "The directory containing the source files could not be found... aborting!"
    fi

    echo
    echo_bld "Please select your language:"

    # available languages
    local lang_list=(en-US ar de es-ES fa fr it ko nl pl pt-PT ru vi zh-CN QUIT)
    select i18n in ${lang_list[@]}; do
        if [[ -z $i18n ]]; then
            echo; echo_r "Invalid selection... aborting!"
        elif [[ $i18n == QUIT ]]; then
            exit 0
        fi
        # save the language to a file for later retrieval
        echo $i18n > "$lang_file" && chmod 0444 "$lang_file"
        break
    done
}

download()
{
    # check if the source files are available
    for file in "${source_files[@]}"; do
        if [[ ! -f $file ]]; then
            echo_r "The source files could not be found... aborting!"
        fi
    done

    # get the language
    while read line; do
        lang=$line
    done < "$lang_file"

    cd $tmp_dir
    echo -n "==> Determining the latest version... "

    # download the page and sed the latest version
    latest=$(curl -s -L https://www.torproject.org/download/download-easy.html.en | \
        sed -n '/.*gnu-linux-x86_64-\(.*\)-en-US.tar.gz.*/{s//\1/p;q}')
    tarball=$name-gnu-linux-$arch-$latest-$lang.tar.gz
    echo -e  "done.\n"
    
    # download the tarball
    echo -e "  -> \033[1mDownloading $tarball...\033[00m"
    curl -f -C - -O https://www.torproject.org/dist/torbrowser/linux/$tarball
    # if the return code is anything but 0 or 33, abort
    [[ ! $? == 0 && ! $? == 33 ]] && {
        echo; echo_r "There was an error downloading the sources... aborting!"; }
    # download the gpg signature
    echo -e "  -> \033[1mDownloading $tarball.asc...\033[00m"
    curl -f -C - -O https://www.torproject.org/dist/torbrowser/linux/$tarball.asc
    [[ ! $? == 0 && ! $? == 33 ]] && {
        echo; echo_r "There was an error downloading the sources... aborting!"; }

    # if the gpg key is available, verify the source
    if gpg -k 416F061063FEE659 &>/dev/null; then
        if gpg --verify $tmp_dir/$tarball{.asc,} &>/dev/null; then
            echo; echo_g "GPG: Signature succesfully verified."
        else
            echo; echo_r "GPG: BAD signature... aborting!"
        fi
    else
        echo; echo_bld "Warning: The GPG key was not found, and the signature could not be verified."
    fi
}

inst()
{
    # copy the source files to the tmp location
    cd $tmp_dir
    cp "$folder"/files/$name.{sh,png,desktop} ./

    # fill the appropiate variables
    sed -i "s/REPL_NAME/$name/g" $name.sh
    sed -i "s/REPL_VERSION/$latest/g" $name.sh
    sed -i "s/REPL_LANGUAGE/$lang/g" $name.sh
    sed -i "s/REPL_LANGUAGE/$lang/" $name.desktop

    echo "==> Installing..."

    # install the files
    sudo install -Dm755 $name.sh "/usr/bin/$name" || {
        echo; echo_r "The files could not be installed, please run the script again... aborting!"; }
    sudo install -Dm644 $name.desktop "/usr/share/applications/$name.desktop"
    sudo install -Dm644 $name.png "/usr/share/pixmaps/$name.png"
    sudo install -Dm644 $tarball "/opt/tor-browser/$tarball"

    # remove the temp directory
    rm -rf $tmp_dir

    echo
    echo_bld "Installation complete. You can now browse the web anonymously!"
    echo_bld "Just start the Tor Browser and have fun.\n"
}

uninst()
{
    # check if the tor-browser script is actually installed
    if [[ -f $dest_files ]]; then
        echo "==> Uninstalling..."
        # remove all the files
        for file in "${dest_files[@]}"; do
            sudo rm $file 2>/dev/null || {
                echo; echo_r "The files could not be uninstalled, please run the script again... aborting!"; }
        done

        # remove the tor-browser directory
        sudo rm -rf "/opt/tor-browser" 2>/dev/null

        echo
        echo_bld "Tor browser was uninstalled from your system. You must remove the tor-browser"
        echo_bld "folder from your home directory. As your regular user, run:"
        echo_bld ""
        echo_bld "$ rm -rf ~/.$name\n"
    else
        echo_r "Tor Browser doesn't seem to be installed on your system... aborting!"
    fi
}

# Run the script
# check if the arch is supported
if [[ ! $arch == i686 && ! $arch == x86_64 ]]; then
    echo; echo_r "Not a supported architecture... aborting!"
fi

# use 'hash' to find out if the dependencies are installed
needs=("curl" "sudo")
for dep in "${needs[@]}"; do
    if ! hash $dep 2>/dev/null; then
        echo; echo_r "You must have both 'curl' and 'sudo' installed... aborting!"
    fi
done

# if the language hasn't been set, prompt the user for it
while [[ ! -f $lang_file ]]; do
    language
done

# show the instructions
echo
echo -e "This script will install/uninstall the latest version of the Tor Browser Bundle."
echo -e "You are \033[4mstrongly\033[00m encouraged to import the GPG key that signs the Tor Browser Bundle"
echo -e "BEFORE proceeding. If you have not done so, please take a look at the README file.\n"
echo_bld "Please select an option:"

# ask the user to choose an option
options=("Install" "Uninstall" "QUIT")
select choice in "${options[@]}"; do
    if [[ -z $choice ]]; then
        echo; echo_r "Invalid selection... aborting!"
    elif [[ $choice == QUIT ]]; then
        exit 0
    fi
    break
done

# show the choice made and ask for confirmation
echo
echo "==> You have selected the \"$choice\" option."
echo_bld "Are you sure you want to continue? [Y/n]"
echo -n "==> "

read confirmation
conf=$(echo "$confirmation" | tr '[:lower:]' '[:upper:]')

if [[ $conf == Y || $conf == YES ]]; then
    echo
    echo -e "==> Confirmation received... continuing."
    if [[ $choice == Install ]]; then
        # Create the tmp directory
        [[ -d $tmp_dir ]] || mkdir $tmp_dir || exit 1
        download && inst
    else
        uninst
    fi
elif [[ $conf == N || $conf == NO ]]; then
    exit 0
else
    echo; echo_r "Confirmation failed... aborting!"
fi

exit 0

# vim:set ts=4 sw=4 et:
