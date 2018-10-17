#!/bin/sh

# Build Molpro for Hawk
# The installer needs personal permission to clone git@bitbucket.org:pjknowles/myMolpro
compilersystem=intel
if [ x$1 = xgnu ]; then compilersystem=gnu; suffix='-gnu' ; fi

# configuration
prefix=$HOME/software${suffix} # where to install to
working_directory=/scratch/$USER/trees/Molpro${suffix} # careful! if this directory already exists it will be completely destroyed first
# GITPATH=/home/c.sacpjk/bin # need git version 1.9 or higher
module load raven; module load git
if [ $compilersystem = intel ]; then
module load compiler/gnu/6
module load compiler/intel/2018/3
module load mpi/intel/2018/3
MPICXX=mpicxx
MPICC=mpicc
FC=mpif90
CXXFLAGS='-xCORE-AVX512'
FCFLAGS='-xCORE-AVX512'
else
module load compiler/gnu/8
module load compiler/intel/2018/3
module load mpi/intel/2018/3
MPICXX=mpigxx
#FCFLAGS='-mavx512f -mavx512cd -mavx512bw -mavx512dq -mavx512vl -mavx512ifma -mavx512vbmi'
FCFLAGS='-march=skylake'
CXXFLAGS="-cxx=g++ ${FCFLAGS}"
MPICC=mpigcc
CFLAGS='-cc=gcc'
FC=gfortran
fi
module list
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
./configure MPICC=${MPICC} CC=${MPICC} CFLAGS="${CFLAGS}" --with-openib --prefix=$working_directory --with-blas=no --with-lapack=no --with-scalapack=no --disable-f77
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

module list
echo $PATH
echo ./configure FC=${FC}  CXX=${MPICXX} FCFLAGS="${FCFLAGS}" CXXFLAGS="${CXXFLAGS}"  --enable-mpp=ga CPPFLAGS="-I${working_directory}/include -I${working_directory}/include/eigen3" --prefix=$prefix LDFLAGS="-libverbs -L ${working_directory}/lib" LAUNCHER='srun %x' --bindir=${prefix}/bin
./configure FC=${FC}  CXX=${MPICXX} FCFLAGS="${FCFLAGS}" CXXFLAGS="${CXXFLAGS}"  --enable-mpp=ga CPPFLAGS="-I${working_directory}/include -I${working_directory}/include/eigen3" --prefix=$prefix LDFLAGS="-libverbs -L ${working_directory}/lib" LAUNCHER='srun %x' --bindir=${prefix}/bin
make -j$make_processes || exit 1
make uninstall
make install

cd $working_directory

git clone git@bitbucket.org:pjknowles/qmolpro
cp -p qmolpro/hawk/qmolpro ${prefix}/bin
