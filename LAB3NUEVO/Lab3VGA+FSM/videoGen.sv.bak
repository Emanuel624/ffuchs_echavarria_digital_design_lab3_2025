// videoGen.sv — wrapper que llama a cardGrid
module videoGen(
    input  logic       vgaclk,
    input  logic       blank_b,
    input  logic [9:0] x, y,
    output logic [7:0] r, g, b
);
    // Instancia del grid de cartas 
    cardGrid #(
        .CARDS_X (4),
        .CARDS_Y (4),
        .SCR_W   (640),
        .SCR_H   (480),
        .MARGIN_L(20),
        .MARGIN_R(20),
        .MARGIN_T(20),
        .MARGIN_B(20)
    ) u_cards (
        .vgaclk (vgaclk),
        .blank_b(blank_b),
        .x      (x),
        .y      (y),
        .r      (r),
        .g      (g),
        .b      (b)
    );
endmodule
