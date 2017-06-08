#!/bin/bash

set -x

STORAGE_URL=https://staging-storage.kernelci.org
API_URL=https://staging-api.kernelci.org

declare -A trees
trees=(
    [mainline]="http://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git"
    [next]="http://git.kernel.org/pub/scm/linux/kernel/git/next/linux-next.git"
    [arm-soc]="http://git.kernel.org/pub/scm/linux/kernel/git/arm/arm-soc.git"
    [rmk]="git://git.armlinux.org.uk/~rmk/linux-arm.git"
    [stable]="http://git.kernel.org/pub/scm/linux/kernel/git/stable/linux-stable.git"
    [omap]="http://git.kernel.org/pub/scm/linux/kernel/git/tmlind/linux-omap.git"
    [linux-linaro]="https://git.linaro.org/kernel/linux-linaro-tracking.git"
    [lsk]="https://git.linaro.org/kernel/linux-linaro-stable.git"
    [khilman]="http://git.kernel.org/pub/scm/linux/kernel/git/khilman/linux.git"
    [stable-sasha]="http://git.kernel.org/pub/scm/linux/kernel/git/sashal/linux-stable.git"
    [qcom-lt]="https://git.linaro.org/landing-teams/working/qualcomm/kernel.git"
    [samsung]="http://git.kernel.org/pub/scm/linux/kernel/git/kgene/linux-samsung.git"
    [dlezcano]="https://git.linaro.org/people/daniel.lezcano/linux.git"
    [tbaker]="https://github.com/EmbeddedAndroid/linux.git"
    [collabora]="http://cgit.collabora.com/git/linux.git"
    [rt-stable]="http://git.kernel.org/pub/scm/linux/kernel/git/paulg/linux-stable-rt.git"
    [tegra]="http://git.kernel.org/pub/scm/linux/kernel/git/tegra/linux.git"
    [anders]="https://git.linaro.org/people/anders.roxell/linux-rt.git"
    [viresh]="http://git.kernel.org/pub/scm/linux/kernel/git/vireshk/linux.git"
    [alex]="https://git.linaro.org/people/alex.bennee/linux.git"
    [krzysztof]="http://git.kernel.org/pub/scm/linux/kernel/git/krzk/linux.git"
    [agross]="http://git.kernel.org/pub/scm/linux/kernel/git/agross/linux.git"
    [broonie-regmap]="http://git.kernel.org/pub/scm/linux/kernel/git/broonie/regmap.git"
    [broonie-regulator]="http://git.kernel.org/pub/scm/linux/kernel/git/broonie/regulator.git"
    [broonie-sound]="http://git.kernel.org/pub/scm/linux/kernel/git/broonie/sound.git"
    [broonie-spi]="http://git.kernel.org/pub/scm/linux/kernel/git/broonie/spi.git"
    [renesas]="http://git.kernel.org/pub/scm/linux/kernel/git/horms/renesas.git"
    [llvm]="http://git.linuxfoundation.org/llvmlinux/kernel.git"
    [ulfh]="http://git.kernel.org/pub/scm/linux/kernel/git/ulfh/mmc.git"
    [ardb]="https://git.linaro.org/people/ard.biesheuvel/linux-arm.git"
    [evalenti]="http://git.kernel.org/pub/scm/linux/kernel/git/evalenti/linux-soc-thermal.git"
    [amitk]="https://git.linaro.org/people/amit.kucheria/kernel.git"
    [pmwg]="https://git.linaro.org/power/linux.git"
    [net-next]="git://git.kernel.org/pub/scm/linux/kernel/git/davem/net-next.git"
    [amlogic]="http://git.kernel.org/pub/scm/linux/kernel/git/khilman/linux-amlogic.git"
    [leg]="http://git.linaro.org/leg/acpi/leg-kernel.git"
    [stable-rc]="http://git.kernel.org/pub/scm/linux/kernel/git/stable/linux-stable-rc.git"
    [efi]="http://git.kernel.org/pub/scm/linux/kernel/git/efi/efi.git"
    [android]="https://android.googlesource.com/kernel/common"
    [linaro-android]="https://android-git.linaro.org/git/kernel/linaro-android.git"
    [drm-tip]="https://anongit.freedesktop.org/git/drm/drm-tip.git"
    [arnd]="http://git.kernel.org/pub/scm/linux/kernel/git/arnd/playground.git"
    [cip]="https://git.kernel.org/pub/scm/linux/kernel/git/bwh/linux-cip.git"
    [mattface]="https://github.com/mattface/linux.git"
)

