//==============================================================
// board_pair_top.sv  
// - conecta board_core y pair_check_rom 
//==============================================================
module board_pair_top (
    input  logic        clk,
    input  logic        rst_n,

    // ---- Control hacia board_core ----
    input  logic [3:0]  sel_idx,
    input  logic [3:0]  act_idx,
    input  logic        req_flip,
    input  logic        req_unflip,
    input  logic        req_remove_pair,

    // ---- Handshakes desde board_core ----
    output logic        can_flip_sel,
    output logic        flip_ack,
    output logic        unflip_ack,
    output logic        remove_ack,
    output logic        all_pairs_done,

    // ---- Visibilidad de tablero ----
    output logic [15:0] card_faceup,
    output logic [15:0] card_removed,

    // ---- AUTO pick ----
    input  logic [3:0]  idx_chk,       // índice a verificar
    output logic        can_flip_idx,  // 1 si es flippable

    // ---- Señales para verificación de pareja ----
    input  logic [3:0]  idx_a,
    input  logic [3:0]  idx_b,
    input  logic        pair_start,   
    output logic        pair_done,     // pulso 1 ciclo
    output logic        pair_match     // resultado
);

    // -----------------------------
    // board_core
    // -----------------------------
    board_core u_board (
        .clk             (clk),
        .rst_n           (rst_n),
        .sel_idx         (sel_idx),
        .act_idx         (act_idx),
        .req_flip        (req_flip),
        .req_unflip      (req_unflip),
        .req_remove_pair (req_remove_pair),

        .can_flip_sel    (can_flip_sel),
        .flip_ack        (flip_ack),
        .unflip_ack      (unflip_ack),
        .remove_ack      (remove_ack),
        .all_pairs_done  (all_pairs_done),

        .idx_chk         (idx_chk),       
        .can_flip_idx    (can_flip_idx),  

        .card_faceup     (card_faceup),
        .card_removed    (card_removed)
    );

    // -----------------------------
    // pair_check_rom
    // -----------------------------
    pair_check_rom u_pair (
        .clk      (clk),
        .rst_n    (rst_n),
        .start    (pair_start),
        .idx_a    (idx_a),
        .idx_b    (idx_b),
        .done     (pair_done),
        .is_match (pair_match)
    );

endmodule
