module vga(
    input  logic clk, nxt,
    output logic vgaclk,            // 25 MHz aprox (usa PLL real a 25.175 MHz en placa)
    output logic hsync, vsync,
    output logic sync_b, blank_b,   // monitor
    output logic [7:0] r, g, b
);
    logic [9:0] x, y;

    // Módulo para obtener ~25MHz 
    pll vgapll(.inclk0(clk), .c0(vgaclk));

    // Generador de sincronías y coordenadas
    vgaController vgaCont(
        .vgaclk(vgaclk),
        .hsync(hsync), .vsync(vsync),
        .sync_b(sync_b), .blank_b(blank_b),
        .x(x), .y(y)
    );

    videoGen videoGen(
		.vgaclk(vgaclk),
		.blank_b(blank_b),
		.x(x), .y(y),
		.r(r), .g(g), .b(b)
	);
	

endmodule
