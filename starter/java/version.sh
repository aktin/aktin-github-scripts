# shellcheck shell=bash
# Asks for the Java version and sets it as java.version and as the enforcer
# floor in pom.xml, in the workflows and in the READMEs. Fails when the JDK on
# PATH is older, because the pre-push hook builds with it. Sourced by
# new-repo.sh in the new repository.
current=$(sed -n 's|.*<java.version>\([0-9]*\)</java.version>.*|\1|p' pom.xml)
java_version=$(ask "Java version" "$current" "The feature release to build with, for example 25. Also the lowest supported one")
[[ "$java_version" =~ ^[0-9]+$ ]] || fail "$java_version is not a Java feature release like 25"
installed=$(java -version 2>&1 | sed -n 's/.* version "\([0-9]*\).*/\1/p')
[ "${installed:-0}" -ge "$java_version" ] || fail "Java $java_version needs a JDK $java_version or newer on PATH, found ${installed:-none}"
sed -i -e "s|<java.version>$current</java.version>|<java.version>$java_version</java.version>|" \
  -e "s|older than $current or|older than $java_version or|" -e "s|\[$current,)|[$java_version,)|" pom.xml
sed -i "s|java-version: \"$current\"|java-version: \"$java_version\"|" .github/workflows/*.yml
sed -i "s|Java $current\b|Java $java_version|g" README.md .github/workflows/README.md
