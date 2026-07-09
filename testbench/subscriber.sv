class riscv_subscriber extends uvm_subscriber #(analysis_item);
  `uvm_component_utils(riscv_subscriber)

  analysis_item tr;

  bit [4:0] rs1, rs2, rd;
  bit [2:0] funct3;
  bit [6:0] funct7;
  bit [6:0] opcode;

  bit is_shift;
  bit is_logic;
  bit is_arithmetic;

  // Grupo de cobertura
  covergroup instruction_cg;

    // Permite ver cobertura por instancia del covergroup
    option.per_instance = 1;

    // Permite obtener cobertura de cada instancia
    option.get_inst_coverage = 1;

    cp_rs1 : coverpoint rs1 {
      option.comment = "Bins de registros RS1";
      bins bajos[] = {[0:15]};
    }

    cp_rs2 : coverpoint rs2 {
      option.comment = "Bins de registros RS2";
      bins bajos[] = {[0:15]};
    }

    cp_rd : coverpoint rd {
      option.comment = "Bins de registro destino RD";
      bins bajos[] = {[0:15]};
    }

    cp_funct3 : coverpoint funct3 {
      option.comment = "Codificación funct3";
    }

    cp_funct7 : coverpoint funct7 {
      option.comment = "Codificación funct7";
      bins normal = {7'b0000000};
      bins alterna = {7'b0100000};
    }

    cp_opcode : coverpoint opcode {
      option.comment = "Tipos de opcode";
      bins r_tipo = {7'b0110011};
      bins i_tipo = {7'b0010011};
      bins lui    = {7'b0110111};
      bins auipc  = {7'b0010111};
      bins load   = {7'b0000011};
      bins store  = {7'b0100011};
      bins branch = {7'b1100011};
      bins jal    = {7'b1101111};
      bins jalr   = {7'b1100111};
    }

    // Solo tiene sentido cuando opcode==BRANCH (1100011): las 6 condiciones
    // de salto codificadas en funct3.
    cp_branch_cond : coverpoint funct3 iff (opcode == 7'b1100011) {
      option.comment = "Condicion de branch cubierta";
      bins beq  = {3'b000};
      bins bne  = {3'b001};
      bins blt  = {3'b100};
      bins bge  = {3'b101};
      bins bltu = {3'b110};
      bins bgeu = {3'b111};
    }

    cp_shift : coverpoint is_shift {
      option.comment = "Clasificación shift";
      bins no  = {0};
      bins si  = {1};
    }

    cp_logico : coverpoint is_logic {
      option.comment = "Clasificación lógica";
      bins no  = {0};
      bins si  = {1};
    }

    cp_aritmetico : coverpoint is_arithmetic {
      option.comment = "Clasificación aritmética";
      bins no  = {0};
      bins si  = {1};
    }

    // Cobertura cruzada de funct3 y funct7
    cross_funct : cross cp_funct3, cp_funct7 {
      option.comment = "Cruzamiento funct3 x funct7";
    }

    // Dependencia de registros
    cross_regs : cross cp_rs1, cp_rs2 {
      option.comment = "Cruzamiento de registros RS1 y RS2";
    }

    // Relación opcode vs funct3
    cross_opcode_funct3 : cross cp_opcode, cp_funct3 {
      option.comment = "Cruzamiento opcode vs funct3";
    }

  endgroup

  function new(string name = "riscv_subscriber", uvm_component parent = null);
    super.new(name, parent);
    instruction_cg = new();
  endfunction

  virtual function void write(analysis_item t);

    tr = t;

    // Decodificación de la instrucción
    opcode = t.instruction[6:0];
    rd     = t.instruction[11:7];
    funct3 = t.instruction[14:12];
    rs1    = t.instruction[19:15];
    rs2    = t.instruction[24:20];
    funct7 = t.instruction[31:25];

    // Inicialización de clasificación
    is_shift = 0;
    is_logic = 0;
    is_arithmetic = 0;

    // Clasificación válida solo para tipo R
    if (opcode == 7'b0110011) begin
      case ({funct7, funct3})

        // Operaciones de shift
        {7'b0000000,3'b001},
        {7'b0000000,3'b101},
        {7'b0100000,3'b101}:
          is_shift = 1;

        // Operaciones lógicas
        {7'b0000000,3'b111},
        {7'b0000000,3'b110},
        {7'b0000000,3'b100}:
          is_logic = 1;

        // Operaciones aritméticas
        {7'b0000000,3'b000},
        {7'b0100000,3'b000},
        {7'b0000000,3'b010},
        {7'b0000000,3'b011}:
          is_arithmetic = 1;

      endcase
    end

    // Muestreo del covergroup
    instruction_cg.sample();

    // Validación de registros. instruction[11:7] solo es un indice de
    // registro real cuando la instruccion escribe rd; en STORE (0100011) y
    // BRANCH (1100011) esos mismos bits son parte del inmediato
    // (imm_s[4:0] / imm_b[4:1|11]) y pueden exceder 15 legitimamente.
    if (opcode != 7'b0100011 && opcode != 7'b1100011)
      assert(rd < 16)
        else `uvm_error(get_type_name(), $sformatf("RD inválido: %0d", rd))

    if (opcode == 7'b0110011 || opcode == 7'b0010011)
      assert(rs1 < 16)
        else `uvm_error(get_type_name(), $sformatf("RS1 inválido: %0d", rs1))

    if (opcode == 7'b0110011)
      assert(rs2 < 16)
        else `uvm_error(get_type_name(), $sformatf("RS2 inválido: %0d", rs2))

    `uvm_info(get_type_name(), $sformatf("Cobertura muestreada para instrucción: %08h", t.instruction), UVM_HIGH)

  endfunction

  function void report_phase(uvm_phase phase);

    real cov;

    // Cobertura total del covergroup
    cov = instruction_cg.get_coverage();

    `uvm_info(get_type_name(), $sformatf("Cobertura total del covergroup = %0.2f%%", cov), UVM_NONE)

    `uvm_info(get_type_name(), $sformatf("Cobertura RS1 = %0.2f%%", instruction_cg.cp_rs1.get_coverage()), UVM_NONE)

    `uvm_info(get_type_name(), $sformatf("Cobertura RS2 = %0.2f%%", instruction_cg.cp_rs2.get_coverage()), UVM_NONE)

    `uvm_info(get_type_name(), $sformatf("Cobertura RD  = %0.2f%%", instruction_cg.cp_rd.get_coverage()), UVM_NONE)

    `uvm_info(get_type_name(), $sformatf("Cobertura OPCODE = %0.2f%%", instruction_cg.cp_opcode.get_coverage()), UVM_NONE)

    `uvm_info(get_type_name(), $sformatf("Cobertura condicion de BRANCH = %0.2f%%", instruction_cg.cp_branch_cond.get_coverage()), UVM_NONE)

  endfunction

endclass
