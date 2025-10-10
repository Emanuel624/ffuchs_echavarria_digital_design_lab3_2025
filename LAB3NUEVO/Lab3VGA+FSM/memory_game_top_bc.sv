//==============================================================
// memory_game_top_bc.sv
// Top que une logica + fms
//==============================================================

module memory_game_top_bc #(
  parameter int TICKS_PER_TURN = 300   
)(
  input  logic        clk,
  input  logic        rst_n,

  // UI
  input  logic        start_btn,
  input  logic        click_e,
  input  logic [3:0]  sel_idx,

  // estado
  output logic        show_winner_o,
  output logic [15:0] card_faceup_o,
  output logic [15:0] card_removed_o,
  // Turno actual hacia fuera
  output logic        current_player_o,
  // Marcador de parejas por jugador
  output logic [3:0]  p1_pairs_o,
  output logic [3:0]  p2_pairs_o,
  // Código de ganador
  output logic [1:0]  winner_code_o,   // 0=none, 1=P1, 2=P2, 3=empate
  // Salida tiempo restante (para 7-seg)
  output logic [7:0]  seconds_left_o
);

  // ----------------------------
  // Señales FSM <-> entorno
  // ----------------------------
  logic        timer_done;
  logic        all_pairs_done;
  logic        can_flip_sel;

  logic        game_active;
  logic        current_player;
  logic        enable_random;
  logic        validate_cards;
  logic        update_score;
  logic        show_winner;
  logic [5:0]  state_dbg;

  //  Con board_core
  logic        req_flip, req_unflip, req_remove;
  logic [3:0]  act_idx;
  logic        flip_ack, unflip_ack, remove_ack;

  // Pair-check
  logic        pair_start, pair_done, pair_match;
  logic [3:0]  idx_a, idx_b;

  // Control de timer
  logic        turn_load_15, turn_start, turn_pause, turn_reset;

  // ----------------------------
  // Temporizador de turno (1 Hz)
  // ----------------------------
  // Declaraciones 
  logic        running_q;
  logic [7:0]  seconds_q;       // 0..99 (usamos 15..0)
  assign seconds_left_o = seconds_q;

  // Prescaler 50 MHz -> 1 Hz
  localparam int PS_MAX = 50_000_000 - 1;
  logic [25:0] ps_cnt_q;
  logic        tick_1hz;

  // si el juego está pausado o el timer no corre, resetea el conteo
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      ps_cnt_q <= '0;
      tick_1hz <= 1'b0;
    end else begin
      if (turn_pause || !running_q) begin
        ps_cnt_q <= '0;
        tick_1hz <= 1'b0;
      end else if (ps_cnt_q == PS_MAX) begin
        ps_cnt_q <= '0;
        tick_1hz <= 1'b1;
      end else begin
        ps_cnt_q <= ps_cnt_q + 26'd1;
        tick_1hz <= 1'b0;
      end
    end
  end

  // Contador de segundos y timer_done
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      running_q  <= 1'b0;
      seconds_q  <= 8'd0;
      timer_done <= 1'b0;
    end else begin
      timer_done <= 1'b0;

      if (turn_reset) begin
        running_q <= 1'b0;
        seconds_q <= 8'd0;

      end else if (turn_load_15) begin
        //  viene alto en el mismo ciclo, arranca.
        seconds_q <= 8'd15;
        running_q <= turn_start ? 1'b1 : running_q;

      end else begin
        // Si la FSM decide "start" 
        if (turn_start) running_q <= 1'b1;

        if (running_q && !turn_pause && tick_1hz) begin
          if (seconds_q != 8'd0) begin
            seconds_q <= seconds_q - 8'd1;
            if (seconds_q == 8'd1) timer_done <= 1'b1; // pulso al pasar a 0
          end
        end
      end
    end
  end

  // ----------------------------
  // RNG (LFSR 4-bit)
  // ----------------------------
  logic [3:0] lfsr_q, lfsr_d, rnd_idx;
  logic       rnd_valid;

  // Registro del LFSR 
  // - Se inicializa en una semilla NO CERO (4'hA).
  // - Cada ciclo, lfsr_q toma lfsr_d (el siguiente estado del LFSR).
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) lfsr_q <= 4'hA;
    else        lfsr_q <= lfsr_d;
  end

  always_comb begin
    lfsr_d    = lfsr_q;
    rnd_idx   = lfsr_q;
    rnd_valid = 1'b0;
    if (enable_random) begin
	 // Avance de 4-bit LFSR
    // - lfsr_d[0] = XOR(taps)
    // - El resto es corrimiento a la izquierda (LSB entra con el XOR)
      lfsr_d    = {lfsr_q[2:0], lfsr_q[3]^lfsr_q[1]};
      rnd_idx   = lfsr_d;
      rnd_valid = 1'b1;
    end
  end

  // ----------------------------
  // board_core
  // ----------------------------
  logic can_flip_idx; 

  board_core u_board (
    .clk            (clk),
    .rst_n          (rst_n),
    .sel_idx        (sel_idx),
    .act_idx        (act_idx),
    .req_flip       (req_flip),
    .req_unflip     (req_unflip),
    .req_remove_pair(req_remove),
    .can_flip_sel   (can_flip_sel),
    .flip_ack       (flip_ack),
    .unflip_ack     (unflip_ack),
    .remove_ack     (remove_ack),
    .all_pairs_done (all_pairs_done),
    .idx_chk        (rnd_idx),          // consulta el índice
    .can_flip_idx   (can_flip_idx),     
    .card_faceup    (card_faceup_o),
    .card_removed   (card_removed_o)
  );

  // ----------------------------
  // pair_check
  // ----------------------------
  pair_check_rom u_pair (
    .clk      (clk),
    .rst_n    (rst_n),
    .start    (pair_start),
    .idx_a    (idx_a),
    .idx_b    (idx_b),
    .done     (pair_done),
    .is_match (pair_match)
  );

  // ----------------------------
  // FSM principal
  // ----------------------------
  memory_game_fsm_bc u_fsm (
    .clk               (clk),
    .reset             (~rst_n),
    .start_game        (start_btn),
    .select_e          (click_e),
    .sel_idx           (sel_idx),
    .timer_done        (timer_done),
    .all_pairs_done    (all_pairs_done),
    .rnd_idx           (rnd_idx),
    .rnd_valid         (rnd_valid),
    .can_flip_sel      (can_flip_sel),
    .flip_ack          (flip_ack),
    .unflip_ack        (unflip_ack),
    .remove_ack        (remove_ack),
    .req_flip          (req_flip),
    .req_unflip        (req_unflip),
    .req_remove_pair   (req_remove),
    .act_idx           (act_idx),
    .pair_start        (pair_start),
    .pair_done         (pair_done),
    .pair_match        (pair_match),
    .idx_a_out         (idx_a),
    .idx_b_out         (idx_b),
    .turn_load_15      (turn_load_15),
    .turn_start        (turn_start),
    .turn_pause        (turn_pause),
    .turn_reset        (turn_reset),
    .game_active       (game_active),
    .current_player    (current_player),
    .enable_random     (enable_random),
    .validate_cards    (validate_cards),
    .update_score      (update_score),
    .show_winner       (show_winner),
    .state             (state_dbg),
    .can_flip_idx_any  (can_flip_idx)
  );

  // --- Scoreboard de parejas ---
  scoreboard_pairs u_score (
    .clk           (clk),
    .rst_n         (rst_n),
    .start_game    (start_btn),
    .update_score  (update_score),
    .current_player(current_player),
    .show_winner   (show_winner),
    .p1_pairs      (p1_pairs_o),
    .p2_pairs      (p2_pairs_o)
  );

  // --- Cálculo del ganador ---
  always_comb begin
    if (!show_winner) begin
      winner_code_o = 2'd0;
    end else if (p1_pairs_o > p2_pairs_o) begin
      winner_code_o = 2'd1;
    end else if (p2_pairs_o > p1_pairs_o) begin
      winner_code_o = 2'd2;
    end else begin
      winner_code_o = 2'd3;
    end
  end

  // Exposición hacia arriba
  assign show_winner_o    = show_winner;
  assign current_player_o = current_player;

endmodule


