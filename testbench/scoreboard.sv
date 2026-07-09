//=============================================================================
// Clase: riscv_scoreboard
//
// Descripción:
//   Modelo de referencia (golden model) + buffer de pipeline para el core
//   RISC-V RV32I. Recibe transacciones (analysis_item) del monitor a través
//   de analysis_export, calcula el resultado esperado de cada instrucción
//   en ref_model(), y reenvía la transacción ya resuelta al checker a
//   través de checker_port, con un retardo de PIPELINE_DELAY instrucciones
//   para compensar la latencia del pipeline del DUT.
//
// Instrucciones soportadas actualmente:
//   - Tipo R   : ADD, SUB, AND, OR, XOR, SLL, SRL, SRA, SLT, SLTU
//   - Tipo I   : ADDI, SLTI, SLTIU, XORI, ORI, ANDI, SLLI, SRLI, SRAI
//   - Tipo U   : LUI
//   - Loads    : LB, LH, LW, LBU, LHU
//   - Tipo S   : SB, SH, SW
//   - Tipo B   : BEQ, BNE, BLT, BGE, BLTU, BGEU
//   - JAL, JALR
//
// SUPUESTOS / PRECONDICIONES:
//   1. El monitor entrega las transacciones EN ORDEN DE PROGRAMA (sin
//      instrucciones especulativas ni squasheadas). La memoria shadow
//      (mem[]) y el banco de registros (regf[]) de este modelo se
//      desincronizan si esto no se cumple.
//   2. t.pc debe venir poblado por el monitor (ver contrato en
//      analysis_item.sv).
//   3. No se modela detección de excepciones (alineación de memoria,
//      instrucción ilegal, etc.) — instrucciones no reconocidas producen
//      result = 32'hDEADBEEF y executed_op indicando "no soportada".
//
// CONTRATO DE SALIDA HACIA EL CHECKER (ver también analysis_item.sv):
//   - Si mem_we=1        -> comparar mem_addr/mem_wdata/mem_size, NO rd
//   - Si mem_re=1        -> comparar expected_rd/expected_result (dato leído)
//   - Si opcode es branch -> NO comparar rd, comparar expected_next_pc
//   - En cualquier otro caso -> comparar expected_rd/expected_result y
//     expected_next_pc (debe ser pc+4)
//=============================================================================
class riscv_scoreboard extends uvm_scoreboard;

    `uvm_component_utils(riscv_scoreboard)

    uvm_analysis_imp #(analysis_item, riscv_scoreboard) analysis_export;
    uvm_analysis_port #(analysis_item)                  checker_port;

    // Estado interno del modelo (persiste entre instrucciones)
    logic [31:0] result;
    logic [4:0]  rd;
    logic [4:0]  rs1;
    logic [4:0]  rs2;
    logic [31:0] instruction;
    logic [31:0] regf [15:0];   // Banco de registros shadow (16 registros)

    // Memoria shadow, usada por loads/stores.
    // Ajustar la profundidad al mapa de memoria real del DUT.
    logic [31:0] mem [0:16383];

    // Buffer para compensar el desfase de pipeline antes de enviar al checker
    analysis_item pending_queue[$];

    localparam int PIPELINE_DELAY = 2; // número de instrucciones almacenadas en el buffer

    function new(string name = "riscv_scoreboard", uvm_component parent = null);
        super.new(name, parent);
        analysis_export = new("analysis_export", this);
        checker_port    = new("checker_port", this);
    endfunction

    function void build_phase(uvm_phase phase);
        result = 0;
        rd     = 0;
        rs1    = 0;
        rs2    = 0;
        for (int i = 0; i < 16; i++)
            regf[i] = 0;
        // No se inicializa mem[] explícitamente por tamaño; se asume 0
        // por defecto en simulación. Si el DUT arranca con memoria
        // precargada, este modelo debe recibir la misma carga inicial
        // (pendiente de definir mecanismo con el equipo de memoria).
    endfunction

    //-------------------------------------------------------------------
    // write
    //
    // Callback de uvm_analysis_imp. Punto de entrada de cada transacción
    // proveniente del monitor. Ejecuta el modelo de referencia y gestiona
    // el buffer de retardo de pipeline antes de reenviar al checker.
    //-------------------------------------------------------------------
    virtual function void write(analysis_item t);
        analysis_item to_send;

        instruction = t.instruction;
        ref_model(t);  // calcula todos los campos expected_/mem_/next_pc sobre t

        pending_queue.push_back(t);

        // No se envía nada al checker hasta llenar el buffer de retardo
        if (pending_queue.size() <= PIPELINE_DELAY) begin
            return;
        end

        to_send = pending_queue.pop_front();

        `uvm_info(get_type_name(),
                  $sformatf("Procesando instruccion %08h", to_send.instruction),
                  UVM_MEDIUM)
        `uvm_info(get_type_name(), to_send.convert2string(), UVM_MEDIUM)

        checker_port.write(to_send);
    endfunction

    //-------------------------------------------------------------------
    // ref_model
    //
    // Modelo de referencia funcional. Decodifica la instrucción actual,
    // actualiza el estado interno (regf[], mem[]) y escribe en la
    // transacción 't' todos los campos que el checker necesita comparar
    // contra el DUT (expected_result, expected_rd, expected_next_pc,
    // mem_we/mem_re/mem_addr/mem_wdata/mem_size, branch_taken).
    //-------------------------------------------------------------------
    function void ref_model(analysis_item t);
        bit [6:0] opcode;
        bit [2:0] funct3;
        bit [6:0] funct7;

        logic signed [31:0] imm_i, imm_s, imm_b, imm_j;
        logic [31:0] mem_addr;
        logic        branch_cond;
        logic [31:0] next_pc;
        logic [31:0] jalr_target;

        opcode = instruction[6:0];
        funct3 = instruction[14:12];
        funct7 = instruction[31:25];

        rs1 = instruction[19:15];
        rs2 = instruction[24:20];
        rd  = instruction[11:7];

        // Decodificación de todos los formatos de inmediato posibles.
        // Cada rama del case usa únicamente el que le corresponde.
        imm_i = {{20{instruction[31]}}, instruction[31:20]};
        imm_s = {{20{instruction[31]}}, instruction[31:25], instruction[11:7]};
        imm_b = {{19{instruction[31]}}, instruction[31], instruction[7],
                  instruction[30:25], instruction[11:8], 1'b0};
        imm_j = {{11{instruction[31]}}, instruction[31], instruction[19:12],
                  instruction[20], instruction[30:21], 1'b0};

        // Valores por defecto: se sobreescriben según el tipo de instrucción.
        next_pc        = t.pc + 4;
        t.mem_we       = 0;
        t.mem_re       = 0;
        t.mem_addr     = 0;
        t.mem_wdata    = 0;
        t.mem_size     = 0;
        t.branch_taken = 0;
        result         = 0;

        case (opcode)

            //=============================================================
            // Tipo R (0110011): registro-registro
            //=============================================================
            7'b0110011: begin
                if (rd == 0) begin
                    result = 0;
                    t.executed_op = "RD=0 (ignorada)";
                end else begin
                    case ({funct7, funct3})
                        {7'b0000000, 3'b000}: begin regf[rd] = regf[rs1] + regf[rs2]; t.executed_op = "ADD";  end
                        {7'b0100000, 3'b000}: begin regf[rd] = regf[rs1] - regf[rs2]; t.executed_op = "SUB";  end
                        {7'b0000000, 3'b111}: begin regf[rd] = regf[rs1] & regf[rs2]; t.executed_op = "AND";  end
                        {7'b0000000, 3'b110}: begin regf[rd] = regf[rs1] | regf[rs2]; t.executed_op = "OR";   end
                        {7'b0000000, 3'b100}: begin regf[rd] = regf[rs1] ^ regf[rs2]; t.executed_op = "XOR";  end
                        {7'b0000000, 3'b001}: begin regf[rd] = regf[rs1] << regf[rs2][4:0]; t.executed_op = "SLL"; end
                        {7'b0000000, 3'b101}: begin regf[rd] = regf[rs1] >> regf[rs2][4:0]; t.executed_op = "SRL"; end
                        {7'b0100000, 3'b101}: begin regf[rd] = $signed(regf[rs1]) >>> regf[rs2][4:0]; t.executed_op = "SRA"; end
                        {7'b0000000, 3'b011}: begin regf[rd] = (regf[rs1] < regf[rs2]); t.executed_op = "SLTU"; end
                        {7'b0000000, 3'b010}: begin regf[rd] = ($signed(regf[rs1]) < $signed(regf[rs2])); t.executed_op = "SLT"; end
                        default: begin result = 32'hDEADBEEF; t.executed_op = "R no soportada"; end
                    endcase
                    result = regf[rd];
                end
            end

            //=============================================================
            // Tipo I aritmético (0010011): registro-inmediato
            //=============================================================
            7'b0010011: begin
                if (rd == 0) begin
                    result = 0;
                    t.executed_op = "RD=0 (ignorada)";
                end else begin
                    case (funct3)
                        3'b000: begin regf[rd] = regf[rs1] + imm_i; t.executed_op = "ADDI"; end
                        3'b010: begin regf[rd] = ($signed(regf[rs1]) < $signed(imm_i)); t.executed_op = "SLTI"; end
                        3'b011: begin regf[rd] = ($unsigned(regf[rs1]) < $unsigned(imm_i)); t.executed_op = "SLTIU"; end
                        3'b100: begin regf[rd] = regf[rs1] ^ imm_i; t.executed_op = "XORI"; end
                        3'b110: begin regf[rd] = regf[rs1] | imm_i; t.executed_op = "ORI";  end
                        3'b111: begin regf[rd] = regf[rs1] & imm_i; t.executed_op = "ANDI"; end
                        3'b001: begin regf[rd] = regf[rs1] << imm_i[4:0]; t.executed_op = "SLLI"; end
                        3'b101: begin
                            if (funct7 == 7'b0100000) begin
                                regf[rd] = $signed(regf[rs1]) >>> imm_i[4:0];
                                t.executed_op = "SRAI";
                            end else begin
                                regf[rd] = regf[rs1] >> imm_i[4:0];
                                t.executed_op = "SRLI";
                            end
                        end
                        default: begin result = 32'hDEADBEEF; t.executed_op = "I no soportada"; end
                    endcase
                    result = regf[rd];
                end
            end

            //=============================================================
            // Tipo U (0110111): LUI
            //=============================================================
            7'b0110111: begin
                if (rd == 0) begin
                    result = 0;
                    t.executed_op = "RD=0 (ignorada)";
                end else begin
                    regf[rd] = {instruction[31:12], 12'b0};
                    result   = regf[rd];
                    t.executed_op = "LUI";
                end
            end

            //=============================================================
            // LOAD (0000011): LB, LH, LW, LBU, LHU
            // Dirección efectiva = regf[rs1] + imm_i
            //=============================================================
            7'b0000011: begin
                mem_addr = regf[rs1] + imm_i;

                case (funct3)
                    3'b000: begin result = {{24{mem[mem_addr][7]}},  mem[mem_addr][7:0]};  t.executed_op = "LB";  end // sign-extend byte
                    3'b001: begin result = {{16{mem[mem_addr][15]}}, mem[mem_addr][15:0]}; t.executed_op = "LH";  end // sign-extend half
                    3'b010: begin result = mem[mem_addr];                                  t.executed_op = "LW";  end
                    3'b100: begin result = {24'b0, mem[mem_addr][7:0]};                     t.executed_op = "LBU"; end // zero-extend byte
                    3'b101: begin result = {16'b0, mem[mem_addr][15:0]};                    t.executed_op = "LHU"; end // zero-extend half
                    default: begin result = 32'hDEADBEEF; t.executed_op = "LOAD no soportada"; end
                endcase

                if (rd != 0) regf[rd] = result;
                else         result   = 0;

                t.mem_re   = 1;
                t.mem_addr = mem_addr;
            end

            //=============================================================
            // Tipo S (0100011): SB, SH, SW
            // Dirección efectiva = regf[rs1] + imm_s. No escribe rd.
            //=============================================================
            7'b0100011: begin
                mem_addr = regf[rs1] + imm_s;

                case (funct3)
                    3'b000: begin
                        mem[mem_addr][7:0] = regf[rs2][7:0];
                        t.executed_op = "SB";
                        t.mem_size    = 1;
                        t.mem_wdata   = {24'b0, regf[rs2][7:0]};
                    end
                    3'b001: begin
                        mem[mem_addr][15:0] = regf[rs2][15:0];
                        t.executed_op = "SH";
                        t.mem_size    = 2;
                        t.mem_wdata   = {16'b0, regf[rs2][15:0]};
                    end
                    3'b010: begin
                        mem[mem_addr] = regf[rs2];
                        t.executed_op = "SW";
                        t.mem_size    = 4;
                        t.mem_wdata   = regf[rs2];
                    end
                    default: t.executed_op = "STORE no soportada";
                endcase

                t.mem_we   = 1;
                t.mem_addr = mem_addr;
                result     = 0; // los stores no escriben rd
            end

            //=============================================================
            // Tipo B (1100011): BEQ, BNE, BLT, BGE, BLTU, BGEU
            // No escribe rd. Modifica next_pc si la condición se cumple.
            //=============================================================
            7'b1100011: begin
                case (funct3)
                    3'b000: begin branch_cond = (regf[rs1] == regf[rs2]); t.executed_op = "BEQ";  end
                    3'b001: begin branch_cond = (regf[rs1] != regf[rs2]); t.executed_op = "BNE";  end
                    3'b100: begin branch_cond = ($signed(regf[rs1]) <  $signed(regf[rs2])); t.executed_op = "BLT";  end
                    3'b101: begin branch_cond = ($signed(regf[rs1]) >= $signed(regf[rs2])); t.executed_op = "BGE";  end
                    3'b110: begin branch_cond = (regf[rs1] <  regf[rs2]); t.executed_op = "BLTU"; end
                    3'b111: begin branch_cond = (regf[rs1] >= regf[rs2]); t.executed_op = "BGEU"; end
                    default: begin branch_cond = 0; t.executed_op = "BRANCH no soportada"; end
                endcase

                if (branch_cond) next_pc = t.pc + imm_b;
                t.branch_taken = branch_cond;
                result = 0; // los branches no escriben rd
            end

            //=============================================================
            // JAL (1101111): rd = pc+4, salto incondicional a pc+imm_j
            //=============================================================
            7'b1101111: begin
                if (rd != 0) regf[rd] = t.pc + 4;
                result        = t.pc + 4;
                next_pc       = t.pc + imm_j;
                t.executed_op = "JAL";
            end

            //=============================================================
            // JALR (1100111): rd = pc+4, salto a (rs1+imm) con bit0 a 0
            //=============================================================
            7'b1100111: begin
                jalr_target = (regf[rs1] + imm_i) & ~32'b1;
                if (rd != 0) regf[rd] = t.pc + 4;
                result        = t.pc + 4;
                next_pc       = jalr_target;
                t.executed_op = "JALR";
            end

            //=============================================================
            // Opcode no reconocido
            //=============================================================
            default: begin
                result        = 32'hDEADBEEF;
                t.executed_op = "instruccion no soportada por el modelo de referencia";
            end
        endcase

        // Campos comunes que se guardan siempre, independientemente
        // del tipo de instrucción, para que el checker/logging los use.
        t.expected_result  = result;
        t.expected_rd      = rd;
        t.rs1_val          = rs1;
        t.rs2_val          = rs2;
        t.opcode_val       = opcode;
        t.expected_next_pc = next_pc;

        // imm_val guarda el inmediato relevante según el tipo de
        // instrucción, para que quede reflejado en el log/debug.
        case (opcode)
            7'b0010011, 7'b0000011, 7'b1100111: t.imm_val = imm_i; // I-type / load / JALR
            7'b0100011:                         t.imm_val = imm_s; // S-type
            7'b1100011:                         t.imm_val = imm_b; // B-type
            7'b1101111:                         t.imm_val = imm_j; // J-type
            7'b0110111:                         t.imm_val = {instruction[31:12], 12'b0}; // U-type
            default:                            t.imm_val = 0;
        endcase

    endfunction

endclass
