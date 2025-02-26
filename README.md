# react-native-fast-crypto

This library implements fast, fully native crypto routines for React Native under iOS and Android. Fully built binaries are committed for both platforms but can also be built from scratch.

## Getting started

`npm install react-native-fast-crypto --save`

### Mostly automatic installation

`react-native link react-native-fast-crypto`

### Manual installation

#### Install in iOS app

1. In XCode, in the project navigator, right click `Libraries` ➜ `Add Files to [your project's name]`
2. Go to `node_modules` ➜ `react-native-fast-crypto` and add `RNFastCrypto.xcodeproj`
3. In XCode, in the project navigator, select your project. Add `libRNFastCrypto.a` to your project's `Build Phases` ➜ `Link Binary With Libraries`
4. Run your project (`Cmd+R`)<

#### Install in Android app

1. Open up `android/app/src/main/java/[...]/MainActivity.java`

- Add `import com.reactlibrary.RNFastCryptoPackage;` to the imports at the top of the file
- Add `new RNFastCryptoPackage()` to the list returned by the `getPackages()` method

2. Append the following lines to `android/settings.gradle`:
   ```
   include ':react-native-fast-crypto'
   project(':react-native-fast-crypto').projectDir = new File(rootProject.projectDir, 	'../node_modules/react-native-fast-crypto/android')
   ```
3. Insert the following lines inside the dependencies block in `android/app/build.gradle`:
   ```
     compile project(':react-native-fast-crypto')
   ```

## Build the C/C++ binaries from scratch (optional)

### Prerequisites

- Xcode (13.3 or later should work)
- brew

### Setup

```bash
sudo xcode-select --switch /Applications/Xcode.app
sudo xcodebuild -license

brew install autoconf automake cmake git pkgconfig protobuf python zlib

sudo mkdir -p /usr/local/bin
sudo ln -sf $(brew --prefix python)/bin/python3 /usr/local/bin/python
```

### Build

1. Build binaries

```bash
rm -rf /tmp/react-native-fast-crypto
git clone git@github.com:ExodusMovement/react-native-fast-crypto.git /tmp/react-native-fast-crypto
cd /tmp/react-native-fast-crypto
yarn build
```

(if you're building on Apple arm, M1 & M2, you can use `arch -x86_64 yarn build` instead of `yarn build`)

## Verification of build hashes (optional)

The following instructions describe the process necessary to verify the hashes generated in `shasums.txt`.
These instructions were tested in a fresh MacOS 15.3.1 VM with a single shared directory between the host and VM (`~/vm_shared/` on the host, `/Volumes/My\ Shared\ Files/vm_shared/` on the VM).
This process will take several hours, as many GBs of tooling is downloaded during the building process. Not recommended for data-limited connections.

Note: if you end up using these instructions, ensure that you are not using bash, as `arch -x86_64` will not work correctly (bash passes some environmental values which are picked up by the build process, making the build ignore whatever `arch -x86_64` does).

First, clone the repository and checkout the appropriate PR or branch, on the host:

```shell
git clone --depth=1 https://github.com/ExodusMovement/react-native-fast-crypto.git ~/vm_shared/react-native-fast-crypto
cd ~/vm_shared/react-native-fast-crypto
git fetch origin pull/76/head:pr-76
git checkout pr-76
```

Next, again from the host, copy Xcode (it is more comfortable to copy Xcode than to install it manually in the VM):

```shell
cp -r /Applications/Xcode.app ~/vm_shared/
```

From the VM, open the terminal and run:

```shell
sudo xcode-select --install
```

A window will appear confirming you want to install xcode. Agree/confirm.
This doesn't _actually_ install the Xcode application, so we will copy it from the host later on.

Next, back in the terminal:

```shell
sudo cp -r /Volumes/My\ Shared\ Files/vm_shared/Xcode.app /Applications/
sudo xcode-select --switch /Applications/Xcode.app
sudo xcodebuild -license
sudo xcodebuild -runFirstLaunch
sudo softwareupdate --all --install --force
sudo softwareupdate --install-rosetta --agree-to-license

/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> $HOME/.zprofile && source $HOME/.zprofile
brew install autoconf automake cmake git pkgconfig protobuf python zlib

sudo mkdir -p /usr/local/bin
sudo ln -sf $(brew --prefix python)/bin/python3 /usr/local/bin/python
```

At this point, you should reboot the VM. Why? No clue. But otherwise, the following error appears when building:

```txt
ld: warning: -bitcode_bundle is no longer supported and will be ignored
ld: -mllvm and -bitcode_bundle (Xcode setting ENABLE_BITCODE=YES) cannot be used together
clang: error: linker command failed with exit code 1 (use -v to see invocation)
```

Next:

```shell
sudo cp -r /Volumes/My\ Shared\ Files/vm_shared/react-native-fast-crypto ~/react-native-fast-crypto
cd ~/react-native-fast-crypto

rm -rf ios/Libraries android/jni/libs
arch -x86_64 ./build-deps

shasum --algorithm 256 --check shasums.txt
```

The final command should confirm that the checksums of the binaries in `shasums.txt` correspond to the source code.
