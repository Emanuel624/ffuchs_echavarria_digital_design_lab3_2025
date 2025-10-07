//==============================================================
// videoGen.sv
// - Renderiza la grilla del juego y el overlay de ganador.
// - Overlay: banderola centrada de color según winner_code.
//==============================================================
module videoGen (
    input  logic       vgaclk,
    input  logic       blank_b,
    input  logic [9:0] x, y,
    input  logic       show_winner,        // 1 = mostrar overlay de ganador
    input  logic [1:0] winner_code,        // 1=P1, 2=P2, 3=empate
    output logic [7:0] r, g, b
);

    // ----------------------------------------------------------
    // 1) Señales del grid base
    // ----------------------------------------------------------
    logic [7:0] r_base, g_base, b_base;

    // Instancia del grid de cartas (solo fondo + tablero)
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
        .r      (r_base),
        .g      (g_base),
        .b      (b_base)
    );

    // ----------------------------------------------------------
    // 2) Overlay de ganador (centrado)
    // ----------------------------------------------------------
    logic win_on;
    logic [7:0] win_r, win_g, win_b;

    // Dimensiones de la banderola
    localparam int BW  = 640*6/10;    // ancho 60%
    localparam int BH  = 480*2/10;    // alto 20%
    localparam int BX0 = (640 - BW)/2; // esquina izq
    localparam int BY0 = (480 - BH)/2; // esquina sup
    localparam int BX1 = BX0 + BW - 1; // derecha
    localparam int BY1 = BY0 + BH - 1; // inferior
    localparam int THK = 6;             // grosor del marco

    always_comb begin
        win_on = 1'b0;
        win_r  = 8'd0; 
        win_g  = 8'd0; 
        win_b  = 8'd0;

        if (show_winner && blank_b) begin
            if (x >= BX0 && x <= BX1 && y >= BY0 && y <= BY1) begin
                win_on = 1'b1;
                // Marco blanco
                if ((x - BX0 < THK) || (BX1 - x < THK) ||
                    (y - BY0 < THK) || (BY1 - y < THK)) begin
                    win_r = 8'd240; win_g = 8'd240; win_b = 8'd240;
                end else begin
                    unique case (winner_code)
                        2'd1: begin // Jugador 1 gana (rojo)
                            win_r = 8'd220; win_g = 8'd70;  win_b = 8'd70;
                        end
                        2'd2: begin // Jugador 2 gana (azul)
                            win_r = 8'd70;  win_g = 8'd120; win_b = 8'd220;
                        end
                        2'd3: begin // Empate
                            win_r = 8'd230; win_g = 8'd200; win_b = 8'd60;
                        end
                        default: begin // No debería pasar
                            win_r = 8'd0; win_g = 8'd0; win_b = 8'd0;
                        end
                    endcase
                end
            end
        end
    end

    // ----------------------------------------------------------
    // 3) Combinación final (overlay sobre grid)
    // ----------------------------------------------------------
    always_ff @(posedge vgaclk) begin
        if (!blank_b) begin
            r <= 8'd0;
            g <= 8'd0;
            b <= 8'd0;
        end else begin
            if (win_on) begin
                // Overlay tiene prioridad
                r <= win_r;
                g <= win_g;
                b <= win_b;
            end else begin
                // Fondo del juego
                r <= r_base;
                g <= g_base;
                b <= b_base;
            end
        end
    end

endmodule
