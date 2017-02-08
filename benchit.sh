#!/bin/bash
for i in 4kr 4kw 8kr 8kw 64kr 64kw 1mr 1mw; do
command=""
if [ $# -eq 1 ]; then
	gseq=$(seq 1 $1)
elif [ $# -eq 2 ]; then
	gseq=$(seq 1 $2 $1)
fi
for g in $gseq; do
	echo $g
	commandset=("--client=loadgen"$g)
	command+="$commandset $i.fio "
done
	echo "running $i "
	fio $command >$i.out
	fio2gnuplot -b -g -o $i-bw
	fio2gnuplot -i -g -o $i-iops
	mv $i*.log archive
done

