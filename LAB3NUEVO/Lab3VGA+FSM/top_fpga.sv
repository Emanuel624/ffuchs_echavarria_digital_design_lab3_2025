//------------------------------------------------------------------------------
// top_fpga.sv
// Punto de entrada en FPGA.
//------------------------------------------------------------------------------
module top_fpga (
    input  logic        clk,       // reloj base 50 MHz de la placa
    input  logic        nxt,         
    input  logic        rst_n_btn,   // botón reset del contador 

    // VGA
    output logic        vgaclk,
    output logic        hsync, vsync,
    output logic        sync_b, blank_b,
    output logic [7:0]  r, g, b,

    // Numero pantalla
    output logic [6:0]  HEX0
);
    // ---- Video  ----
    vga u_vga (
        .clk    (clk),
        .nxt    (nxt),
        .vgaclk (vgaclk),
        .hsync  (hsync),
        .vsync  (vsync),
        .sync_b (sync_b),
        .blank_b(blank_b),
        .r      (r),
        .g      (g),
        .b      (b)
    );
endmodule
