// ===================== cardGrid_game.sv =====================
// renderiza el grid de cartas 
module cardGrid_game #(
    parameter int CARDS_X = 4,
    parameter int CARDS_Y = 4,
    parameter int SCR_W   = 640,
    parameter int SCR_H   = 480,
    parameter int MARGIN_L = 20,
    parameter int MARGIN_R = 20,
    parameter int MARGIN_T = 20,
    parameter int MARGIN_B = 20
)(
    input  logic        vgaclk,
    input  logic        blank_b,
    input  logic [9:0]  x, y,

    input  logic [15:0] faceup_mask,    // de board_core
    input  logic [15:0] removed_mask,   // de board_core
    input  logic [3:0]  sel_idx,        // cursor actual 
    input  logic        show_winner,    // overlay de fin de juego

    output logic [7:0]  r, g, b
);
    // ===== grid =====
    localparam int VP_X0 = MARGIN_L;
    localparam int VP_Y0 = MARGIN_T;
    localparam int VP_X1 = SCR_W - 1 - MARGIN_R;
    localparam int VP_Y1 = SCR_H - 1 - MARGIN_B;
    localparam int VP_W  = VP_X1 - VP_X0 + 1;
    localparam int VP_H  = VP_Y1 - VP_Y0 + 1;
		
	 // Tamaño de celda 
    localparam int W  = VP_W / CARDS_X;
    localparam int H  = VP_H / CARDS_Y;
    localparam int GX0 = VP_X0;
    localparam int GY0 = VP_Y0;
    localparam int GX1 = GX0 + (W*CARDS_X) - 1;
    localparam int GY1 = GY0 + (H*CARDS_Y) - 1;

    localparam int BORDER = 3;

    // Colores base
    localparam [7:0] BG_R = 8'd10,  BG_G = 8'd50,  BG_B = 8'd15;
    localparam [7:0] GM_R = 8'd32,  GM_G = 8'd32,  GM_B = 8'd32;
    localparam [7:0] BD_R = 8'd240, BD_G = 8'd240, BD_B = 8'd240;
    localparam [7:0] BK_R = 8'd20,  BK_G = 8'd80,  BK_B = 8'd20;
    localparam [7:0] RM_R = 8'd28,  RM_G = 8'd28,  RM_B = 8'd28;
    localparam [7:0] HL_R = 8'd255, HL_G = 8'd255, HL_B = 8'd60;

    // --------- Regiones básicas ---------
    logic in_vp, in_grid;
    always_comb begin
        in_vp   = (x >= VP_X0) && (x <= VP_X1) && (y >= VP_Y0) && (y <= VP_Y1);
        in_grid = (x >= GX0)   && (x <= GX1)   && (y >= GY0)   && (y <= GY1);
    end

    // --------- Selección de carta  ---------
    integer relx, rely;
    integer cell_x, cell_y;
    logic   [3:0] card_ix;

    always_comb begin
        relx    = x - GX0;
        rely    = y - GY0;
        cell_x  = relx / W;
        cell_y  = rely / H;
        card_ix = cell_y * CARDS_X + cell_x; // 0..15
    end

    // --------- Bounds locales ---------
    integer x0, y0, ux, uy;
    logic in_card, in_border;
    always_comb begin
        x0 = GX0 + cell_x * W;
        y0 = GY0 + cell_y * H;
        ux = x - x0;
        uy = y - y0;
        in_card   = in_grid && (ux >= 0) && (ux < W) && (uy >= 0) && (uy < H);
        in_border = in_card && ((ux < BORDER) || (ux >= W-BORDER) || (uy < BORDER) || (uy >= H-BORDER));
    end

    // --------- Estado de carta---------
    logic [3:0] ix_safe;
    logic is_face, is_removed, is_hidden;

    always_comb ix_safe = in_card ? card_ix : 4'd0;

    always_comb begin
        is_face    = in_card ? faceup_mask[ix_safe]  : 1'b0;
        is_removed = in_card ? removed_mask[ix_safe] : 1'b0;
        is_hidden  = ~(is_face | is_removed);
    end

    // --------- Símbolo---------
    logic [3:0] sym;
    always_comb sym = (card_ix < 8) ? card_ix : (card_ix - 8);

    logic [1:0] sym_sel;
    logic [7:0] col_r, col_g, col_b;
    always_comb begin
        sym_sel = sym[1:0];
        unique case (sym)
          4'd0: begin col_r=8'd200; col_g=8'd120; col_b=8'd20;  end
          4'd1: begin col_r=8'd40;  col_g=8'd200; col_b=8'd160; end
          4'd2: begin col_r=8'd180; col_g=8'd60;  col_b=8'd200; end
          4'd3: begin col_r=8'd230; col_g=8'd210; col_b=8'd40;  end
          4'd4: begin col_r=8'd80;  col_g=8'd230; col_b=8'd80;  end
          4'd5: begin col_r=8'd60;  col_g=8'd120; col_b=8'd240; end
          4'd6: begin col_r=8'd240; col_g=8'd120; col_b=8'd60;  end
          default: begin col_r=8'd180; col_g=8'd180; col_b=8'd210; end
        endcase
    end

    // --------- Geometría local y dibujo símbolo ---------
    integer lcx, lcy, dx, dy, adx, ady;
    always_comb begin
        lcx = W/2; lcy = H/2;
        dx  = ux - lcx;
        dy  = uy - lcy;
        adx = (dx < 0) ? -dx : dx;
        ady = (dy < 0) ? -dy : dy;
    end

    localparam int R  = (H < W ? H : W) / 3;
    localparam int TH = 6;
    integer d2_tmp, man_tmp, d1abs_tmp, d2abs_tmp;
    logic draw_symbol;
    always_comb begin
        draw_symbol = 1'b0;
        d2_tmp    = dx*dx + dy*dy;
        man_tmp   = adx + ady;
        d1abs_tmp = dx - dy; if (d1abs_tmp < 0) d1abs_tmp = -d1abs_tmp;
        d2abs_tmp = dx + dy; if (d2abs_tmp < 0) d2abs_tmp = -d2abs_tmp;

        if (in_card && (is_face || is_removed)) begin
            unique case (sym_sel)
              2'd0: if ((d2_tmp <= (R*R)) && (d2_tmp >= (R-TH)*(R-TH))) draw_symbol = 1'b1; // anillo
              2'd1: if ((man_tmp >= (R-TH)) && (man_tmp <= R))          draw_symbol = 1'b1; // rombo
              2'd2: if ((adx <= TH && ady <= R) || (ady <= TH && adx <= R)) draw_symbol = 1'b1; // cruz
              default: if ((d1abs_tmp <= TH) || (d2abs_tmp <= TH))      draw_symbol = 1'b1; // x
            endcase
        end
    end

    // --------- Highlight selección ---------
    logic sel_border;
    always_comb sel_border = in_card && (card_ix == sel_idx) && !is_removed &&
                             ((ux < BORDER+2) || (ux >= W-(BORDER+2)) || (uy < BORDER+2) || (uy >= H-(BORDER+2)));

    // --------- RGB ---------
    always_ff @(posedge vgaclk) begin
        if (!blank_b) begin
            r <= 8'd0; g <= 8'd0; b <= 8'd0;
        end else if (!in_vp) begin
            r <= BG_R; g <= BG_G; b <= BG_B;
        end else if (!in_grid) begin
            r <= GM_R; g <= GM_G; b <= GM_B;
        end else if (is_removed) begin
            r <= RM_R; g <= RM_G; b <= RM_B;
        end else if (sel_border) begin
            r <= HL_R; g <= HL_G; b <= HL_B;
        end else if (in_border) begin
            r <= BD_R; g <= BD_G; b <= BD_B;
        end else if (is_hidden) begin
            r <= BK_R; g <= BK_G; b <= BK_B;
        end else if (draw_symbol) begin
            r <= col_r; g <= col_g; b <= col_b;
        end else begin
            r <= 8'd16; g <= 8'd60; b <= 8'd16;
        end

        // show winner
        if (show_winner && in_vp) begin
            r <= (r>>1) + 8'd80;
            g <= (g>>1) + 8'd10;
            b <= (b>>1) + 8'd10;
        end
    end
endmodule

