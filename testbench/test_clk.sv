class riscv_clock_test extends riscv_test;

    `uvm_component_utils(riscv_clock_test)
  
  function new(string name = "riscv_clock_test", uvm_component parent = null);
        super.new(name,parent);
    endfunction

    virtual task ejecutar_clock_test();

        env.agent.cambiar_clk(4);

        #500;

        env.agent.cambiar_clk(1);

        #500;

        env.agent.cambiar_clk(2);

    endtask

endclass