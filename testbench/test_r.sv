// Test dirigido: programa de solo instrucciones tipo R
// (ADD, SUB, SLL, SLT, SLTU, XOR, SRL, SRA, OR, AND)
// Se selecciona con +UVM_TESTNAME=riscv_r_test
class riscv_r_test extends riscv_test;

	//Registrarse en la fábrica
    `uvm_component_utils(riscv_r_test)

    function new(string name = "riscv_r_test", uvm_component parent = null);
        super.new(name,parent);
    endfunction

    // Unica diferencia con riscv_test: como se configura la secuencia
    virtual function riscv_sequence crear_secuencia();
        riscv_sequence s;
        s = riscv_sequence::type_id::create("seq");
        s.tipos_permitidos = '{riscv_item::R_TYPE};
        s.frecuencia_jalr  = 0; // sin parejas AUIPC+JALR en programas dirigidos
        return s;
    endfunction

endclass
