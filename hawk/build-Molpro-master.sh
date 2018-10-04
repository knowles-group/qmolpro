#!/bin/sh

# Build Molpro for Hawk
# The installer needs personal permission to clone git@bitbucket.org:pjknowles/myMolpro

# configuration
prefix=$HOME/software # where to install to
working_directory=$HOME/trees/Molpro # careful! if this directory already exists it will be completely destroyed first
#working_directory=/scratch/$USER/trees/Molpro # careful! if this directory already exists it will be completely destroyed first
# GITPATH=/home/c.sacpjk/bin # need git version 1.9 or higher
module load compiler/gnu/6
module load compiler/intel/2018/3
module load mpi/intel
module load raven; module load git
eigen_version=3.3.5
ga_version=v5.7
make_processes=50
# end configuration - shouldn't need to change below here

if [ x"$GITPATH" != x ]; then export PATH=$GITPATH:$PATH ; fi

rm -fr $working_directory && mkdir -p $working_directory && cd $working_directory || exit 1
mkdir -p ${prefix}/bin || exit 1

git clone https://github.com/GlobalArrays/ga || exit 1
cd ga || exit 1
git checkout $ga_version || exit 1
./autogen.sh
./configure FC=mpif90 CXX=mpicxx CC=mpicc --with-openib --prefix=$working_directory --with-blas=no --with-lapack=no --with-scalapack=no --disable-f77
make -j$make_processes && make install
cd $working_directory

git clone https://github.com/eigenteam/eigen-git-mirror Eigen || exit 1
cd Eigen
git checkout $eigen_version || exit 1
mkdir -p build || exit 1
cd build
cmake -DCMAKE_INSTALL_PREFIX=${working_directory} ..
make install
cd $working_directory

git clone git@bitbucket.org:pjknowles/myMolpro Molpro || exit 1
cd Molpro
git checkout master
# Molpro's official repository and branches
officialOrigin=git@www.molpro.net:Molpro
officialBranchRegExp='[0-9][0-9]|master|release'

# official branches should be pushed to officialOrigin not mirror
git remote add officialOrigin $officialOrigin
branchprefix=remotes/origin/
for branch in $(git branch -a --no-color --no-column | egrep "^ *$branchprefix($officialBranchRegExp)" | sed -e 's/\*//' | sed -e "s@$branchprefix@@" | sort | uniq) ; do
    git config --add branch.$branch.pushremote officialOrigin
done

./configure FC=ifort CXX=mpicxx --enable-mpp=ga CPPFLAGS="-I${working_directory}/include -I${working_directory}/include/eigen3" --prefix=$prefix LDFLAGS="-libverbs -L ${working_directory}/lib" LAUNCHER='srun %x' --bindir=${prefix}/bin
make -j$make_processes || exit 1
make uninstall
make install

cd $working_directory

git clone git@bitbucket.org:pjknowles/qmolpro
cp -p qmolpro/hawk/qmolpro ${prefix}/bin
