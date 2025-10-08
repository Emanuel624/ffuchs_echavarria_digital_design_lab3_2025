//==============================================================
// pair_check_rom.sv
//  - Compara símbolos por índices usando la misma ROM fija
//  - Responde con pulso 'done' de 1 ciclo al flanco de 'start'
//==============================================================
module pair_check_rom (
    input  logic       clk,
    input  logic       rst_n,
    input  logic       start,      // pulso 1 ciclo (o level -> solo detecta flanco)
    input  logic [3:0] idx_a,
    input  logic [3:0] idx_b,
    output logic       done,       // pulso 1 ciclo
    output logic       is_match
);
    localparam logic [3:0] SYM_ROM [0:15] = '{
        4'd0,4'd1,4'd2,4'd3,4'd4,4'd5,4'd6,4'd7,
        4'd0,4'd1,4'd2,4'd3,4'd4,4'd5,4'd6,4'd7
    };

    logic start_q;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            start_q  <= 1'b0;
            done     <= 1'b0;
            is_match <= 1'b0;
        end else begin
            start_q <= start;
            done    <= 1'b0;          // default

            if (start & ~start_q) begin
                is_match <= (SYM_ROM[idx_a] == SYM_ROM[idx_b]);
                done     <= 1'b1;     // pulso 1 ciclo
            end
        end
    end
endmodule
