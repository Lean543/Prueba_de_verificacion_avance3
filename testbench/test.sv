class riscv_test extends uvm_test;
	//Registrarse en la fábrica
    `uvm_component_utils(riscv_test)
  
  	//cantidad de instrucciones precargadas en el .mem
  	localparam int PRELOAD = 15;
   	//cantidad de instrucciones randomizadas para el test
    localparam int NUMERO_INSTRUCCIONES = 50;
  
	//instacias de las clases del entorno y la secuencia
    riscv_env env;
    riscv_sequence seq;

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

    endfunction

    // Cada test hijo sobrescribe SOLO esta funcion para instanciar su propia secuencia
    virtual function riscv_sequence crear_secuencia();
        return riscv_sequence::type_id::create("seq");
    endfunction
  
  	virtual task ejecutar_reset_test();

        #500;

        env.agent.aplicar_reset();

    endtask

    virtual task ejecutar_clock_test();

        #500;

        env.agent.cambiar_clk(4);

        #1000;

        env.agent.cambiar_clk(2);

    endtask

    task run_phase(uvm_phase phase);

      	phase.raise_objection(this); // Debemos levantar una objecion para que el test no termine antes de tiempo

      	`uvm_info(get_type_name(), "Iniciando secuencia RISCV", UVM_LOW)
      
      	seq = crear_secuencia();
      	seq.num_instructions = NUMERO_INSTRUCCIONES;

      	seq.start(env.agent.sequencer);

        fork
            ejecutar_reset_test();
            ejecutar_clock_test();
        join_none

        #3000; //tiempo de simulacion

      	phase.drop_objection(this); //llama a que termine la simulacion y uvm entre en estado de extract, check y report

    endtask

endclass
