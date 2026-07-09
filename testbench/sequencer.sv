class riscv_sequencer extends uvm_sequencer #(riscv_item); //recibe el item (estimulo)
	//Registrarse en la fábrica
    `uvm_component_utils(riscv_sequencer)
  	//contiene varios “data items”. Estos pueden ser visto como estímulos o transacciones que permiten crear diferentes escenarios para el DUT.
  	//comunica al driver con la secuencia, permitiendo crear un “handshake” para obtener los datos o estímulo que se enviarán al DUT

  	function new(string name = "riscv_sequencer", uvm_component parent = null);//constructor del sequencer
        super.new(name, parent);
    endfunction

endclass