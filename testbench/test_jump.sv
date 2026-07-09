// Test dirigido: programa de saltos (JAL y parejas AUIPC+JALR).
// Casos excepcionales: cada JALR va precedido de un AUIPC que deja la base
// en rs1, y la ultima posicion se rellena con una I-ALU.
// Se selecciona con +UVM_TESTNAME=riscv_jump_test
class riscv_jump_test extends riscv_test;

	//Registrarse en la fábrica
    `uvm_component_utils(riscv_jump_test)

    function new(string name = "riscv_jump_test", uvm_component parent = null);
        super.new(name,parent);
    endfunction

    // Unica diferencia con riscv_test: como se configura la secuencia
    virtual function riscv_sequence crear_secuencia();
        riscv_sequence s;
        s = riscv_sequence::type_id::create("seq");
        s.tipos_permitidos = '{riscv_item::J_TYPE};
        s.frecuencia_jalr  = 3; // parejas AUIPC+JALR frecuentes (~1 de cada 3 posiciones)
        return s;
    endfunction

endclass
