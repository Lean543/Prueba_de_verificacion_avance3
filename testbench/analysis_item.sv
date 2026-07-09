//=============================================================================
// Clase: analysis_item
//
// Descripción:
//   Transacción que fluye entre el Monitor -> Scoreboard -> Checker.
//   Contiene tanto los datos capturados del DUT (entrada al scoreboard)
//   como los resultados calculados por el modelo de referencia (salida
//   del scoreboard hacia el checker).
//
// CONTRATO CON EL MONITOR:
//   El monitor DEBE poblar, antes de llamar a analysis_export.write(t),
//   los siguientes campos:
//     - instruction : la instrucción de 32 bits leída del DUT
//     - pc          : el PC correspondiente a esa instrucción
//   El resto de campos son calculados internamente por el scoreboard
//   (riscv_scoreboard::ref_model) y no deben ser escritos por el monitor.
//
// CONTRATO CON EL CHECKER:
//   El checker recibe la transacción ya resuelta por el modelo de
//   referencia (vía checker_port.write) y debe comparar los campos
//   "expected_" / "mem_" contra los valores reales observados en el DUT,
//   usando writes_rd/mem_we/mem_re/branch_taken para saber qué
//   comparaciones aplican en cada caso (ver detalle campo por campo más
//   abajo):
//     - writes_rd=1 -> comparar expected_rd/expected_result contra regs[]
//     - mem_we=1    -> comparar mem_addr/mem_wdata contra la memoria del DUT
//     - siempre     -> comparar expected_next_pc (de la transacción previa)
//                      contra el pc de la transacción actual
//=============================================================================
class analysis_item extends uvm_sequence_item;
    `uvm_object_utils(analysis_item)

    //-------------------------------------------------------------------
    // Datos de entrada (poblados por el MONITOR)
    //-------------------------------------------------------------------

    // Instrucción de 32 bits capturada del DUT.
    logic [31:0] instruction;

    // PC (Program Counter) de la instrucción actual, capturado del DUT.
    // Obligatorio para poder calcular expected_next_pc en branches,
    // JAL, JALR y AUIPC.
    logic [31:0] pc;

    //-------------------------------------------------------------------
    // Datos generales de decodificación (calculados por el scoreboard,
    // útiles para debug/logging, no todos aplican a todas las instrucciones)
    //-------------------------------------------------------------------

    string        executed_op;   // Mnemónico ejecutado, ej "ADD", "LW", "BEQ", "JAL"
    logic [4:0]   rs1_val;       // Índice del registro fuente 1
    logic [4:0]   rs2_val;       // Índice del registro fuente 2
    logic [31:0]  imm_val;       // Inmediato decodificado (según tipo de instrucción)
    bit   [6:0]   opcode_val;    // Campo opcode[6:0] de la instrucción

    //-------------------------------------------------------------------
    // Resultado esperado en registros (salida del modelo de referencia)
    //-------------------------------------------------------------------

    // Valor esperado a escribir en el registro destino.
    // Válido solo si la instrucción escribe rd (R, I, U, J, JALR, loads).
    // Para stores y branches este campo se fuerza a 0 y NO debe compararse.
    logic [31:0] expected_result;

    // Índice del registro destino (rd) de la instrucción.
    logic [4:0]  expected_rd;

    // 1 si esta instrucción escribe un registro destino real (R, I-ALU,
    // LOAD, LUI, AUIPC, JAL, JALR). 0 para STORE y BRANCH: en esos formatos
    // instruction[11:7] es en realidad parte del inmediato (imm_s/imm_b),
    // NO un índice de registro, así que el checker NO debe compararlo
    // contra expected_result/expected_rd.
    bit writes_rd;

    //-------------------------------------------------------------------
    // Control de flujo (salida del modelo de referencia)
    //-------------------------------------------------------------------

    // PC esperado tras ejecutar esta instrucción:
    //   - pc + 4                  -> caso por defecto (R, I, U, S, load)
    //   - pc + imm_b (si taken)   -> branches tomados
    //   - pc + 4 (si not taken)   -> branches no tomados
    //   - pc + imm_j              -> JAL
    //   - (rs1 + imm) & ~1        -> JALR
    // El checker debe comparar esto contra el PC real que el DUT
    // presenta en el siguiente ciclo de fetch.
    logic [31:0] expected_next_pc;

    // 1 si la condición del branch se cumplió (solo relevante si
    // opcode_val corresponde a un branch, opcode 7'b1100011).
    // Útil para debug/cobertura; el checker puede apoyarse en este
    // campo para saber si debía comparar expected_next_pc contra
    // pc+4 o contra el target del branch.
    bit branch_taken;

    //-------------------------------------------------------------------
    // Memoria (salida del modelo de referencia)
    //-------------------------------------------------------------------

    // 1 si esta instrucción es un STORE. Si es 1, el checker debe
    // comparar (mem_addr, mem_wdata, mem_size) contra la escritura
    // observada en la interfaz de memoria del DUT, y NO debe comparar
    // expected_result/expected_rd (los stores no escriben rd).
    bit mem_we;

    // 1 si esta instrucción es un LOAD (LW). Si es 1, el checker debe
    // comparar expected_result/expected_rd (la palabra leída de memoria)
    // contra lo que el DUT escribe en el registro destino.
    bit mem_re;

    // Dirección efectiva de memoria (rs1 + immediato), válida
    // únicamente cuando mem_we=1 o mem_re=1.
    logic [31:0] mem_addr;

    // Dato a escribir en memoria, válido únicamente cuando mem_we=1.
    logic [31:0] mem_wdata;

    // Tamaño del acceso a memoria en BYTES. Siempre 4 (word), ya que
    // el plan solo requiere LW/SW. Válido cuando mem_we=1 o mem_re=1.
    int mem_size;

    function new(string name = "analysis_item");
        super.new(name);
    endfunction

    //-------------------------------------------------------------------
    // convert2string
    //
    // Representación en texto de la transacción completa, pensada para
    // depuración (uvm_info / $display) sin tener que repetir manualmente
    // todos los campos en cada punto de log del scoreboard/checker.
    //-------------------------------------------------------------------
    function string convert2string();
        return $sformatf(
            "op=%-6s pc=%08h instr=%08h | rd=%0d writes_rd=%0b rs1=%0d rs2=%0d imm=%08h | result=%08h next_pc=%08h | mem_we=%0b mem_re=%0b addr=%08h wdata=%08h size=%0d | branch_taken=%0b",
            executed_op, pc, instruction, expected_rd, writes_rd, rs1_val, rs2_val, imm_val,
            expected_result, expected_next_pc, mem_we, mem_re, mem_addr, mem_wdata,
            mem_size, branch_taken
        );
    endfunction

endclass