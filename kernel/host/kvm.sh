#!/usr/bin/env bash

set -E -e -u -o pipefail

cd ~/core/nixos-kernel
version=$(uname -r)
tarfile=linux-${version}.tar.xz

if [[ ! -f $tarfile ]]; then
	wget https://mirrors.edge.kernel.org/pub/linux/kernel/v6.x/"$tarfile"
fi

srcdir=linux-${version}
if [[ ! -d $srcdir ]]; then
	tar -xvf "$tarfile"
fi

cd "$srcdir"
zcat /proc/config.gz >.config

if [[ ! -d .git ]]; then
	git init
	git add -A
	git commit -m "init"
fi

function exe() {
	command="$1"
	echo "$command"
	nix-shell '<nixpkgs>' -A linuxPackages_latest.kernel --command "$command"
}

# @todo
# 不知道为什么，有报错！
# 难道是因为 nixos 存在什么 patch 吗?
# exe "make ./arch/x86/kernel/kvm-intel.ko"
# @todo
# 如何使用 direnv ?
cat <<_EOF_
  DESCEND objtool
  DESCEND bpf/resolve_btfids
  CALL    scripts/checksyscalls.sh
make[3]: *** No rule to make target 'arch/x86/kernel/kvm-intel.o'.  Stop.
make[2]: *** [scripts/Makefile.build:504: arch/x86/kernel] Error 2
make[1]: *** [scripts/Makefile.build:504: arch/x86] Error 2
make: *** [Makefile:2021: .] Error 2
_EOF_

cat <<_EOF_
[ 1503.956995] kvm: version magic '6.2.12-g6825a3677969-dirty SMP preempt mod_unload ' should be '6.2.12 SMP preempt mod_unload '
[ 1503.962909] kvm_intel: version magic '6.2.12-g6825a3677969-dirty SMP preempt mod_unload ' should be '6.2.12 SMP preempt mod_unload '
[ 1580.326624] kvm: version magic '6.2.12-g6825a3677969-dirty SMP preempt mod_unload ' should be '6.2.12 SMP preempt mod_unload '
[ 1580.333232] kvm_intel: version magic '6.2.12-g6825a3677969-dirty SMP preempt mod_unload ' should be '6.2.12 SMP preempt mod_unload '
_EOF_

# scripts/setlocalversion =>
# include/config/kernel.release =>
# linux-6.2.12/include/generated/utsrelease.h
#
# 所以将 scripts/setlocalversion 最后一行删除掉
# 但是还是存在这个错误，都不知道插入了没有，而且现在也是修改一行，整个代码重新编译
# 再仔细想想吧!
cat << _EOF_
[10606.080260] BPF:      type_id=52229 bits_offset=896
[10606.080263] BPF:
[10606.080264] BPF: Invalid name
[10606.080264] BPF:
[10606.080266] failed to validate module [kvm] BTF: -22
[10606.089001] BPF:      type_id=52229 bits_offset=896
[10606.089004] BPF:
[10606.089005] BPF: Invalid name
[10606.089005] BPF:
[10606.089006] failed to validate module [kvm_intel] BTF: -22
_EOF_


exe "m"
sudo rmmod kvm_intel kvm
sudo insmod ./arch/x86/kvm/kvm.ko
sudo insmod ./arch/x86/kvm/kvm-intel.ko

sudo modprobe kvm-intel
