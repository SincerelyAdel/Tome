# APK builder

One repo that builds Android APKs for your other repos, only when you ask.
Your source repos keep just their code, and no Actions minutes are spent on
pushes.

It builds Flutter apps (`pubspec.yaml` at the root) and Gradle apps
(`gradlew` at the root), signs every APK with one key so new builds install
as updates, and publishes them as a release of the builder repo.

## Set up

1. Create a new repo, for example `apk-builder`, and copy
   `.github/workflows/build-apk.yml` into it.
2. In the new repo, add these secrets under **Settings → Secrets and
   variables → Actions**:

   | Secret | What it is |
   |---|---|
   | `SOURCE_TOKEN` | A token that can read the repos you'll build. Fine-grained: **Contents: Read** on those repos. Classic: `repo`. Not needed if they're all public. |
   | `ANDROID_KEYSTORE_BASE64` | Your signing keystore, base64-encoded. Optional, but without it each build uses a new key and won't install over the last one. |
   | `ANDROID_KEYSTORE_PASSWORD` | The keystore's password. |

   To make a keystore and its base64 text:

   ```sh
   keytool -genkeypair -keystore apps.jks -alias key -keyalg RSA -validity 10000
   base64 -w0 apps.jks   # paste the output into ANDROID_KEYSTORE_BASE64
   ```

   Keep `apps.jks` somewhere safe: losing it means the next build can't
   update the installed apps.
3. In RepoViewer, go to **Settings** and enter the builder repo as
   `owner/apk-builder`.
4. Open the **APKs** page and tap **Build APK**, then pick a repo.
   The APKs show up on the same page when the build finishes.

## Saving minutes

- **Public builder repo:** Actions minutes are free and unlimited in public
  repos. The catch is that its releases (your APKs) are public too.
- **Private builder repo:** builds count against your monthly minutes, so
  only `arm64` is built by default, Gradle and Flutter downloads are cached,
  a newer build of the same branch cancels the older one, and a build stops
  after 25 minutes.
- **Your own PC:** a
  [self-hosted runner](https://docs.github.com/actions/hosting-your-own-runners)
  costs no minutes at all. Change `runs-on: ubuntu-latest` to
  `runs-on: self-hosted`.
- Remove the `push:` trigger from workflows in your source repos so they only
  build here.
