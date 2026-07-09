class riscv_checker extends uvm_component;
	//Registrarse en la fábrica
    `uvm_component_utils(riscv_checker)

  	uvm_analysis_imp #(analysis_item, riscv_checker) checker_port;

    virtual ifc_riscv ifc_riscv_obj; //instancia de la interfaz virtual

    riscv_scoreboard scoreboard; //instacia del scoreboard

    int pass_count;
    int fail_count;

    // Estado para verificar el flujo de PC entre transacciones consecutivas:
    // el expected_next_pc de la transaccion anterior debe coincidir con el
    // pc real de la transaccion actual (cubre branch tomado/no-tomado, JAL,
    // JALR y el flujo normal pc+4 de todo lo demas).
    bit          have_prev;
    logic [31:0] prev_expected_next_pc;

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
        have_prev  = 0;

    endfunction

  	virtual function void write(analysis_item t); //funcion que compara modelo de referencia con el DUT, recibe la transaccion resuelta por el scoreboard en t

        logic [31:0] actual_mem_word;
        bit ok;

        ok = 1;

        // 1) Registro destino: solo aplica si la instruccion realmente
        //    escribe rd (R, I-ALU, LOAD, LUI, AUIPC, JAL, JALR). Para
        //    STORE/BRANCH, instruction[11:7] es parte del inmediato, no
        //    un indice de registro, asi que NO se debe comparar.
        if (t.writes_rd) begin
            if (t.expected_result !== ifc_riscv_obj.regs[t.expected_rd]) begin
                ok = 0;
                `uvm_error(get_type_name(), $sformatf("ERROR rd=x%0d esperado=%08h obtenido=%08h", t.expected_rd, t.expected_result, ifc_riscv_obj.regs[t.expected_rd]))
            end
        end

        // 2) Memoria: solo aplica a STORE. Compara la palabra escrita en el
        //    espejo de memoria del DUT contra la que calculo el modelo de
        //    referencia.
        if (t.mem_we) begin
            actual_mem_word = ifc_riscv_obj.mem[t.mem_addr[11:2]];
            if (t.mem_wdata !== actual_mem_word) begin
                ok = 0;
                `uvm_error(get_type_name(), $sformatf("ERROR mem[%08h] esperado=%08h obtenido=%08h", t.mem_addr, t.mem_wdata, actual_mem_word))
            end
        end

        // 3) Flujo de control: aplica a toda instruccion (branch/JAL/JALR y
        //    tambien el flujo normal pc+4 de todas las demas).
        if (have_prev) begin
            if (prev_expected_next_pc !== t.pc) begin
                ok = 0;
                `uvm_error(get_type_name(), $sformatf("ERROR flujo de PC: esperado=%08h obtenido=%08h", prev_expected_next_pc, t.pc))
            end
        end
        have_prev             = 1;
        prev_expected_next_pc = t.expected_next_pc;

        if (ok) begin
            pass_count++;
          	`uvm_info(get_type_name(), $sformatf("PASS %s", t.convert2string()), UVM_LOW)
        end
        else begin
            fail_count++;
        end

      	$display("---------------------------------------------------------------------");

    endfunction

  	function void report_phase(uvm_phase phase); //se ejecuta solo al final de la simulacion

      	`uvm_info(get_type_name(), $sformatf("Resumen: PASS=%0d FAIL=%0d", pass_count, fail_count), UVM_NONE)

    endfunction

endclass

