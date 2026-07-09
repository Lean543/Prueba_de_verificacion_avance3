class riscv_monitor extends uvm_monitor;
  `uvm_component_utils(riscv_monitor)

  uvm_analysis_port #(analysis_item) ap;

  virtual ifc_riscv ifc_riscv_obj;
  
  //logic [31:0] lastaddr;

  function new(string name = "riscv_monitor", uvm_component parent = null);
    super.new(name, parent);
    ap = new("ap", this);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    if (!uvm_config_db#(virtual ifc_riscv)::get(
          this, "", "ifc_riscv_obj", ifc_riscv_obj))
      `uvm_fatal(get_type_name(), "No se pudo obtener ifc_riscv_obj")
  endfunction


  task run_phase(uvm_phase phase);

    analysis_item item;

    // Espera a que el procesador salga de reset/idle
    wait (ifc_riscv_obj.addr != 32'h0);

    while (ifc_riscv_obj.data != 32'h0) begin

        @(posedge ifc_riscv_obj.clk);

        // ifc_riscv_obj.idleproc (DUT.core0.IDLE = |FLUSH) esta alineado,
        // ciclo a ciclo, con ifc_riscv_obj.data (XIDATA) e ifc_riscv_obj.pc
        // (PC). Cuando esta en 1, la instruccion que acaba de llegar a
        // XIDATA es una burbuja descartada por un salto/branch tomado (el
        // pipeline de 3 etapas ya redirigio el fetch, pero XIDATA todavia
        // arrastra 1-2 ciclos de instrucciones "fantasma" que el DUT nunca
        // llega a ejecutar). No se debe reportar como instruccion real.
        //
        // ifc_riscv_obj.hlt se asierta durante el wait-state que insertan
        // los LOAD (1 ciclo extra en este core). Mientras hlt=1, XIDATA/PC
        // quedan CONGELADOS -- sin este chequeo, el mismo LOAD se captura
        // dos veces (una por cada ciclo que permanece en XIDATA), lo que
        // duplica esa transaccion en el scoreboard y rompe tanto el chequeo
        // de flujo de PC como la sincronizacion del buffer de pipeline.
        if (!ifc_riscv_obj.idleproc && !ifc_riscv_obj.hlt) begin

            item = analysis_item::type_id::create("item");
            item.instruction = ifc_riscv_obj.data;
            item.pc          = ifc_riscv_obj.pc;

            $display("%0t PC_core=%08h entrando_pipeline=%08h",
                 $time,
                 ifc_riscv_obj.pc,
                 ifc_riscv_obj.data);

            ap.write(item);

        end

    end

    repeat (2) @(posedge ifc_riscv_obj.clk); //esperar a 2 ultimas instrucciones

  endtask

endclass