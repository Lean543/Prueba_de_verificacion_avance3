class riscv_item extends uvm_sequence_item;
  
  	localparam logic [6:0] OPCODE_R      = 7'b0110011;
    localparam logic [6:0] OPCODE_I      = 7'b0010011;
    localparam logic [6:0] OPCODE_LOAD   = 7'b0000011;
    localparam logic [6:0] OPCODE_STORE  = 7'b0100011;
    localparam logic [6:0] OPCODE_BRANCH = 7'b1100011;
    localparam logic [6:0] OPCODE_JALR   = 7'b1100111;
    localparam logic [6:0] OPCODE_JAL    = 7'b1101111;
    localparam logic [6:0] OPCODE_LUI    = 7'b0110111;
    localparam logic [6:0] OPCODE_AUIPC  = 7'b0010111;
  
  	//Registrarse en la fábrica
    `uvm_object_utils(riscv_item)

  	typedef enum {
        R_TYPE,
        I_ALU_TYPE,
        I_LOAD_TYPE,
        I_JALR_TYPE,
        S_TYPE,
        B_TYPE,
        U_TYPE,
        J_TYPE
    } instr_type_e;

  	logic [6:0] opcode_u;

    logic [31:0] instruction;
  
  	int pc;
	int max_pc;

    // La secuencia lo pone en 1 SOLO para el JALR de la pareja AUIPC+JALR;
    // un JALR suelto (sin base conocida) saltaría a una dirección impredecible
    bit jalr_habilitado;
  
  	function new(string name = "riscv_item");
        super.new(name);
    endfunction
          
    //randomizar los bits de todos los conjuntos de bits de toda instruccion    
    rand  instr_type_e instr_type;

    rand bit [4:0] rs1;
    rand bit [4:0] rs2;
    rand bit [4:0] rd;

    rand bit [6:0] funct7;
    rand bit [2:0] funct3;
  
  	rand bit [11:0] imm_i; // inmediato de 12 bits (tipo I)
    rand bit [11:0] imm_s;
    rand bit [12:0] imm_b;
  
  	rand bit [19:0] imm_u; // inmediato superior de 20 bits
  	rand bit u_select; //al ser un bit puede ser 1 o 0 entonces no hay que hacer constrain
  
    rand bit [20:0] imm_j;
  	//Randomizar teniendo en cuenta las siguientes restricciones de todos los constrains:

    // Se limitan los índices de registro a la mitad inferior (x0–x15)
    constraint lower_registers {
      	rs1[4] == 1'b0; //16 registros
        rs2[4] == 1'b0;
        rd[4]  == 1'b0;
        rd     != 5'b00000; // escrituras a x0 se descartan
    }
  
  	// funct7 solo es relevante en tipo R; se fuerza a 0 en los demás tipos
    constraint valid_funct7 {
        if (instr_type == R_TYPE)
            funct7 inside {7'b0000000, 7'b0100000};
        else
            funct7 == 7'b0000000;
    }

    // SUB y SRA requieren funct7=0100000; las demás operaciones R usan 0000000
    constraint valid_r_funct3 {

        if(instr_type == R_TYPE)

            if(funct7 == 7'b0100000)
                funct3 inside {3'b000,3'b101};
            else
                funct3 inside {
                    3'b000,
                    3'b001,
                    3'b010,
                    3'b011,
                    3'b100,
                    3'b101,
                    3'b110,
                    3'b111
                };
    }
          
    constraint valid_i {

        if(instr_type == I_ALU_TYPE)
            funct3 inside {
                3'b000,
                3'b001,
                3'b010,
                3'b011,
                3'b100,
                3'b101,
                3'b110,
                3'b111
            };
    }

    // Para SRLI/SRAI (funct3=101 en tipo I), imm[11:5] codifica la variante de desplazamiento
    // Para SLLI (funct3=001 en tipo I), la ISA exige imm[11:5]=0000000 (otro valor es codificación reservada)
    constraint valid_i_shift {
        if (instr_type == I_ALU_TYPE && funct3 == 3'b101)
            imm_i[11:5] inside {7'b0000000,7'b0100000};
        if (instr_type == I_ALU_TYPE && funct3 == 3'b001)
            imm_i[11:5] == 7'b0000000;
    }

    // Inmediato superior no nulo para resultados no triviales en LUI.
    // AUIPC (u_select=0) sí puede llevar imm=0: se usa para capturar el PC en la pareja AUIPC+JALR
    constraint valid_u {
        if (instr_type == U_TYPE && u_select == 1'b1)
            imm_u != 20'b0;
    }
  
  	constraint valid_branch {
        if(instr_type==B_TYPE)
            funct3 inside {
                3'b000, // BEQ
                3'b001, // BNE
                3'b100, // BLT
                3'b101, // BGE
                3'b110, // BLTU
                3'b111  // BGEU
            };
    }    
    constraint valid_branch_imm {
        if(instr_type == B_TYPE)
            imm_b[1:0] == 2'b00; // destino alineado a 4 (todas las instrucciones son de 32 bits)
    }
  	// Progreso garantizado: offset solo hacia adelante (nunca 0 = loop infinito),
  	// pequeño para saltar poco código muerto, y sin salirse del programa
  	constraint valid_branch_target {
        if(instr_type == B_TYPE) {
            imm_b inside {[4:32]};
            (pc + int'(imm_b)) <= max_pc;
        }
    }
    // JALR solo aparece cuando la secuencia lo habilita (pareja AUIPC+JALR)
    constraint valid_jalr_enable {
        if (!jalr_habilitado)
            instr_type != I_JALR_TYPE;
    }

    // JALR: destino = (PC del AUIPC previo, que está en pc-4) + imm.
    // offset >= 8 garantiza caer estrictamente después del propio JALR (progreso),
    // alineado a 4 y sin salirse del programa. funct3=000 por ISA.
    constraint valid_jalr {
        if (instr_type == I_JALR_TYPE) {
            funct3 == 3'b000;
            imm_i[1:0] == 2'b00;
            imm_i inside {[8:36]};
            ((pc - 4) + int'(imm_i)) <= max_pc;
        }
    }
          
    constraint valid_load {

        if(instr_type == I_LOAD_TYPE) {
            funct3 == 3'b010;
            imm_i[1:0] == 2'b00; // dirección de LW alineada a palabra
        }
    }
          
    constraint valid_store {

        if(instr_type == S_TYPE)
            funct3 == 3'b010;
    }
  	constraint valid_store_imm {
        if(instr_type == S_TYPE)
            imm_s[1:0] == 2'b00; // dirección de SW alineada a palabra
    }
          
    constraint valid_jal {
        if(instr_type == J_TYPE)
            imm_j[1:0] == 2'b00; // destino alineado a 4
    }
  	// Progreso garantizado: mismas reglas que en branch
  	constraint valid_jal_target {
        if(instr_type == J_TYPE) {
            imm_j inside {[4:32]};
            (pc + int'(imm_j)) <= max_pc;
        }
    }

    // En la última instrucción del programa no cabe un salto hacia adelante: ahí se excluyen B/J/JALR
    constraint no_flow_at_end {
        if (pc + 4 > max_pc)
            !(instr_type inside {B_TYPE, J_TYPE, I_JALR_TYPE});
    }
          
	//concatenar los bits pertenecientes al tipo de instruccion generado con las restricciones
  	function void build_instruction();

        case(instr_type)
            // R
            R_TYPE:
                instruction = {funct7,rs2,rs1,funct3,rd,OPCODE_R};
          
            // I ALU
            I_ALU_TYPE:
                instruction = {imm_i,rs1,funct3,rd,OPCODE_I};
          
            // LW
            I_LOAD_TYPE:
                instruction = {imm_i,rs1,3'b010,rd,OPCODE_LOAD};
          
            // JALR (siempre en pareja con un AUIPC previo que deja la base en rs1)
            I_JALR_TYPE:
                instruction = {imm_i,rs1,3'b000,rd,OPCODE_JALR};
            // SW
            S_TYPE:
              	instruction = {imm_s[11:5], rs2, rs1, 3'b010, imm_s[4:0], OPCODE_STORE};
          
            // Branch
            B_TYPE:
              	instruction = {imm_b[12], imm_b[10:5], rs2, rs1, funct3, imm_b[4:1], imm_b[11], OPCODE_BRANCH};
          
            // LUI/AUIPC
            U_TYPE: begin
              	opcode_u = (u_select) ? OPCODE_LUI : OPCODE_AUIPC;
                instruction = {imm_u, rd, opcode_u};
            end	
            // JAL
            J_TYPE:
              	instruction = {imm_j[20], imm_j[10:1], imm_j[11], imm_j[19:12], rd, OPCODE_JAL};
            default:
                instruction = 32'h13; //default meter un NOP

        endcase

    endfunction

    function string convert2string();

        string type_str;

        case (instr_type)
            R_TYPE:      type_str = "R";
            I_ALU_TYPE:  type_str = "I-ALU";
            I_LOAD_TYPE: type_str = "I-LOAD";
            I_JALR_TYPE: type_str = "I-JALR";
            S_TYPE:      type_str = "S";
            B_TYPE:      type_str = "B";
            U_TYPE: begin
                if (opcode_u == OPCODE_LUI)
                    type_str = "U-LUI";
                else
                    type_str = "U-AUIPC";
            end
            J_TYPE:      type_str = "J";
            default:     type_str = "?";
        endcase
      
        return $sformatf(
            "[%s] instruction=%08h rd=%0d rs1=%0d rs2=%0d funct7=%07b funct3=%03b imm_i=%03h imm_s=%03h imm_b=%04h imm_u=%05h imm_j=%06h",
            type_str,
            instruction,
            rd,
            rs1,
            rs2,
            funct7,
            funct3,
            imm_i,
            imm_s,
            imm_b,
            imm_u,
            imm_j
        );

    endfunction
endclass