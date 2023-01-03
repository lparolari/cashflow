echo "WARNING: This operation will create s version tag and push to github"
read -p "Version? (provide the next X.Y.Z semver) : " TAG
echo "${TAG}" > cashflow/VERSION
sed -i -E "/version/s/.*/version = \"${TAG}\"/" pyproject.toml
git add cashflow/VERSION pyproject.toml
git commit -m "release: v${TAG}"
echo "creating git tag : v${TAG}"
git tag ${TAG}
read -p "Are you sure you want to continue? [y/N] " CONFIRM
if [ "${CONFIRM}" != "y" ]; then echo "Aborted"; exit; fi
git push -u origin HEAD --tags
echo "Github Actions will detect the new tag and release the new version."