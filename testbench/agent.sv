class riscv_agent extends uvm_agent; //agente activo
	//Registrarse en la fábrica
    `uvm_component_utils(riscv_agent)
	//instancias de los componentes del agente activo
    riscv_sequencer sequencer;
    riscv_driver    driver;
    riscv_monitor   monitor;

  	function new(string name = "riscv_agent", uvm_component parent = null); //constructor
      
      	super.new(name,parent); //llama al constructor de la clase padre
    endfunction

  	function void build_phase(uvm_phase phase); //se llama sola cuando hay que crear componentes

      	super.build_phase(phase); //llama a la funcion build_phase de la clase padre

      	`uvm_info(get_type_name(), "Construyendo componentes del agente", UVM_LOW)

      	sequencer = riscv_sequencer::type_id::create( "sequencer", this);

      	driver = riscv_driver::type_id::create("driver", this);

      	monitor = riscv_monitor::type_id::create("monitor",this);

    endfunction
  
  task aplicar_reset(time duracion = 100);
        driver.aplicar_reset(duracion);
    endtask

    task cambiar_clk(time periodo);
        driver.cambiar_clk(periodo);
    endtask

  	function void connect_phase(uvm_phase phase); //se llama sola cuando hay que conectar componentes
 
      	super.connect_phase(phase); //llama a la funcion connect_phase de la clase padre

      	driver.seq_item_port.connect(sequencer.seq_item_export); //conexion del driver con el sequencer

      	`uvm_info(get_type_name(), "Driver conectado al Sequencer", UVM_LOW)

    endfunction

endclass