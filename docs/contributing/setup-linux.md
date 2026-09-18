# Set up Linux development

Use Node.js version in [`.node-version`](../../.node-version), Python 3, a C/C++
compiler, `pkg-config`, and the Electron runtime libraries for your distribution.
On Ubuntu 24.04, install the build and test dependencies with:

```sh
sudo apt-get update
sudo apt-get install -y build-essential python3 pkg-config libsecret-1-dev \
  libgtk-3-0t64 libnss3 libasound2t64 libgbm1 libxss1 xvfb dbus-x11 gnome-keyring
```

Install JavaScript dependencies with the vendored Yarn version:

```sh
node vendor/yarn-1.21.1.js install --frozen-lockfile --production=false
node vendor/yarn-1.21.1.js run postinstall
```

See [Linux builds](linux-builds.md) for Docker packaging, both architectures,
local CI with `act`, and distribution tests. For feedback on this fork, use
[its issue tracker](https://github.com/fluffy-furry/desktop/issues).
