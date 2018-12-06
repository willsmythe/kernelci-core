#!/bin/bash

set -x

if [ -z $KCI_STORAGE_URL ]; then
  echo "STORAGE not set, exiting"
  exit 1
fi

if [ -z $KCI_API_URL ]; then
  echo "API not set, exiting"
  exit 1
fi

if [ -z $LINUX_REMOTE_URL ]; then
  echo "LINUX_REMOTE_URL not set, exiting"
  exit 1
fi

if [ -z $WORKSPACE ]; then
  echo "WORKSPACE not set, exiting"
  exit 1
fi

rm -f ${WORKSPACE}/*.properties

# TODO: Move tree URLs into a common configuration file (see kci-config.json)
declare -A trees
trees=(
    [mainline]="https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git"
    [next]="https://git.kernel.org/pub/scm/linux/kernel/git/next/linux-next.git"
    [arm-soc]="https://git.kernel.org/pub/scm/linux/kernel/git/arm/arm-soc.git"
    [rmk]="git://git.armlinux.org.uk/~rmk/linux-arm.git"
    [stable]="https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux-stable.git"
    [omap]="https://git.kernel.org/pub/scm/linux/kernel/git/tmlind/linux-omap.git"
    [linux-linaro]="https://git.linaro.org/kernel/linux-linaro-tracking.git"
    [lsk]="https://git.linaro.org/kernel/linux-linaro-stable.git"
    [khilman]="https://git.kernel.org/pub/scm/linux/kernel/git/khilman/linux.git"
    [stable-sasha]="https://git.kernel.org/pub/scm/linux/kernel/git/sashal/linux-stable.git"
    [qcom-lt]="https://git.linaro.org/landing-teams/working/qualcomm/kernel.git"
    [samsung]="https://git.kernel.org/pub/scm/linux/kernel/git/kgene/linux-samsung.git"
    [dlezcano]="https://git.linaro.org/people/daniel.lezcano/linux.git"
    [tbaker]="https://github.com/EmbeddedAndroid/linux.git"
    [collabora]="http://cgit.collabora.com/git/linux.git"
    [rt-stable]="https://git.kernel.org/pub/scm/linux/kernel/git/rt/linux-stable-rt.git"
    [tegra]="https://git.kernel.org/pub/scm/linux/kernel/git/tegra/linux.git"
    [anders]="https://git.linaro.org/people/anders.roxell/linux.git"
    [viresh]="https://git.kernel.org/pub/scm/linux/kernel/git/vireshk/linux.git"
    [alex]="https://git.linaro.org/people/alex.bennee/linux.git"
    [krzysztof]="https://git.kernel.org/pub/scm/linux/kernel/git/krzk/linux.git"
    [agross]="https://git.kernel.org/pub/scm/linux/kernel/git/agross/linux.git"
    [broonie-regmap]="https://git.kernel.org/pub/scm/linux/kernel/git/broonie/regmap.git"
    [broonie-regulator]="https://git.kernel.org/pub/scm/linux/kernel/git/broonie/regulator.git"
    [broonie-sound]="https://git.kernel.org/pub/scm/linux/kernel/git/broonie/sound.git"
    [broonie-spi]="https://git.kernel.org/pub/scm/linux/kernel/git/broonie/spi.git"
    [renesas]="https://git.kernel.org/pub/scm/linux/kernel/git/horms/renesas.git"
    [llvm]="http://git.linuxfoundation.org/llvmlinux/kernel.git"
    [ulfh]="https://git.kernel.org/pub/scm/linux/kernel/git/ulfh/mmc.git"
    [ardb]="git://git.kernel.org/pub/scm/linux/kernel/git/ardb/linux.git"
    [evalenti]="https://git.kernel.org/pub/scm/linux/kernel/git/evalenti/linux-soc-thermal.git"
    [amitk]="https://git.linaro.org/people/amit.kucheria/kernel.git"
    [pmwg]="https://git.linaro.org/power/linux.git"
    [net-next]="git://git.kernel.org/pub/scm/linux/kernel/git/davem/net-next.git"
    [amlogic]="https://git.kernel.org/pub/scm/linux/kernel/git/khilman/linux-amlogic.git"
    [leg]="http://git.linaro.org/leg/acpi/leg-kernel.git"
    [stable-rc]="https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux-stable-rc.git"
    [efi]="https://git.kernel.org/pub/scm/linux/kernel/git/efi/efi.git"
    [android]="https://android.googlesource.com/kernel/common"
    [linaro-android]="https://android-git.linaro.org/git/kernel/linaro-android.git"
    [drm-tip]="https://anongit.freedesktop.org/git/drm/drm-tip.git"
    [arnd]="https://git.kernel.org/pub/scm/linux/kernel/git/arnd/playground.git"
    [cip]="https://git.kernel.org/pub/scm/linux/kernel/git/bwh/linux-cip.git"
    [mattface]="https://github.com/mattface/linux.git"
    [gtucker]="https://gitlab.collabora.com/gtucker/linux.git"
    [tomeu]="https://gitlab.collabora.com/tomeu/linux.git"
    [osf]="https://github.com/OpenSourceFoundries/linux.git"
    [clk]="https://git.kernel.org/pub/scm/linux/kernel/git/clk/linux.git"
    [dmaengine]="git://git.infradead.org/users/vkoul/slave-dma.git"
    [soundwire]="https://git.kernel.org/pub/scm/linux/kernel/git/vkoul/soundwire.git"
    [media]="https://git.linuxtv.org/media_tree.git"
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

curl ${KCI_STORAGE_URL}/${tree_name}/${branch}/last.commit > last.commit
if [ $? != 0 ] || [ ! -e last.commit ]
then
    echo "Failed to fetch the last.commit file, not triggering."
    echo "If this is a first build, create the file on storage."
fi

LAST_COMMIT=`cat last.commit`
rm -f last.commit

COMMIT_ID=`git ls-remote ${tree_url} refs/heads/${branch} | awk '{printf($1)}'`
if [ -z $COMMIT_ID ]
then
  echo "ERROR: branch $branch doesn't exist"
  exit 0
fi

if [ "x$COMMIT_ID" == "x$LAST_COMMIT" ]
then
  echo "Nothing new in $tree_name/$branch.  Skipping"
  exit 0
fi

echo "There was a new commit, time to fetch the tree"

#REFSPEC=+refs/heads/${branch}:refs/remotes/${tree_name}/${branch}
#if [ -e ${tree_name} ]; then
#  cd ${tree_name} && \
#  timeout --preserve-status -k 10s 5m git fetch --tags linus && \
#  timeout --preserve-status -k 10s 5m git fetch --tags ${tree_url} ${REFSPEC}
#else
#  git clone -o linus https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git ${tree_name}
#  cd ${tree_name} && \
#  git remote add origin ${tree_url} && \
#  timeout --preserve-status -k 10s 5m git fetch origin
#fi

################
# 
# This is a temporary workaround to save time on initial seeding of the trees and branches.

#pushd $LINUX_SRC

#git remote add ${tree_name} ${tree_url}

#timeout --preserve-status -k 10s 5m git fetch ${tree_name} ${REFSPEC}

#if [ $? != 0 ]; then
#  exit 1
#fi

#timeout --preserve-status -k 10s 5m git fetch origin ${REFSPEC}

#git remote update
#git clean -df
#git checkout -f --detach ${tree_name}/$branch
#if [ $? != 0 ]; then
#  echo "ERROR: branch $branch doesn't exist"
#  exit 0
#fi


REFSPEC=+refs/heads/${branch}:refs/remotes/origin/${branch}
if [ -e ${tree_name} ]; then
  pushd ${tree_name}
  timeout --preserve-status -k 10s 5m git fetch --tags linus && \
  timeout --preserve-status -k 10s 5m git fetch --tags ${tree_url} ${REFSPEC}
else
  git clone -o linus ${LINUX_REMOTE_URL} ${tree_name}
  pushd ${tree_name}
  git remote add origin ${tree_url} && \
  timeout --preserve-status -k 10s 5m git fetch origin  
fi
if [ $? != 0 ]; then
  exit 1
fi

timeout --preserve-status -k 10s 5m git fetch origin ${REFSPEC}

git remote update
git checkout -f origin/$branch
if [ $? != 0 ]; then
  echo "ERROR: branch $branch doesn't exist"
  exit 0
fi


# Ensure abbrev SHA1s are 12 chars
git config --local core.abbrev 12

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

#
# Dynamically create some special config fragments
#
# kselftests: create fragment by combining all the fragments from individual selftests
#             fragment file will have comment lines showing which selftest dir
#             each individual fragment came from
#
KSELFTEST_FRAG=kernel/configs/kselftest.config
find tools/testing/selftests -name config -printf "#\n# %h/%f\n#\n" -exec cat {} \; > $KSELFTEST_FRAG

popd

echo $COMMIT_ID > last.commit

curl --output /dev/null --silent --head --fail ${KCI_STORAGE_URL}/${tree_name}/${branch}/${GIT_DESCRIBE}/linux-src.tar.gz
if [ $? == 0 ]; then
    echo "This git describe was already triggered"
    ${KCI_CORE}/push-source.py --tree ${tree_name} --branch ${branch} --api ${KCI_API_URL} --token ${KCI_API_TOKEN} --file last.commit
    if [ $? != 0 ]; then
      echo "Error pushing last commit update to API, not updating current commit"
      rm last.commit
      exit 1
    fi
    exit 1
fi

tar -czf linux-src.tar.gz --exclude=.git -C ${tree_name} .
if [ $? != 0 ]; then
  echo "Failed to create source tarball"
  exit 1
fi

${KCI_CORE}/push-source.py --tree ${tree_name} --branch ${branch} --describe ${GIT_DESCRIBE} --api ${KCI_API_URL} --token ${KCI_API_TOKEN} --file linux-src.tar.gz
if [ $? != 0 ]; then
  echo "Error pushing source file to API"
  rm linux-src.tar.gz
  exit 1
fi

${KCI_CORE}/push-source.py --tree ${tree_name} --branch ${branch} --api ${KCI_API_URL} --token ${KCI_API_TOKEN} --file last.commit
if [ $? != 0 ]; then
  echo "Error pushing last commit update to API, not updating current commit"
  rm linux-src.tar.gz
  rm last.commit
  exit 1
fi

rm last.commit
rm linux-src.tar.gz

#
# TODO: Move this out of here and into an Azure Pipelines specific script or job configuration
#
pipeline_id=$(vsts build definition show --name ${TREE_BRANCH} --query id)
if [ $? == 0 ]; then
  echo "Found Azure Pipelines pipeline for ${TREE_BRANCH}. Queuing new build..."

  pipeline_vars="TREE=${tree_url}
    SRC_TARBALL=${KCI_STORAGE_URL}/${tree_name}/${branch}/${GIT_DESCRIBE}/linux-src.tar.gz
    TREE_NAME=$tree_name
    BRANCH=$branch
    COMMIT_ID=$COMMIT_ID
    GIT_DESCRIBE=${GIT_DESCRIBE}
    GIT_DESCRIBE_VERBOSE='${GIT_DESCRIBE_VERBOSE}'"

  echo ${pipeline_vars}

  vsts build queue --definition-id ${pipeline_id} --variables ${pipeline_vars}
fi

build_props=${TREE_BRANCH}-build.properties

cat << EOF > ${build_props}
TREE=$tree_url
SRC_TARBALL=${KCI_STORAGE_URL}/${tree_name}/${branch}/${GIT_DESCRIBE}/linux-src.tar.gz
TREE_NAME=$tree_name
BRANCH=$branch
COMMIT_ID=$COMMIT_ID
GIT_DESCRIBE=${GIT_DESCRIBE}
GIT_DESCRIBE_VERBOSE=${GIT_DESCRIBE_VERBOSE}
EOF

cat ${build_props}
