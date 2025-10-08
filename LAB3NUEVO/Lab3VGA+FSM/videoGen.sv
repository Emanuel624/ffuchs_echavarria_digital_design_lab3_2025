//==============================================================
// videoGen.sv
// - Renderiza la grilla del juego y el overlay de ganador.
// - Overlay: banderola centrada de color según winner_code.
//==============================================================
module videoGen_game(
    input  logic        vgaclk,
    input  logic        blank_b,
    input  logic [9:0]  x, y,
    input  logic [15:0] faceup_mask,
    input  logic [15:0] removed_mask,
    input  logic [3:0]  sel_idx,
    input  logic        show_winner,
    input  logic [1:0]  winner_code,   // 1=P1, 2=P2, 3=empate
    output logic [7:0]  r, g, b
);
    // ===================== grid base =====================
    logic [7:0] r_base, g_base, b_base;

    cardGrid_game u_grid (
        .vgaclk      (vgaclk),
        .blank_b     (blank_b),
        .x           (x),
        .y           (y),
        .faceup_mask (faceup_mask),
        .removed_mask(removed_mask),
        .sel_idx     (sel_idx),
        .show_winner (show_winner),
        .r           (r_base),
        .g           (g_base),
        .b           (b_base)
    );

    // ===================== overlay ganador =====================
    localparam int BW  = 640*6/10;
    localparam int BH  = 480*2/10;
    localparam int BX0 = (640 - BW)/2;
    localparam int BY0 = (480 - BH)/2;
    localparam int BX1 = BX0 + BW - 1;
    localparam int BY1 = BY0 + BH - 1;
    localparam int THK = 6;

    logic win_on;
    logic [7:0] win_r, win_g, win_b;

    always_comb begin
        win_on = 1'b0;
        win_r  = 8'd0; win_g = 8'd0; win_b = 8'd0;

        if (show_winner && blank_b &&
            x >= BX0 && x <= BX1 && y >= BY0 && y <= BY1) begin
            win_on = 1'b1;
            if ((x - BX0 < THK) || (BX1 - x < THK) ||
                (y - BY0 < THK) || (BY1 - y < THK)) begin
                win_r = 8'd240; win_g = 8'd240; win_b = 8'd240;
            end else begin
                unique case (winner_code)
                    2'd1: begin win_r = 8'd220; win_g = 8'd70;  win_b = 8'd70;  end // P1 rojo
                    2'd2: begin win_r = 8'd70;  win_g = 8'd120; win_b = 8'd220; end // P2 azul
                    2'd3: begin win_r = 8'd230; win_g = 8'd200; win_b = 8'd60;  end // empate amarillo
                    default: begin win_r = 8'd0; win_g = 8'd0; win_b = 8'd0; end
                endcase
            end
        end
    end

    // ===================== composición final =====================
    always_ff @(posedge vgaclk) begin
        if (!blank_b) begin
            r <= 8'd0; g <= 8'd0; b <= 8'd0;
        end else if (win_on) begin
            r <= win_r; g <= win_g; b <= win_b;
        end else begin
            r <= r_base; g <= g_base; b <= b_base;
        end
    end
endmodule
