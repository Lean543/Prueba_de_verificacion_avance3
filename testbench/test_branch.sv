// Test dirigido: programa de solo branches (BEQ/BNE/BLT/BGE/BLTU/BGEU).
// Caso excepcional: la ultima posicion del programa se rellena con una I-ALU
// porque ahi no cabe un salto hacia adelante (lo maneja la secuencia).
// Se selecciona con +UVM_TESTNAME=riscv_branch_test
class riscv_branch_test extends riscv_test;

	//Registrarse en la fábrica
    `uvm_component_utils(riscv_branch_test)

    function new(string name = "riscv_branch_test", uvm_component parent = null);
        super.new(name,parent);
    endfunction

    // Unica diferencia con riscv_test: como se configura la secuencia
    virtual function riscv_sequence crear_secuencia();
        riscv_sequence s;
        s = riscv_sequence::type_id::create("seq");
        s.tipos_permitidos = '{riscv_item::B_TYPE};
        s.frecuencia_jalr  = 0; // sin parejas AUIPC+JALR en programas dirigidos
        return s;
    endfunction

endclass
