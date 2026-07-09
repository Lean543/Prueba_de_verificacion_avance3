class riscv_test extends uvm_test;
	//Registrarse en la fábrica
    `uvm_component_utils(riscv_test)
  
  	//cantidad de instrucciones precargadas en el .mem
  	localparam int PRELOAD = 15;
   	//cantidad de instrucciones randomizadas para el test
    localparam int NUMERO_INSTRUCCIONES = 400;
  
	//instacias de las clases del entorno y la secuencia
    riscv_env env;
    riscv_sequence seq;
  	
  	bit enable_reset;
	bit enable_clock;

    function new(
        string name = "riscv_test",
        uvm_component parent = null
    );
        super.new(name,parent);
    endfunction

    function void build_phase(uvm_phase phase);
      
      	super.build_phase(phase); //llama a la funcion build_phase de la clase padre

      	env = riscv_env::type_id::create("env", this); // Definimos los objetos mediante el creador de la fábrica
        // "env" corresponde al nombre de la instancia con el que lo podemos encontrar en la base de datos.
        // this corresponde al "parent" de la instancia en cuestión.
      	uvm_config_db#(int)::set(this, "*", "num_instructions", NUMERO_INSTRUCCIONES);
        uvm_config_db#(int)::set(this, "*", "preload", PRELOAD);
      	
      	enable_reset = $test$plusargs("ENABLE_RESET");
    	enable_clock = $test$plusargs("ENABLE_CLOCK");
      
      	`uvm_info(get_type_name(),
          $sformatf("enable_reset=%0d enable_clock=%0d",
                    enable_reset, enable_clock),
          UVM_NONE)

    endfunction

    // Cada test hijo sobrescribe SOLO esta funcion para instanciar su propia secuencia
    virtual function riscv_sequence crear_secuencia();
        return riscv_sequence::type_id::create("seq");
    endfunction
  
  	virtual task ejecutar_reset_test();
        #900ns;
        env.agent.aplicar_reset();
    endtask

    virtual task ejecutar_clock_test();
        #900ns;
        env.agent.cambiar_clk(4ns);

        #1000ns;

      	env.agent.cambiar_clk(6ns);
	endtask

    task run_phase(uvm_phase phase);

        phase.raise_objection(this);

        `uvm_info(get_type_name(), "Iniciando secuencia RISCV", UVM_LOW)

        seq = crear_secuencia();
        seq.num_instructions = NUMERO_INSTRUCCIONES;

        seq.start(env.agent.sequencer);

        fork
            if (enable_reset)
                ejecutar_reset_test();

            if (enable_clock)
                ejecutar_clock_test();
        join_none

        #3000;

        phase.drop_objection(this);

    endtask

endclass
