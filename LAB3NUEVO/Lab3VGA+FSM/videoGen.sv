//==============================================================
// videoGen.sv
// - Renderiza el grid del juego y, al finalizar,
//   dibuja un dígito grande centrado:
//     1 = gana P1, 2 = gana P2, 0 = empate
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

    // ===================== overlay: dígito ganador =====================
    // Dimensiones del dígito (centrado en 640x480)
    localparam int DW   = 200;                    // ancho del dígito
    localparam int DH   = 300;                    // alto del dígito
    localparam int DX0  = (640 - DW)/2;           // esquina izquierda
    localparam int DY0  = (480 - DH)/2;           // esquina superior
    localparam int DX1  = DX0 + DW - 1;
    localparam int DY1  = DY0 + DH - 1;

    // Parámetros 
    localparam int PAD  = 16;                     // margen interno
    localparam int TH   = 22;                     // grosor de segmento

    // Mapeo de winner_code -> dígito a mostrar
    // 1->'1', 2->'2', 3->'0', otro -> nada
    logic [3:0] digit;
    always_comb begin
        unique case (winner_code)
            2'd1: digit = 4'd1;
            2'd2: digit = 4'd2;
            2'd3: digit = 4'd0;
            default: digit = 4'd15; // nada
        endcase
    end

    // Área activa del dígito y coords locales
    logic in_digit;
    int   ux, uy;
    always_comb begin
        in_digit = 1'b0;
        ux = 0; uy = 0;
        if (show_winner && blank_b &&
            x >= DX0 && x <= DX1 && y >= DY0 && y <= DY1) begin
            in_digit = 1'b1;
            ux = x - DX0;
            uy = y - DY0;
        end
    end

    // Rectángulos de segmentos (A,B,C,D,E,F,G)para hacer los numeros
    logic inA, inB, inC, inD, inE, inF, inG;
    always_comb begin
        // defaults
        inA = 1'b0; inB = 1'b0; inC = 1'b0;
        inD = 1'b0; inE = 1'b0; inF = 1'b0; inG = 1'b0;

        if (in_digit) begin
            // horizontales
            inA = (uy >= PAD) && (uy < PAD + TH) &&
                  (ux >= PAD) && (ux < DW - PAD);
            inG = (uy >= (DH/2 - TH/2)) && (uy < (DH/2 + TH/2)) &&
                  (ux >= PAD) && (ux < DW - PAD);
            inD = (uy >= (DH - PAD - TH)) && (uy < (DH - PAD)) &&
                  (ux >= PAD) && (ux < DW - PAD);

            // verticales izq
            inF = (ux >= PAD) && (ux < PAD + TH) &&
                  (uy >= PAD + TH) && (uy < (DH/2 - TH/2));
            inE = (ux >= PAD) && (ux < PAD + TH) &&
                  (uy >= (DH/2 + TH/2)) && (uy < (DH - PAD - TH));

            // verticales der
            inB = (ux >= (DW - PAD - TH)) && (ux < (DW - PAD)) &&
                  (uy >= PAD + TH) && (uy < (DH/2 - TH/2));
            inC = (ux >= (DW - PAD - TH)) && (ux < (DW - PAD)) &&
                  (uy >= (DH/2 + TH/2)) && (uy < (DH - PAD - TH));
        end
    end

    // Activación de segmentos por dígito (estilo 7-seg clásico)
    //   0 -> A B C D E F
    //   1 ->   B C
    //   2 -> A B   D E   G
    logic segA_on, segB_on, segC_on, segD_on, segE_on, segF_on, segG_on;
    always_comb begin
        segA_on = 1'b0; segB_on = 1'b0; segC_on = 1'b0;
        segD_on = 1'b0; segE_on = 1'b0; segF_on = 1'b0; segG_on = 1'b0;
        unique case (digit)
            4'd0: begin segA_on=1; segB_on=1; segC_on=1; segD_on=1; segE_on=1; segF_on=1; segG_on=0; end
            4'd1: begin segA_on=0; segB_on=1; segC_on=1; segD_on=0; segE_on=0; segF_on=0; segG_on=0; end
            4'd2: begin segA_on=1; segB_on=1; segC_on=0; segD_on=1; segE_on=1; segF_on=0; segG_on=1; end
            default: begin // nada (no dibuja)
                segA_on=0; segB_on=0; segC_on=0; segD_on=0; segE_on=0; segF_on=0; segG_on=0;
            end
        endcase
    end

    // Dibujar pixel del dígito?
    logic draw_digit;
    always_comb begin
        draw_digit = 1'b0;
        if (in_digit) begin
            draw_digit =
                (segA_on && inA) ||
                (segB_on && inB) ||
                (segC_on && inC) ||
                (segD_on && inD) ||
                (segE_on && inE) ||
                (segF_on && inF) ||
                (segG_on && inG);
        end
    end

    // Color del dígito 
    localparam [7:0] DIG_R = 8'd255, DIG_G = 8'd255, DIG_B = 8'd255;

    // ===================== composición final =====================
    always_ff @(posedge vgaclk) begin
        if (!blank_b) begin
            r <= 8'd0; g <= 8'd0; b <= 8'd0;
        end else if (draw_digit) begin
            r <= DIG_R; g <= DIG_G; b <= DIG_B;
        end else begin
            r <= r_base; g <= g_base; b <= b_base;
        end
    end

endmodule
