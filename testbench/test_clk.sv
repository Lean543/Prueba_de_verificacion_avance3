class riscv_clock_test extends riscv_test;

    `uvm_component_utils(riscv_clock_test)
  
  function new(string name = "riscv_clock_test", uvm_component parent = null);
        super.new(name,parent);
    endfunction

    virtual task ejecutar_clock_test();

        env.variar_reloj();

    endtask

endclass