OFS=${IFS}
IFS='#'
arr=($TREE_BRANCH)
IFS=${OFS}

tree_name=${arr[0]}
tree_url=${trees[$tree_name]}
branch=${arr[1]}
if [[ -z ${branch} ]]; then
  branch="master"
fi

echo "Looking for new commits in ${tree_url} (${tree_name}/${branch})"

THIS_COMMIT=${tree_name}-${branch}-this.commit
LAST_COMMIT=${tree_name}-${branch}-last.commit

COMMIT_ID=`git ls-remote ${tree_url} refs/heads/${branch} | awk '{printf($1)}'`
if [ -z $COMMIT_ID ]
then
  echo "ERROR: branch $branch doesn't exist"
  exit 0
fi

echo $COMMIT_ID > $THIS_COMMIT

if [ ! -e $LAST_COMMIT ]; then
  echo -n 0 > $LAST_COMMIT
fi

diff -w $LAST_COMMIT $THIS_COMMIT
if [ $? == 0 ]; then
  echo "Nothing new in $tree_name/$branch.  Skipping"
  exit 0
fi


echo "There was a new commit, time to fetch the tree"

REFSPEC=+refs/heads/${branch}:refs/remotes/origin/${branch}
if [ -e ${tree_name} ]; then
  cd ${tree_name} && \
  timeout --preserve-status -k 10s 5m git fetch --tags linus && \
  timeout --preserve-status -k 10s 5m git fetch --tags ${tree_url} ${REFSPEC}
else
  git clone -o linus http://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git ${tree_name}
  cd ${tree_name} && \
  git remote add origin ${tree_url} && \
  timeout --preserve-status -k 10s 5m git fetch origin
fi
if [ $? != 0 ]; then
  exit 1
fi

timeout --preserve-status -k 10s 5m git fetch origin ${REFSPEC}

rm -f *.properties
git remote update
git checkout -f origin/$branch
if [ $? != 0 ]; then
  echo "ERROR: branch $branch doesn't exist"
  exit 0
fi

# Ensure abbrev SHA1s are 12 chars
git config --global core.abbrev 12

# Only use v3.x tags in arm-soc tree
unset describe_args
[ ${tree_name} = "arm-soc" ] && describe_args="--match=v\*"
GIT_DESCRIBE=$(eval git describe $describe_args)
GIT_DESCRIBE=${GIT_DESCRIBE//\//_}  # replace any '/' with '_'
GIT_DESCRIBE_VERBOSE=$(eval git describe --match=v[34]\*)

if [ -z $GIT_DESCRIBE ]; then
  echo "Unable to determine a git describe, exiting"
  exit 1
fi

cd ${WORKSPACE}
rm -f *.properties

tar -czf linux-src.tar.gz --exclude=.git -C ${tree_name} .
if [ $? != 0 ]; then
  echo "Failed to create source tarball"
  exit 1
fi

./push-source.py --tree ${tree_name} --branch ${branch} --describe ${GIT_DESCRIBE} --api ${API_URL} --token ${API_TOKEN} --file linux-src.tar.gz
if [ $? != 0 ]; then
  echo "Error pushing source file to API, not updating current commit"
  rm linux-src.tar.gz
  rm ${THIS_COMMIT}
  exit 1
fi
./push-source.py --tree ${tree_name} --branch ${branch} --describe ${GIT_DESCRIBE} --api ${API_URL} --token ${API_TOKEN} --file ${THIS_COMMIT}
if [ $? != 0 ]; then
  echo "Error pushing last commit update to API, not updating current commit"
  rm linux-src.tar.gz
  rm ${THIS_COMMIT}
  exit 1
fi

rm linux-src.tar.gz
cp $THIS_COMMIT $LAST_COMMIT


cat << EOF > ${WORKSPACE}/${TREE_BRANCH}-build.properties
TREE=$tree_url
SRC_TARBALL=${STORAGE_URL}/${tree_name}/${branch}/${GIT_DESCRIBE}/linux-src.tar.gz
TREE_NAME=$tree_name
BRANCH=$branch
COMMIT_ID=$COMMIT_ID
GIT_DESCRIBE=${GIT_DESCRIBE}
GIT_DESCRIBE_VERBOSE=${GIT_DESCRIBE_VERBOSE}
PUBLISH=true
EOF

cat ${WORKSPACE}/${TREE_BRANCH}-build.properties