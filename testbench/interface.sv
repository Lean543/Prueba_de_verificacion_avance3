interface ifc_riscv;

    logic clk;
    logic res;

    logic idleproc;
    logic [31:0] addr;
    logic [31:0] data;
    logic [31:0] regs[16];

    // PC arquitectonico de la instruccion actualmente decodificada (XIDATA),
    // necesario para AUIPC, branch target, JAL y JALR.
    logic [31:0] pc;

    // Espejo de la memoria de datos del DUT (RTL/darksocv.v: MEM[0:2**MLEN/4-1]).
    // 1024 palabras de 32 bits = 4KB, debe coincidir con MLEN=12 en RTL/config.vh.
    logic [31:0] mem [0:1023];

    realtime periodo_clk = 2ns;

    // Generador de reloj
    initial begin
        clk = 0;
        forever begin
            #(periodo_clk/2);
            clk = ~clk;
        end
    end

    //estimulos para el procesador que se envian por la interfaz virtual
    //
    // NOTA: antes este bloque terminaba con "#1000; res = 1'b1;", dejando
    // res (XRES) asertado PARA SIEMPRE (nunca se volvia a bajar). RTL/darkpll.v
    // requiere ~256 ciclos de reloj despues de CADA liberacion de reset antes
    // de que el reset interno del core (RES) realmente baje (IRES/DRES son
    // contadores de 8 bits encadenados). Con res atascado en 1, el core nunca
    // sale de reset y no ejecuta nada -> el checker no recibe transacciones.
    // Tambien se quito "clk = 1'b1;" de aca: competia con el generador de
    // reloj de arriba por manejar la misma señal clk.
    initial begin

        res = 1'b1;

        #10;
        res = 1'b0;

    end

    task aplicar_reset(time duracion = 20ns);
        res = 1;
        #(duracion);
        res = 0;
    endtask

    task cambiar_periodo(realtime nuevo_periodo);
        periodo_clk = nuevo_periodo;
    endtask

endinterface