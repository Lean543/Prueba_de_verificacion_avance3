class riscv_reset_test extends riscv_test;

    `uvm_component_utils(riscv_reset_test)
  
  function new(string name = "riscv_reset_test", uvm_component parent = null);
        super.new(name,parent);
    endfunction

    virtual task ejecutar_reset_test();

        #500;

        env.aplicar_reset();

    endtask

endclass