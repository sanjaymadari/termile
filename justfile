default:
    @just --list

fcp:
    @flutter clean
    @flutter pub get

bundle-release: fcp
    @flutter build appbundle --release

upgrade:
    @flutter pub upgrade --major-versions
