// cardGrid.sv — tablero 4x4 con viewport y símbolos (compatible Quartus 20.1)
module cardGrid #(
    parameter int CARDS_X = 4,
    parameter int CARDS_Y = 4,
    parameter int SCR_W   = 640,
    parameter int SCR_H   = 480,

    // Márgenes del viewport 
    parameter int MARGIN_L = 20,
    parameter int MARGIN_R = 20,
    parameter int MARGIN_T = 20,
    parameter int MARGIN_B = 20
)(
    input  logic       vgaclk,
    input  logic       blank_b,        
    input  logic [9:0] x, y,           
    output logic [7:0] r, g, b // RGB888
);
    // ===== Viewport =====
    localparam int VP_X0 = MARGIN_L;
    localparam int VP_Y0 = MARGIN_T;
    localparam int VP_X1 = SCR_W - 1 - MARGIN_R;   
    localparam int VP_Y1 = SCR_H - 1 - MARGIN_B;   
    localparam int VP_W  = VP_X1 - VP_X0 + 1;
    localparam int VP_H  = VP_Y1 - VP_Y0 + 1;

    // Tamaño de celda entero dentro del viewport
    localparam int W = VP_W / CARDS_X;   
    localparam int H = VP_H / CARDS_Y;   

    // Área exacta del grid 
    localparam int GX0 = VP_X0;
    localparam int GY0 = VP_Y0;
    localparam int GX1 = GX0 + (W*CARDS_X) - 1;  
    localparam int GY1 = GY0 + (H*CARDS_Y) - 1;  

    // Estilo
    localparam int  BORDER = 3;                     // grosor del borde de la carta
    localparam [7:0] BG_R = 8'd10, BG_G = 8'd50, BG_B = 8'd15;  // fondo

    // ===== Señales/comunes =====
    logic in_vp, in_grid;

    integer relx, rely;       // relativas al grid
    integer cell_x, cell_y;   // 0..CARDS_X-1 / 0..CARDS_Y-1
    logic   [3:0] card_ix;

    integer x0, y0, x1, y1;   // bounds absolutos 
    integer ux, uy;           // coords locales a carta
    logic   in_card, in_border;

    integer lcx, lcy, dx, dy, adx, ady; // geometría local

    logic   [3:0] pair_id;
    logic   [1:0] sym_sel;              
    logic   [7:0] col_r, col_g, col_b;

    // Temporales para el cálculo de símbolos 
    integer d2_tmp;      // dx*dx + dy*dy
    integer man_tmp;     // adx + ady
    integer d1abs_tmp;   // |dx - dy|
    integer d2abs_tmp;   // |dx + dy|

    // ===== Regiónes básicas =====
    always_comb begin
        in_vp   = (x >= VP_X0) && (x <= VP_X1) && (y >= VP_Y0) && (y <= VP_Y1);
        in_grid = (x >= GX0)   && (x <= GX1)   && (y >= GY0)   && (y <= GY1);
    end

    // ===== Selección de carta (índice) =====
    always_comb begin
        relx   = x - GX0;
        rely   = y - GY0;
        cell_x = relx / W;
        cell_y = rely / H;
        card_ix = cell_y * CARDS_X + cell_x; // 0..15
    end

    // ===== Bounds de carta y coordenadas locales =====
    always_comb begin
        // bounds inclusivos 
        x0 = GX0 + cell_x * W;
        y0 = GY0 + cell_y * H;
        x1 = x0 + W - 1;
        y1 = y0 + H - 1;

        // coords locales 
        ux = x - x0;
        uy = y - y0;

        // región de carta
        in_card = in_grid && (ux >= 0) && (ux < W) && (uy >= 0) && (uy < H);

        // borde simétrico en coords locales
        in_border = in_card && (
            (ux < BORDER) || (ux >= (W - BORDER)) ||
            (uy < BORDER) || (uy >= (H - BORDER))
        );
    end

    // ===== Geometría local para símbolos =====
    always_comb begin
        lcx = W/2;
        lcy = H/2;
        dx  = ux - lcx;
        dy  = uy - lcy;
        adx = (dx < 0) ? -dx : dx;
        ady = (dy < 0) ? -dy : dy;
    end

    // ===== Asignación de pares y selección de símbolo/color =====
    always_comb begin
        case (card_ix)
             4'd0,  4'd1 : pair_id = 4'd0;
             4'd2,  4'd3 : pair_id = 4'd1;
             4'd4,  4'd5 : pair_id = 4'd2;
             4'd6,  4'd7 : pair_id = 4'd3;
             4'd8,  4'd9 : pair_id = 4'd4;
             4'd10, 4'd11: pair_id = 4'd5;
             4'd12, 4'd13: pair_id = 4'd6;
             default     : pair_id = 4'd7;  
        endcase
    end

    always_comb begin
        sym_sel = pair_id[1:0];
        unique case (pair_id)
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

    // Radio y grosor del símbolo
    localparam int R  = (H < W ? H : W) / 3;
    localparam int TH = 6;

    // ===== Detección del símbolo (en coords locales) =====
    logic draw_symbol;
    always_comb begin
        draw_symbol = 1'b0;

        // precálculos
        d2_tmp    = dx*dx + dy*dy;     // círculo
        man_tmp   = adx + ady;         // rombo
        d1abs_tmp = dx - dy;  if (d1abs_tmp  < 0) d1abs_tmp  = -d1abs_tmp;
        d2abs_tmp = dx + dy;  if (d2abs_tmp  < 0) d2abs_tmp  = -d2abs_tmp;

        if (in_card) begin
            unique case (sym_sel)
              2'd0: begin // CÍRCULO 
                  if ((d2_tmp <= (R*R)) && (d2_tmp >= (R-TH)*(R-TH)))
                      draw_symbol = 1'b1;
              end
              2'd1: begin // ROMBO 
                  if ((man_tmp >= (R-TH)) && (man_tmp <= R))
                      draw_symbol = 1'b1;
              end
              2'd2: begin // +
                  if ( (adx <= TH && ady <= R) || (ady <= TH && adx <= R) )
                      draw_symbol = 1'b1;
              end
              default: begin // X 
                  if ((d1abs_tmp <= TH) || (d2abs_tmp <= TH))
                      draw_symbol = 1'b1;
              end
            endcase
        end
    end

    // ===== Salida RGB =====
    always_ff @(posedge vgaclk) begin
        if (!blank_b) begin
            r <= 8'd0; g <= 8'd0; b <= 8'd0;                     // fuera 640x480
        end else if (!in_vp) begin
            r <= BG_R; g <= BG_G; b <= BG_B;                     // fuera viewport
        end else if (!in_grid) begin
            r <= 8'd32; g <= 8'd32; b <= 8'd32;                  // marco interno
        end else if (in_border) begin
            r <= 8'd240; g <= 8'd240; b <= 8'd240;               // borde de carta
        end else if (draw_symbol) begin
            r <= col_r; g <= col_g; b <= col_b;                  // símbolo
        end else begin
            r <= 8'd16; g <= 8'd60; b <= 8'd16;                  // relleno de carta
        end
    end
endmodule