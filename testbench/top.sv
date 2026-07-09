`timescale 1ns/1ps

`include "darksocv.v"

module top;

  	logic idle_dbg;
  	logic [31:0] addr;
  	logic [31:0] data;

	ifc_riscv ifc_riscv_obj();

  	//instancia el dut
    darksocv DUT(
        .XCLK(ifc_riscv_obj.clk),
        .XRES(ifc_riscv_obj.res)
    );

    genvar i;
	//conexiones de las señales del core con la interfaz
    generate
        for(i=0; i<16; i=i+1) begin
            assign ifc_riscv_obj.regs[i] =
                DUT.core0.REGS[i];
        end
    endgenerate

    assign idle_dbg = DUT.core0.IDLE;
    assign ifc_riscv_obj.idleproc = idle_dbg;

  	assign addr = DUT.core0.IADDR;
    assign ifc_riscv_obj.addr = addr;

  	// XIDATA (no IDATA) es la instruccion ya latcheada en la etapa de decode:
  	// esta exactamente alineada, ciclo a ciclo, con PC e IDLE/FLUSH, que es lo
  	// que necesita el monitor para poblar item.pc y filtrar burbujas de flush.
  	assign data = DUT.core0.XIDATA;
    assign ifc_riscv_obj.data = data;

  	// PC arquitectonico de la instruccion en XIDATA (mismo registro que usa
  	// el core internamente para AUIPC/branch target/JAL, ej. PCSIMM = PC+SIMM).
  	assign ifc_riscv_obj.pc = DUT.core0.PC;

  	// HLT: se asierta 1 ciclo durante el wait-state de un LOAD (declarado
  	// en darksocv.v, no dentro de core0). XIDATA/PC quedan congelados
  	// mientras HLT=1; el monitor lo usa para no capturar la misma
  	// instruccion dos veces.
  	assign ifc_riscv_obj.hlt = DUT.HLT;

  	// Espejo de la memoria de datos del DUT, para verificar STORE (SW).
  	genvar m;
    generate
        for(m=0; m<1024; m=m+1) begin
            assign ifc_riscv_obj.mem[m] = DUT.MEM[m];
        end
    endgenerate

  	/*//estimulos para el procesador que se envian por la interfaz virtual
    initial begin
      
      	$dumpfile("dump.vcd");
        $dumpvars(0, top);
		$display("VCD enabled at time %0t", $time);
		// #0; // asegura que $dumpvars se registre antes de avanzar      
        clk = 1'b1;
        res = 1'b1;

        #10;
        res = 1'b0;

        #1000;
        res = 1'b1;

    end*/

    initial begin
      
      	$dumpfile("dump.vcd");
        $dumpvars(0, top);
		$display("VCD enabled at time %0t", $time);
		// #0; // asegura que $dumpvars se registre antes de avanzar
		
      	uvm_config_db#(virtual ifc_riscv)::set(null, "*", "ifc_riscv_obj", ifc_riscv_obj); //da un acceso a la interfaz a cualquier componente (*)
		//Ejecuta el test que se indica. Esto lo logra porque el test se ingresa en la fábrica.
      	//Ingresamos la interfaz virtual a la base de datos, así cualquier componente puede acceder a ella
        //sin que necesitmos hacer la transmisión a través de todas las instancias de la jerarquía.
        //::set indica que se ingresa el valor en la base de datos.
        //null es el scope, entonces todos los componentes pueden acceder a él.
      	run_test("riscv_test");

    end

    wire [31:0] x0  = DUT.core0.REGS[0];
    wire [31:0] x1  = DUT.core0.REGS[1];
    wire [31:0] x2  = DUT.core0.REGS[2];
    wire [31:0] x3  = DUT.core0.REGS[3];
    wire [31:0] x4  = DUT.core0.REGS[4];
    wire [31:0] x5  = DUT.core0.REGS[5];
    wire [31:0] x6  = DUT.core0.REGS[6];
    wire [31:0] x7  = DUT.core0.REGS[7];
    wire [31:0] x8  = DUT.core0.REGS[8];
    wire [31:0] x9  = DUT.core0.REGS[9];
    wire [31:0] x10 = DUT.core0.REGS[10];
    wire [31:0] x11 = DUT.core0.REGS[11];
    wire [31:0] x12 = DUT.core0.REGS[12];
    wire [31:0] x13 = DUT.core0.REGS[13];
    wire [31:0] x14 = DUT.core0.REGS[14];
    wire [31:0] x15 = DUT.core0.REGS[15];

endmodule