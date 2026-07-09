vsim +access+r -sv_seed random +UVM_TESTNAME=riscv_store_test +ENABLE_RESET +ENABLE_CLOCK;

run -all;

acdb save;
acdb report -db fcover.acdb -txt -o cov.txt -verbose;
exec cat cov.txt;

exit;