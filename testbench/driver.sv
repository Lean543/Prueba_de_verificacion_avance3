class riscv_driver extends uvm_driver #(riscv_item); //usa get_next_item() / get() para tomar el item, lo drivea a DUT y llama item_done() (o envía RSP) para desbloquear la sequence.
	//Registrarse en la fábrica
    `uvm_component_utils(riscv_driver)
  	virtual ifc_riscv ifc_riscv_obj;

    int instructions_file;
  	int num_instructions;
    int preload;

  	function new(string name = "riscv_driver", uvm_component parent = null); //constructor del driver
        super.new(name,parent);
    endfunction

  	function void build_phase(uvm_phase phase); //se llama sola cuando llega la etapa build

        super.build_phase(phase);
    	if(!uvm_config_db#(int)::get(this, "", "num_instructions", num_instructions))
          `uvm_fatal(get_type_name(), "No se pudo obtener num_instructions en el driver")
        if(!uvm_config_db#(int)::get(this, "", "preload", preload))
          `uvm_fatal(get_type_name(), "No se pudo obtener preload en el driver")
        if(!uvm_config_db#(virtual ifc_riscv)::get(this, "", "ifc_riscv_obj", ifc_riscv_obj))
          `uvm_fatal(get_type_name(), "No se pudo obtener ifc_riscv_obj en el driver")
    endfunction

    task aplicar_reset(time duracion = 20ns);

        ifc_riscv_obj.aplicar_reset(duracion);

    endtask

    task cambiar_clk(time periodo);

        ifc_riscv_obj.cambiar_periodo(periodo);

    endtask

  	task run_phase(uvm_phase phase); //run se ejecuta al inicio de la simulacion sin ser llamado explicitamente

        riscv_item req; //instancia del sequence_item
        int preload_fd;
        bit [31:0] preload_instr;
        bit [31:0] preload_instrs[$]; // preserva el programa semilla (ej. ADDI x1..x15=1..15)
        int j;

      	//comprobacion del archivo de instrucciones desde aqui:

        // Preservar las 'preload' instrucciones ya presentes en darksocv.mem
        // ANTES de truncar el archivo. Antes se abria en modo "a" (append):
        // como $readmemh siempre llena MEM[] desde el inicio del archivo, si
        // el archivo no se reinicia entre corridas, el bloque generado en
        // ESTA corrida terminaba mas abajo en el archivo que las 1024
        // palabras que $readmemh realmente carga, y nunca se ejecutaba -- se
        // veian solo las instrucciones precargadas (siempre al inicio del
        // archivo). Ahora se lee y preserva el seed, y se reescribe el
        // archivo completo desde cero en cada corrida.
        preload_fd = $fopen("darksocv.mem", "r");
        if (preload_fd) begin
            for (j = 0; j < preload; j++) begin
                if ($fscanf(preload_fd, "%h", preload_instr) == 1)
                    preload_instrs.push_back(preload_instr);
            end
            $fclose(preload_fd);
        end
        else
            `uvm_warning(get_type_name(), "No se pudo leer darksocv.mem para preservar el preload")

      	instructions_file = $fopen("darksocv.mem","w");

        if(!instructions_file)
          	`uvm_fatal(get_type_name(), "No se pudo abrir darksocv.mem")

        foreach (preload_instrs[k])
            $fwrite(instructions_file, "%h\n", preload_instrs[k]);

      	`uvm_info(get_type_name(), "Archivo darksocv.mem abierto", UVM_LOW)


      	repeat (num_instructions) begin
          	seq_item_port.get_next_item(req); //recibe y se sincroniza con un ejercicio del sequencer

            $fwrite(instructions_file, "%h\n", req.instruction);

            `uvm_info(get_type_name(), $sformatf("Instruccion escrita: %08h", req.instruction), UVM_MEDIUM)
          
            //$fflush(instructions_file); //hace que el archivo darcsov.mem se escriba en la memoria de la pc a como está en ese momento sin 
            //cerrar el archivo pero provoca warning porque el archivo queda abierto, hay que solucionarlo
          	seq_item_port.item_done(); //manda al sequencer que ya termino el ejercio para que empiece con otro

        end
        // Rellenar resto de la memoria con NOPs
        repeat(1023 - preload - num_instructions) begin
          	$fwrite(instructions_file, "00000000\n");
        end

      	$fclose(instructions_file);
      	`uvm_info(get_type_name(), "Archivo darksocv.mem cerrado", UVM_MEDIUM)
    endtask

    /*function void report_phase(uvm_phase phase);
      
        if(instructions_file)
            $fclose(instructions_file);

      	`uvm_info(get_type_name(), "Archivo darksocv.mem cerrado", UVM_LOW)
      
      	$system("cat darksocv.mem");

    endfunction*/

endclass