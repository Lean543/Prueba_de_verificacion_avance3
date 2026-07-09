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
    //@(negedge ifc_riscv_obj.idleproc);
    wait (ifc_riscv_obj.addr != 32'h0);
    //@(negedge ifc_riscv_obj.idleproc);

    //pipeline delay
    //repeat (1) @(posedge ifc_riscv_obj.clk);
    //lastaddr = 32'h0;

    while (ifc_riscv_obj.data != 32'h0) begin

        @(posedge ifc_riscv_obj.clk);

        //if (ifc_riscv_obj.addr != lastaddr) begin

            //lastaddr = ifc_riscv_obj.addr;

            // Esperar a que la ROM entregue la instrucción
            //@(posedge ifc_riscv_obj.clk);

            item = analysis_item::type_id::create("item");
            item.instruction = ifc_riscv_obj.data;
          	
          	$display("%0t PC_core=%d entrando_pipeline=%08h",
               $time,
               ifc_riscv_obj.addr,
               ifc_riscv_obj.data);

            ap.write(item);

        //end

    end
    
    repeat (2) @(posedge ifc_riscv_obj.clk); //esperar a 2 ultimas instrucciones

  endtask

endclass