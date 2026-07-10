//=============================================================================
// Clase: riscv_subscriber
//
// Cobertura funcional del plan de verificacion: un covergroup POR FUNCION
// (R, I, U, LOAD, STORE, BRANCH, JUMP), cada uno con 6 puntos de cobertura
// y 3 cruces, como exige la rubrica del tercer avance. El test de
// instrucciones mixtas llena todos los covergroups a la vez.
//
// El subscriber recibe la transaccion YA RESUELTA por el modelo de
// referencia (se conecta a scoreboard.checker_port en env.sv, no al
// monitor), por lo que ademas de los campos de la instruccion puede
// muestrear datos dinamicos: branch tomado/no tomado, signo del resultado,
// direccion efectiva de memoria, dato leido/escrito y PC destino de saltos.
//
// Codificacion de signos usada por varios coverpoints:
//   0 = cero, 1 = positivo (bit31=0 y != 0), 2 = negativo (bit31=1)
//=============================================================================
class riscv_subscriber extends uvm_subscriber #(analysis_item);
  `uvm_component_utils(riscv_subscriber)

  //-------------------------------------------------------------------
  // Campos decodificados de la instruccion (comunes a varios covergroups)
  //-------------------------------------------------------------------
  bit [4:0] rs1, rs2, rd;
  bit [2:0] funct3;
  bit [6:0] funct7;
  bit [6:0] opcode;

  // Operacion especifica, decodificada a un indice de bin
  int r_op;   // 0=ADD 1=SUB 2=SLL 3=SLT 4=SLTU 5=XOR 6=SRL 7=SRA 8=OR 9=AND
  int r_clase;// 0=aritmetica(ADD,SUB,SLT,SLTU) 1=logica(XOR,OR,AND) 2=shift(SLL,SRL,SRA)
  int i_op;   // 0=ADDI 1=SLTI 2=SLTIU 3=XORI 4=ORI 5=ANDI 6=SLLI 7=SRLI 8=SRAI
  bit u_op;   // 0=LUI 1=AUIPC
  bit j_op;   // 0=JAL 1=JALR

  // Inmediatos decodificados de la instruccion
  bit [11:0] imm_i_raw;   // campo crudo de 12 bits (tipo I / LOAD)
  bit [11:0] imm_s_raw;   // campo crudo de 12 bits (STORE)
  bit [4:0]  shamt;       // cantidad de shift (SLLI/SRLI/SRAI)
  bit [12:0] imm_b;       // offset de branch (el estimulo lo acota a [4:32])
  bit [19:0] imm_u;       // inmediato superior (LUI/AUIPC)
  int        jump_offset; // offset de JAL (imm_j) o de JALR (imm_i)

  // Datos dinamicos provenientes del modelo de referencia
  int result_sign;    // signo de expected_result
  bit imm_neg;        // 1 si el offset/inmediato de 12 bits es negativo
  int data_sign;      // signo del dato leido (LOAD) o escrito (STORE)
  bit taken;          // branch tomado
  bit same_reg;       // rs1 == rs2 (interesante en BEQ/BGE: siempre se toman)
  bit [9:0]    mem_word; // indice de palabra de la direccion efectiva (memoria de 1024 palabras)
  logic [31:0] pc;
  logic [31:0] target;   // destino del salto (expected_next_pc)

  //-------------------------------------------------------------------
  // Funcion R: 6 coverpoints + 3 cruces
  //-------------------------------------------------------------------
  covergroup cg_r;
    option.per_instance = 1;
    option.get_inst_coverage = 1;
    option.comment = "Funcion R: ADD,SUB,SLL,SLT,SLTU,XOR,SRL,SRA,OR,AND";

    cp_op : coverpoint r_op {
      option.comment = "Las 10 operaciones tipo R";
      bins add  = {0}; bins sub  = {1}; bins sll = {2}; bins slt = {3};
      bins sltu = {4}; bins xor_ = {5}; bins srl = {6}; bins sra = {7};
      bins or_  = {8}; bins and_ = {9};
    }
    // rd=0 esta prohibido por constraint en el estimulo (escrituras a x0 se descartan)
    cp_rd : coverpoint rd {
      option.comment = "Registro destino";
      bins regs[] = {[1:15]};
    }
    cp_rs1 : coverpoint rs1 {
      option.comment = "Primer operando fuente";
      bins regs[] = {[0:15]};
    }
    cp_rs2 : coverpoint rs2 {
      option.comment = "Segundo operando fuente";
      bins regs[] = {[0:15]};
    }
    cp_result : coverpoint result_sign {
      option.comment = "Signo del resultado calculado";
      bins cero = {0}; bins positivo = {1}; bins negativo = {2};
    }
    cp_clase : coverpoint r_clase {
      option.comment = "Clasificacion de la operacion";
      bins aritmetica = {0}; bins logica = {1}; bins shift = {2};
    }

    cx_op_result : cross cp_op, cp_result {
      option.comment = "Cada operacion R con cada signo de resultado";
    }
    cx_regs : cross cp_rs1, cp_rs2 {
      option.comment = "Combinaciones de operandos fuente";
    }
    cx_op_rd : cross cp_op, cp_rd {
      option.comment = "Cada operacion R escribiendo cada registro";
    }
  endgroup

  //-------------------------------------------------------------------
  // Funcion I: 6 coverpoints + 3 cruces
  //-------------------------------------------------------------------
  covergroup cg_i;
    option.per_instance = 1;
    option.get_inst_coverage = 1;
    option.comment = "Funcion I: ADDI,SLTI,SLTIU,XORI,ORI,ANDI,SLLI,SRLI,SRAI";

    cp_op : coverpoint i_op {
      option.comment = "Las 9 operaciones tipo I (SRLI/SRAI separadas por instruction[30])";
      bins addi = {0}; bins slti = {1}; bins sltiu = {2}; bins xori = {3};
      bins ori  = {4}; bins andi = {5}; bins slli  = {6}; bins srli = {7};
      bins srai = {8};
    }
    cp_rd : coverpoint rd {
      option.comment = "Registro destino";
      bins regs[] = {[1:15]};
    }
    cp_rs1 : coverpoint rs1 {
      option.comment = "Registro fuente";
      bins regs[] = {[0:15]};
    }
    cp_imm_sign : coverpoint imm_neg {
      option.comment = "Signo del inmediato de 12 bits";
      bins positivo_o_cero = {0}; bins negativo = {1};
    }
    // Solo tiene sentido en shifts; en las demas operaciones I los bits
    // [24:20] son parte del inmediato, no un shamt
    cp_shamt : coverpoint shamt iff (i_op inside {6, 7, 8}) {
      option.comment = "Cantidad de desplazamiento en SLLI/SRLI/SRAI";
      bins cero = {0}; bins bajo = {[1:15]}; bins alto = {[16:30]}; bins maximo = {31};
    }
    cp_result : coverpoint result_sign {
      option.comment = "Signo del resultado calculado";
      bins cero = {0}; bins positivo = {1}; bins negativo = {2};
    }

    cx_op_imm : cross cp_op, cp_imm_sign {
      option.comment = "Cada operacion I con inmediato positivo y negativo";
      // En los shifts el campo inmediato lleva funct7+shamt: su "signo" esta
      // fijado por la codificacion (SLLI/SRLI siempre 0, SRAI siempre
      // 0100000_xxxxx), no es un caso ejercitable
      ignore_bins shifts = binsof(cp_op) intersect {6, 7, 8};
    }
    cx_op_rd : cross cp_op, cp_rd {
      option.comment = "Cada operacion I escribiendo cada registro";
    }
    cx_rs1_rd : cross cp_rs1, cp_rd {
      option.comment = "Combinaciones fuente-destino (incluye rs1==rd, read-modify-write)";
    }
  endgroup

  //-------------------------------------------------------------------
  // Funcion U: 6 coverpoints + 3 cruces
  //-------------------------------------------------------------------
  covergroup cg_u;
    option.per_instance = 1;
    option.get_inst_coverage = 1;
    option.comment = "Funcion U: LUI, AUIPC";

    cp_op : coverpoint u_op {
      option.comment = "Instruccion de inmediato superior";
      bins lui = {0}; bins auipc = {1};
    }
    cp_rd : coverpoint rd {
      option.comment = "Registro destino";
      bins regs[] = {[1:15]};
    }
    // El bin cero solo lo llena el AUIPC imm=0 de la pareja AUIPC+JALR
    // (tests de jump/mixto); en LUI el estimulo prohibe imm_u==0
    cp_imm : coverpoint imm_u {
      option.comment = "Rangos del inmediato superior de 20 bits";
      bins cero  = {0};
      bins bajo  = {[20'h00001:20'h3FFFF]};
      bins medio = {[20'h40000:20'hBFFFF]};
      bins alto  = {[20'hC0000:20'hFFFFF]};
    }
    cp_imm_msb : coverpoint imm_u[19] {
      option.comment = "Bit 19 del inmediato: signo del valor de 32 bits resultante";
      bins resultado_positivo = {0}; bins resultado_negativo = {1};
    }
    cp_result : coverpoint result_sign {
      option.comment = "Signo del resultado calculado";
      bins cero = {0}; bins positivo = {1}; bins negativo = {2};
    }
    cp_pc : coverpoint pc {
      option.comment = "Region del programa donde se ejecuta (relevante para AUIPC)";
      bins inicio = {[0:255]}; bins medio = {[256:1023]}; bins final_ = {[1024:$]};
    }

    cx_op_msb : cross cp_op, cp_imm_msb {
      option.comment = "LUI/AUIPC con inmediato que produce valor positivo y negativo";
    }
    cx_op_rd : cross cp_op, cp_rd {
      option.comment = "LUI/AUIPC escribiendo cada registro";
    }
    cx_op_result : cross cp_op, cp_result {
      option.comment = "LUI/AUIPC con cada signo de resultado";
    }
  endgroup

  //-------------------------------------------------------------------
  // Funcion LOAD (LW): 6 coverpoints + 3 cruces
  //-------------------------------------------------------------------
  covergroup cg_load;
    option.per_instance = 1;
    option.get_inst_coverage = 1;
    option.comment = "Funcion LOAD: LW";

    cp_rd : coverpoint rd {
      option.comment = "Registro destino del dato leido";
      bins regs[] = {[1:15]};
    }
    cp_rs1 : coverpoint rs1 {
      option.comment = "Registro base de la direccion";
      bins regs[] = {[0:15]};
    }
    cp_offset_sign : coverpoint imm_neg {
      option.comment = "Signo del offset imm_i";
      bins positivo_o_cero = {0}; bins negativo = {1};
    }
    cp_addr : coverpoint mem_word {
      option.comment = "Cuartos de la memoria de datos (1024 palabras) accedidos";
      bins q1 = {[0:255]}; bins q2 = {[256:511]};
      bins q3 = {[512:767]}; bins q4 = {[768:1023]};
    }
    // En el test dirigido de solo-LOAD la memoria conserva su contenido
    // inicial (mayormente 0): positivo/negativo se llenan en el test mixto,
    // donde hay stores previos. Justificacion esperada de <100% por test.
    cp_data : coverpoint data_sign {
      option.comment = "Signo del dato leido de memoria";
      bins cero = {0}; bins positivo = {1}; bins negativo = {2};
    }
    cp_offset_mag : coverpoint imm_i_raw {
      option.comment = "Cuadrantes del offset de 12 bits (positivos y negativos)";
      bins pos_bajo   = {[12'h000:12'h3FF]};
      bins pos_alto   = {[12'h400:12'h7FF]};
      bins neg_lejano = {[12'h800:12'hBFF]};
      bins neg_cercano= {[12'hC00:12'hFFF]};
    }

    cx_rs1_offset : cross cp_rs1, cp_offset_sign {
      option.comment = "Cada registro base con offset positivo y negativo";
    }
    cx_addr_data : cross cp_addr, cp_data {
      option.comment = "Cada region de memoria con cada signo de dato leido";
    }
    cx_rd_addr : cross cp_rd, cp_addr {
      option.comment = "Cada registro destino cargado desde cada region";
    }
  endgroup

  //-------------------------------------------------------------------
  // Funcion STORE (SW): 6 coverpoints + 3 cruces
  //-------------------------------------------------------------------
  covergroup cg_store;
    option.per_instance = 1;
    option.get_inst_coverage = 1;
    option.comment = "Funcion STORE: SW";

    cp_rs1 : coverpoint rs1 {
      option.comment = "Registro base de la direccion";
      bins regs[] = {[0:15]};
    }
    cp_rs2 : coverpoint rs2 {
      option.comment = "Registro con el dato a escribir";
      bins regs[] = {[0:15]};
    }
    cp_offset_sign : coverpoint imm_neg {
      option.comment = "Signo del offset imm_s";
      bins positivo_o_cero = {0}; bins negativo = {1};
    }
    cp_addr : coverpoint mem_word {
      option.comment = "Cuartos de la memoria de datos (1024 palabras) escritos";
      bins q1 = {[0:255]}; bins q2 = {[256:511]};
      bins q3 = {[512:767]}; bins q4 = {[768:1023]};
    }
    // En el test dirigido de solo-STORE los registros conservan su valor
    // inicial (mayormente 0): positivo/negativo se llenan en el test mixto
    cp_data : coverpoint data_sign {
      option.comment = "Signo del dato escrito en memoria";
      bins cero = {0}; bins positivo = {1}; bins negativo = {2};
    }
    cp_offset_mag : coverpoint imm_s_raw {
      option.comment = "Cuadrantes del offset de 12 bits (positivos y negativos)";
      bins pos_bajo   = {[12'h000:12'h3FF]};
      bins pos_alto   = {[12'h400:12'h7FF]};
      bins neg_lejano = {[12'h800:12'hBFF]};
      bins neg_cercano= {[12'hC00:12'hFFF]};
    }

    cx_regs : cross cp_rs1, cp_rs2 {
      option.comment = "Combinaciones base-dato (incluye rs1==rs2)";
    }
    cx_addr_data : cross cp_addr, cp_data {
      option.comment = "Cada region de memoria con cada signo de dato escrito";
    }
    cx_offset_addr : cross cp_offset_sign, cp_addr {
      option.comment = "Signo del offset contra region efectiva alcanzada (wraparound)";
    }
  endgroup

  //-------------------------------------------------------------------
  // Funcion BRANCH: 6 coverpoints + 3 cruces
  //-------------------------------------------------------------------
  covergroup cg_branch;
    option.per_instance = 1;
    option.get_inst_coverage = 1;
    option.comment = "Funcion BRANCH: BEQ,BNE,BLT,BGE,BLTU,BGEU";

    cp_cond : coverpoint funct3 {
      option.comment = "Las 6 condiciones de salto";
      bins beq  = {3'b000}; bins bne  = {3'b001};
      bins blt  = {3'b100}; bins bge  = {3'b101};
      bins bltu = {3'b110}; bins bgeu = {3'b111};
    }
    cp_taken : coverpoint taken {
      option.comment = "Resultado de evaluar la condicion";
      bins no_tomado = {0}; bins tomado = {1};
    }
    cp_offset : coverpoint imm_b {
      option.comment = "Magnitud del offset (el estimulo lo acota a [4:32], multiplos de 4)";
      bins minimo = {4}; bins medio = {[8:28]}; bins maximo = {32};
    }
    cp_rs1 : coverpoint rs1 {
      option.comment = "Primer registro comparado";
      bins regs[] = {[0:15]};
    }
    cp_rs2 : coverpoint rs2 {
      option.comment = "Segundo registro comparado";
      bins regs[] = {[0:15]};
    }
    cp_same_reg : coverpoint same_reg {
      option.comment = "Comparacion de un registro consigo mismo (BEQ/BGE/BGEU siempre toman)";
      bins distintos = {0}; bins iguales = {1};
    }

    cx_cond_taken : cross cp_cond, cp_taken {
      option.comment = "Las 12 combinaciones condicion x tomado/no-tomado";
    }
    cx_cond_offset : cross cp_cond, cp_offset {
      option.comment = "Cada condicion con offset minimo/medio/maximo";
    }
    cx_regs : cross cp_rs1, cp_rs2 {
      option.comment = "Combinaciones de registros comparados";
    }
  endgroup

  //-------------------------------------------------------------------
  // Funcion JUMP (JAL/JALR): 6 coverpoints + 3 cruces
  //-------------------------------------------------------------------
  covergroup cg_jump;
    option.per_instance = 1;
    option.get_inst_coverage = 1;
    option.comment = "Funcion JUMP: JAL, JALR";

    cp_op : coverpoint j_op {
      option.comment = "Tipo de salto incondicional";
      bins jal = {0}; bins jalr = {1};
    }
    cp_rd : coverpoint rd {
      option.comment = "Registro de retorno (recibe pc+4)";
      bins regs[] = {[1:15]};
    }
    cp_offset : coverpoint jump_offset {
      option.comment = "Magnitud del offset (JAL en [4:32], JALR en [8:36])";
      bins minimo = {[4:8]}; bins medio = {[12:28]}; bins maximo = {[32:36]};
    }
    // Solo aplica a JALR; la base la deja el AUIPC de la pareja, cuyo rd
    // esta acotado a [1:15]
    cp_rs1 : coverpoint rs1 iff (j_op == 1) {
      option.comment = "Registro base del JALR";
      bins regs[] = {[1:15]};
    }
    cp_pc : coverpoint pc {
      option.comment = "Region del programa donde se origina el salto";
      bins inicio = {[0:255]}; bins medio = {[256:1023]}; bins final_ = {[1024:$]};
    }
    cp_target : coverpoint target {
      option.comment = "Region del programa donde aterriza el salto";
      bins inicio = {[0:255]}; bins medio = {[256:1023]}; bins final_ = {[1024:$]};
    }

    cx_op_rd : cross cp_op, cp_rd {
      option.comment = "JAL/JALR guardando el retorno en cada registro";
    }
    cx_op_offset : cross cp_op, cp_offset {
      option.comment = "JAL/JALR con cada magnitud de offset";
    }
    cx_rd_offset : cross cp_rd, cp_offset {
      option.comment = "Registro de retorno contra magnitud del salto";
    }
  endgroup

  function new(string name = "riscv_subscriber", uvm_component parent = null);
    super.new(name, parent);
    cg_r      = new();
    cg_i      = new();
    cg_u      = new();
    cg_load   = new();
    cg_store  = new();
    cg_branch = new();
    cg_jump   = new();
  endfunction

  // Codificacion de signo comun: 0=cero, 1=positivo, 2=negativo
  function int signo(logic [31:0] v);
    if (v == 0)      return 0;
    else if (v[31])  return 2;
    else             return 1;
  endfunction

  virtual function void write(analysis_item t);

    // Decodificacion de la instruccion
    opcode = t.instruction[6:0];
    rd     = t.instruction[11:7];
    funct3 = t.instruction[14:12];
    rs1    = t.instruction[19:15];
    rs2    = t.instruction[24:20];
    funct7 = t.instruction[31:25];

    imm_i_raw = t.instruction[31:20];
    imm_s_raw = {t.instruction[31:25], t.instruction[11:7]};
    imm_b     = {t.instruction[31], t.instruction[7], t.instruction[30:25],
                 t.instruction[11:8], 1'b0};
    imm_u     = t.instruction[31:12];
    shamt     = t.instruction[24:20];

    // Datos dinamicos resueltos por el modelo de referencia
    pc          = t.pc;
    target      = t.expected_next_pc;
    taken       = t.branch_taken;
    same_reg    = (rs1 == rs2);
    mem_word    = t.mem_addr[11:2];
    result_sign = signo(t.expected_result);

    // Muestreo del covergroup de la funcion correspondiente
    case (opcode)

      // ---- R ----
      7'b0110011: begin
        case ({funct7, funct3})
          {7'b0000000, 3'b000}: begin r_op = 0; r_clase = 0; end // ADD
          {7'b0100000, 3'b000}: begin r_op = 1; r_clase = 0; end // SUB
          {7'b0000000, 3'b001}: begin r_op = 2; r_clase = 2; end // SLL
          {7'b0000000, 3'b010}: begin r_op = 3; r_clase = 0; end // SLT
          {7'b0000000, 3'b011}: begin r_op = 4; r_clase = 0; end // SLTU
          {7'b0000000, 3'b100}: begin r_op = 5; r_clase = 1; end // XOR
          {7'b0000000, 3'b101}: begin r_op = 6; r_clase = 2; end // SRL
          {7'b0100000, 3'b101}: begin r_op = 7; r_clase = 2; end // SRA
          {7'b0000000, 3'b110}: begin r_op = 8; r_clase = 1; end // OR
          {7'b0000000, 3'b111}: begin r_op = 9; r_clase = 1; end // AND
          default:              begin r_op = -1; r_clase = -1; end
        endcase
        if (r_op != -1)
          cg_r.sample();
      end

      // ---- I aritmetico ----
      7'b0010011: begin
        case (funct3)
          3'b000: i_op = 0;                              // ADDI
          3'b010: i_op = 1;                              // SLTI
          3'b011: i_op = 2;                              // SLTIU
          3'b100: i_op = 3;                              // XORI
          3'b110: i_op = 4;                              // ORI
          3'b111: i_op = 5;                              // ANDI
          3'b001: i_op = 6;                              // SLLI
          3'b101: i_op = t.instruction[30] ? 8 : 7;      // SRAI : SRLI
          default: i_op = -1;
        endcase
        imm_neg = imm_i_raw[11];
        if (i_op != -1)
          cg_i.sample();
      end

      // ---- U ----
      7'b0110111, 7'b0010111: begin
        u_op = (opcode == 7'b0010111); // 0=LUI, 1=AUIPC
        cg_u.sample();
      end

      // ---- LOAD (LW) ----
      7'b0000011: begin
        imm_neg   = imm_i_raw[11];
        data_sign = signo(t.expected_result); // dato leido de memoria
        if (funct3 == 3'b010)
          cg_load.sample();
      end

      // ---- STORE (SW) ----
      7'b0100011: begin
        imm_neg   = imm_s_raw[11];
        data_sign = signo(t.mem_wdata); // dato escrito en memoria
        if (funct3 == 3'b010)
          cg_store.sample();
      end

      // ---- BRANCH ----
      7'b1100011: begin
        if (funct3 inside {3'b000, 3'b001, 3'b100, 3'b101, 3'b110, 3'b111})
          cg_branch.sample();
      end

      // ---- JUMP: JAL ----
      7'b1101111: begin
        j_op = 0;
        jump_offset = int'(signed'({{11{t.instruction[31]}}, t.instruction[31],
                                    t.instruction[19:12], t.instruction[20],
                                    t.instruction[30:21], 1'b0}));
        cg_jump.sample();
      end

      // ---- JUMP: JALR ----
      7'b1100111: begin
        j_op = 1;
        jump_offset = int'(signed'(imm_i_raw));
        cg_jump.sample();
      end

      default: ; // opcode fuera del plan: no se muestrea

    endcase

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

    `uvm_info(get_type_name(), "==== Cobertura funcional por funcion ====", UVM_NONE)

    `uvm_info(get_type_name(), $sformatf("Funcion R      = %0.2f%%", cg_r.get_inst_coverage()),      UVM_NONE)
    `uvm_info(get_type_name(), $sformatf("Funcion I      = %0.2f%%", cg_i.get_inst_coverage()),      UVM_NONE)
    `uvm_info(get_type_name(), $sformatf("Funcion U      = %0.2f%%", cg_u.get_inst_coverage()),      UVM_NONE)
    `uvm_info(get_type_name(), $sformatf("Funcion LOAD   = %0.2f%%", cg_load.get_inst_coverage()),   UVM_NONE)
    `uvm_info(get_type_name(), $sformatf("Funcion STORE  = %0.2f%%", cg_store.get_inst_coverage()),  UVM_NONE)
    `uvm_info(get_type_name(), $sformatf("Funcion BRANCH = %0.2f%%", cg_branch.get_inst_coverage()), UVM_NONE)
    `uvm_info(get_type_name(), $sformatf("Funcion JUMP   = %0.2f%%", cg_jump.get_inst_coverage()),   UVM_NONE)

  endfunction

endclass
