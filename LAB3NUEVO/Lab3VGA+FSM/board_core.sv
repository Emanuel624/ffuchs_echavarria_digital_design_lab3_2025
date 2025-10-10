//==============================================================
// board_core.sv
// logica operaciones con cartas (flips, etc.)
//==============================================================
module board_core #(
    parameter int N_CARDS = 16
) (
    input  logic        clk,
    input  logic        rst_n,

    // Índices desde UI/FSM
    input  logic [3:0]  sel_idx,      // índice bajo el cursor (para validar selección)
    input  logic [3:0]  act_idx,      // índice de la acción

    // Órdenes de la FSM
    input  logic        req_flip,         // voltear a boca-arriba si era oculta
    input  logic        req_unflip,       // volver a oculta si estaba boca-arriba
    input  logic        req_remove_pair,  // marcar como removida (tras match)

    // Servicios hacia FSM
    output logic        can_flip_sel,     // 1 si sel_idx es legal de voltear
    output logic        flip_ack,         // se ejecuta flip válido
    output logic        unflip_ack,       // se ejecuta unflip válido
    output logic        remove_ack,       // se ejecuta remove válido
    output logic        all_pairs_done,   // 1 cuando las 16 cartas están REMOVED

    // consulta para AUTO pick
    input  logic [3:0]  idx_chk,         // índice a verificar
    output logic        can_flip_idx,    // 1 si idx_chk es legal de voltear

    output logic [15:0] card_faceup,
    output logic [15:0] card_removed
);

    // Simbolos (ROM) 0..7 repetidos
    localparam logic [3:0] SYM_ROM [0:15] = '{
        4'd0,4'd1,4'd2,4'd3,4'd4,4'd5,4'd6,4'd7,
        4'd0,4'd1,4'd2,4'd3,4'd4,4'd5,4'd6,4'd7
    };

    // Estados por carta
    typedef enum logic [1:0] { HIDDEN=2'b00, FACEUP=2'b01, REMOVED=2'b10 } cstate_e;
    cstate_e state_q [0:15];

    // Máscaras exportadas
    always_comb begin
        card_faceup  = '0;
        card_removed = '0;
        for (int k = 0; k < 16; k++) begin
            card_faceup[k]  = (state_q[k] == FACEUP);
            card_removed[k] = (state_q[k] == REMOVED);
        end
    end

    // Conteos combinacionales
    function automatic int count_removed();
        int c = 0;
        for (int i=0; i<16; i++) if (state_q[i] == REMOVED) c++;
        return c;
    endfunction

    function automatic int count_faceup();
        int c = 0;
        for (int i=0; i<16; i++) if (state_q[i] == FACEUP) c++;
        return c;
    endfunction

    // Variables temporales
    cstate_e s_sel, s_chk;

    // Validaciones de puedo voltear?
    always_comb begin
        s_sel = state_q[sel_idx];
        s_chk = state_q[idx_chk];

        can_flip_sel = (s_sel == HIDDEN) && (count_faceup() < 2);
        can_flip_idx = (s_chk == HIDDEN) && (count_faceup() < 2);
    end

    // todas removidas
    always_comb begin
        all_pairs_done = (count_removed() == 16);
    end
	 
	 // Política de prioridad: 
    // RESET + ACCIONES + ACKs (UN SOLO always_ff)
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (int i = 0; i < 16; i++) begin
                state_q[i] <= HIDDEN;
            end
            flip_ack   <= 1'b0;
            unflip_ack <= 1'b0;
            remove_ack <= 1'b0;
        end else begin
            // acks (1 ciclo)
            flip_ack   <= 1'b0;
            unflip_ack <= 1'b0;
            remove_ack <= 1'b0;

            // Prioridad: flip > unflip > remove (la FSM emite solo una por ciclo)
            if (req_flip) begin
                if (state_q[act_idx] == HIDDEN && count_faceup() < 2) begin
                    state_q[act_idx] <= FACEUP;
                    flip_ack         <= 1'b1;
                end
            end else if (req_unflip) begin
                if (state_q[act_idx] == FACEUP) begin
                    state_q[act_idx] <= HIDDEN;
                    unflip_ack       <= 1'b1; // pulso 1 ciclo
                end
            end else if (req_remove_pair) begin
                if (state_q[act_idx] == FACEUP) begin
                    state_q[act_idx] <= REMOVED;
                    remove_ack       <= 1'b1;
                end
            end
        end
    end

endmodule

