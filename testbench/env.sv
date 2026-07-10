class riscv_env extends uvm_env;
	//Registrarse en la fábrica
    `uvm_component_utils(riscv_env)
	//instancias de los objetos de componentes en el entorno
    riscv_agent      agent;
    riscv_scoreboard scoreboard;
    riscv_checker checker_obj;
    riscv_subscriber subscriber;

    function new(
        string name = "riscv_env",
        uvm_component parent = null
    );
      super.new(name,parent); //llama al constructor de la clase padre
    endfunction

  	function void build_phase(uvm_phase phase); //llamadas a constructores

      	super.build_phase(phase); //llama a la funcion build_phase de la clase padre

      	`uvm_info(get_type_name(), "Construyendo ambiente RISCV", UVM_LOW)
		//llamadas a los contructores de los objetos del ambiente:
      	agent = riscv_agent::type_id::create("agent", this); 

     	scoreboard = riscv_scoreboard::type_id::create("scoreboard", this);

      	checker_obj = riscv_checker::type_id::create("checker", this);

      	subscriber = riscv_subscriber::type_id::create("subscriber", this);

    endfunction

  	function void connect_phase(uvm_phase phase); //se llama en la etapa de conexiones

        super.connect_phase(phase);

      	agent.monitor.ap.connect(scoreboard.analysis_export); //conexion monitor con scoreboard mediante el puerto analysis_export

      	scoreboard.checker_port.connect(checker_obj.checker_port); //conexion checker con scoreboard mediante el puerto analysis_export

        // El subscriber se alimenta de la MISMA salida del scoreboard que el
        // checker (no del monitor): asi recibe la transaccion ya resuelta por
        // el modelo de referencia, con branch_taken, expected_result,
        // mem_addr/mem_wdata y expected_next_pc poblados, que los covergroups
        // por funcion necesitan muestrear. Nota: las ultimas PIPELINE_DELAY=2
        // instrucciones del programa quedan en el buffer del scoreboard y no
        // se muestrean (impacto despreciable con programas de 400 instrucciones).
        scoreboard.checker_port.connect(subscriber.analysis_export);
	
        checker_obj.scoreboard = scoreboard; //para instancia del scoreboard en el checker

      	`uvm_info(get_type_name(), "Conexiones TLM completadas", UVM_LOW)

    endfunction

endclass