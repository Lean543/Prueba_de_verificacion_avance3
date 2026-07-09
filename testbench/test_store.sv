// Test dirigido: programa de solo instrucciones STORE (SW)
// Se selecciona con +UVM_TESTNAME=riscv_store_test
class riscv_store_test extends riscv_test;

	//Registrarse en la fábrica
    `uvm_component_utils(riscv_store_test)

    function new(string name = "riscv_store_test", uvm_component parent = null);
        super.new(name,parent);
    endfunction

    // Unica diferencia con riscv_test: como se configura la secuencia
    virtual function riscv_sequence crear_secuencia();
        riscv_sequence s;
        s = riscv_sequence::type_id::create("seq");
        s.tipos_permitidos = '{riscv_item::S_TYPE};
        s.frecuencia_jalr  = 0; // sin parejas AUIPC+JALR en programas dirigidos
        return s;
    endfunction

endclass
