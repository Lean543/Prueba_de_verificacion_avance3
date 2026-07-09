class riscv_checker extends uvm_component;
	//Registrarse en la fábrica
    `uvm_component_utils(riscv_checker)

  	uvm_analysis_imp #(analysis_item, riscv_checker) checker_port;

    virtual ifc_riscv ifc_riscv_obj; //instancia de la interfaz virtual

    riscv_scoreboard scoreboard; //instacia del scoreboard

    int pass_count;
    int fail_count;

  	function new(string name = "riscv_checker", uvm_component parent = null);

      	super.new(name,parent); //llama al constructor de la clase padre

      	checker_port = new("checker_port",this); //llama al constructor de la conexion analysis_export

    endfunction

    function void build_phase(uvm_phase phase);

      	super.build_phase(phase); //llama a la funcion build_phase de la clase padre

      	if(!uvm_config_db#(virtual ifc_riscv)::get(this, "","ifc_riscv_obj", ifc_riscv_obj)) begin //se comprueba la conexion con la interfaz virtual
              `uvm_fatal(get_type_name(), "No se pudo obtener la interfaz virtual");
        end

        pass_count = 0;
        fail_count = 0;

    endfunction

  	virtual function void write(analysis_item t); //funcion que compara modelo de referencia con registros del core, recibe la instruccion del suscriber en t 

        logic [31:0] expected_result;
        logic [4:0] rd_number;
      
        expected_result = t.expected_result;
		rd_number       = t.expected_rd;
      	/*$display("%0t x1=%h x2=%h x3=%h x4=%h",
         $time,
         ifc_riscv_obj.regs[1],
         ifc_riscv_obj.regs[2],
         ifc_riscv_obj.regs[3],
         ifc_riscv_obj.regs[4]);*/

        //expected_result = scoreboard.return_result();

        //rd_number = scoreboard.return_rd();
      	//pipeline delay
    	//repeat (1) @(posedge ifc_riscv_obj.clk);

      	if(expected_result != ifc_riscv_obj.regs[rd_number]) begin //comparacion de los resultados

            fail_count++;

          	`uvm_error(get_type_name(), $sformatf( "ERROR rd=x%0d esperado=%08h obtenido=%08h", rd_number, expected_result, ifc_riscv_obj.regs[rd_number]))

        end
        else begin

            pass_count++;

          	`uvm_info(get_type_name(), $sformatf( "PASS rd=x%0d esperado=%08h obtenido=%08h", rd_number, expected_result, ifc_riscv_obj.regs[rd_number]), UVM_LOW)

        end
      
      	$display("---------------------------------------------------------------------");

    endfunction

  	function void report_phase(uvm_phase phase); //se ejecuta solo al final de la simulacion

      	`uvm_info(get_type_name(), $sformatf("Resumen: PASS=%0d FAIL=%0d", pass_count, fail_count), UVM_NONE)

    endfunction

endclass

