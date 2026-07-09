vsim +access+r -sv_seed random +UVM_TESTNAME=riscv_test;

run -all;

acdb save;
acdb report -db fcover.acdb -txt -o cov.txt -verbose;
exec cat cov.txt;

exit;