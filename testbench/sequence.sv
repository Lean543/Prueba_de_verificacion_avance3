class riscv_sequence extends uvm_sequence #(riscv_item);

    `uvm_object_utils(riscv_sequence)

    // ---- Configuracion que cada test ajusta antes de start() ----
    int num_instructions;
    int frecuencia_jalr      = 8; // pareja AUIPC+JALR en ~1 de cada N posiciones; 0 = nunca
    riscv_item::instr_type_e tipos_permitidos[$]; // vacio = todos los tipos (programa mixto)

    int pc;

    function new(string name = "riscv_sequence");
        super.new(name);
    endfunction

    // 1 si en tipos_permitidos hay al menos un tipo que no sea salto hacia adelante
    function bit hay_tipo_sin_salto();
        foreach (tipos_permitidos[i])
            if (!(tipos_permitidos[i] inside {riscv_item::B_TYPE, riscv_item::J_TYPE, riscv_item::I_JALR_TYPE}))
                return 1;
        return 0;
    endfunction

    // Randomiza el item respetando la lista de tipos permitidos del test.
    // Caso excepcional: en la ultima posicion del programa no cabe un salto hacia
    // adelante (constraint no_flow_at_end); si el programa dirigido es SOLO de
    // saltos (branch/jump) esa posicion se rellena con una I-ALU.
    function void randomizar(riscv_item it);
        bit ok;

        if (tipos_permitidos.size() == 0)
            ok = it.randomize();
        else if ((it.pc + 4 > it.max_pc) && !hay_tipo_sin_salto())
            ok = it.randomize() with { instr_type == riscv_item::I_ALU_TYPE; };
        else
            ok = it.randomize() with { instr_type inside {tipos_permitidos}; };

        if (!ok)
            `uvm_fatal(get_type_name(), "Error al randomizar instruction item")
    endfunction

    task body();

        riscv_item req;
        riscv_item auipc;
        int ultimo_pc;
        int base_reg;
        int max_target; // direccion mas lejana que puede alcanzar un B/J/JALR ya emitido

        pc = 0;
        // pc y max_pc en el mismo marco: relativos al inicio del programa generado
        // (los offsets de branch/jump son relativos al PC, asi que el marco absoluto no importa)
        ultimo_pc = (num_instructions - 1) * 4;
        max_target = -1;

        while (pc <= ultimo_pc) begin

            // Pareja AUIPC+JALR (~1 de cada frecuencia_jalr posiciones). Condiciones:
            //  - caben las dos instrucciones y el salto minimo (+8 desde el AUIPC)
            //  - ningun B/J emitido antes puede aterrizar SOBRE el JALR saltandose su AUIPC
            //    (max_target < pc+4). Aterrizar sobre el AUIPC es seguro: la pareja se
            //    ejecuta completa y la base queda bien.
            if (frecuencia_jalr > 0 && (pc + 8) <= ultimo_pc && max_target < (pc + 4)
                && ($urandom_range(0, frecuencia_jalr - 1) == 0)) begin

                // 1) AUIPC rd, 0: deja en rd el PC de esta misma instruccion (base del JALR)
                auipc = riscv_item::type_id::create("auipc");
                auipc.pc     = pc;
                auipc.max_pc = ultimo_pc;

                start_item(auipc);
                if (!auipc.randomize() with { instr_type == riscv_item::U_TYPE; u_select == 1'b0; imm_u == 0; })
                    `uvm_fatal(get_type_name(), "Error al randomizar AUIPC de la pareja JALR")
                auipc.build_instruction();
                `uvm_info(get_type_name(), $sformatf("Generada instruccion: %s", auipc.convert2string()), UVM_MEDIUM)
                finish_item(auipc);

                base_reg = auipc.rd;
                pc += 4;

                // 2) JALR rd, imm(base): destino = PC del AUIPC + imm, conocido en generacion
                req = riscv_item::type_id::create("req");
                req.pc              = pc;
                req.max_pc          = ultimo_pc;
                req.jalr_habilitado = 1;

                start_item(req);
                if (!req.randomize() with { instr_type == riscv_item::I_JALR_TYPE; rs1 == base_reg; })
                    `uvm_fatal(get_type_name(), "Error al randomizar JALR")
                req.build_instruction();
                `uvm_info(get_type_name(), $sformatf("Generada instruccion: %s", req.convert2string()), UVM_MEDIUM)
                finish_item(req);

                if (((pc - 4) + req.imm_i) > max_target)
                    max_target = (pc - 4) + req.imm_i;
                pc += 4;

            end
            else begin

                req = riscv_item::type_id::create("req");

                // El item conoce su PC y el ultimo PC valido del programa
                req.pc     = pc;
                req.max_pc = ultimo_pc;

                start_item(req);
                randomizar(req);
                req.build_instruction();
                `uvm_info(get_type_name(), $sformatf("Generada instruccion: %s", req.convert2string()), UVM_MEDIUM)
                finish_item(req);

                // registrar hasta donde puede aterrizar el flujo ya emitido
                if (req.instr_type == riscv_item::B_TYPE && (pc + req.imm_b) > max_target)
                    max_target = pc + req.imm_b;
                if (req.instr_type == riscv_item::J_TYPE && (pc + req.imm_j) > max_target)
                    max_target = pc + req.imm_j;

                pc += 4;

            end

        end

    endtask

endclass
