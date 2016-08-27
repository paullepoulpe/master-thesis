set boxwidth 0.9 absolute
set style fill   solid 1.00 border lt -1
set key inside right top vertical Right noreverse noenhanced autotitle nobox
set style histogram clustered gap 1 title textcolor lt -1
set datafile missing '-'
set style data histograms
set xtics  norangelimit
set xtics   ()
set title "TPCHQ6 running times in microseconds"
set yrange [ 0 : 60 ] noreverse nowriteback
x = 0.0
plot 'data/TPCHQ6.dat' using 2:xtic(1) title columnheader(2), \
for [i=3:5] '' using i title columnheader(i)
