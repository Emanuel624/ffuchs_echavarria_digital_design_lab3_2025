//==============================================================
// FSM de Memoria (2 jugadores) compatible con board_core
// - Handshakes: req_flip / req_unflip / req_remove_pair + *_ack
// - Pipelín de flip: PREP->DO->WAIT (evita carreras)
// - Usa pair_check por pulso: pair_start / pair_done / pair_match
// - Retiene turno si hay match; cambia si no hay match
// - all_pairs_done => SHOW_WINNER
//==============================================================
module memory_game_fsm_bc (
    input  logic        clk,
    input  logic        reset,

    // UI
    input  logic        start_game,     // pulso/level
    input  logic        select_e,       // pulso de click
    input  logic [3:0]  sel_idx,        // índice del cursor

    // Timer turno (15 s)
    input  logic        timer_done,     // timeout del turno

    // Fin de juego (viene del board_core)
    input  logic        all_pairs_done,

    // RNG para auto-pick cuando hay timeout
    input  logic [3:0]  rnd_idx,
    input  logic        rnd_valid,
	 input  logic        can_flip_idx_any, // NUEVO: consulta para rnd_idx


    // Handshakes con board_core
    input  logic        can_flip_sel,   // válido flip en sel_idx
    input  logic        flip_ack,
    input  logic        unflip_ack,
    input  logic        remove_ack,

    output logic        req_flip,
    output logic        req_unflip,
    output logic        req_remove_pair,
    output logic [3:0]  act_idx,

    // Pair-checker (módulo aparte)
    output logic        pair_start,     // pulso 1 ciclo
    input  logic        pair_done,      // pulso 1 ciclo
    input  logic        pair_match,     // válido con pair_done

    output logic [3:0]  idx_a_out,      // picks confirmados
    output logic [3:0]  idx_b_out,

    // Control a timer (opcional, útil en top)
    output logic        turn_load_15,
    output logic        turn_start,
    output logic        turn_pause,
    output logic        turn_reset,

    // Salidas de “juego”
    output logic        game_active,
    output logic        current_player, // 0=P1, 1=P2
    output logic        enable_random,  // habilita RNG en AUTO
    output logic        validate_cards, // pulso/level cuando estamos chequeando
    output logic        update_score,   // pulso cuando hay match
    output logic        show_winner,

    // Debug
    output logic [5:0]  state
);
    // Estados
    typedef enum logic [5:0] {
        S_IDLE          = 6'd0,
        S_WAIT_START    = 6'd1,
        S_NEW_TURN      = 6'd2,

        S_PICK1         = 6'd3,
        S_AUTO1         = 6'd4,
        S_PREP_FLIP1    = 6'd5,
        S_DO_FLIP1      = 6'd6,
        S_WAIT_FLIP1    = 6'd7,

        S_PICK2         = 6'd8,
        S_AUTO2         = 6'd9,
        S_PREP_FLIP2    = 6'd10,
        S_DO_FLIP2      = 6'd11,
        S_WAIT_FLIP2    = 6'd12,

        S_CHECK         = 6'd13,

        S_MATCH_REM_A   = 6'd14,
        S_MATCH_WAIT_A  = 6'd15,
        S_MATCH_REM_B   = 6'd16,
        S_MATCH_WAIT_B  = 6'd17,
        S_NEXT_SAME     = 6'd18,

        S_MISS_UNF_A    = 6'd19,
        S_MISS_WAIT_A   = 6'd20,
        S_MISS_UNF_B    = 6'd21,
        S_MISS_WAIT_B   = 6'd22,
        S_NEXT_PLAYER   = 6'd23,

        S_GAMEOVER      = 6'd24
    } state_t;

    state_t s, ns;

    // Registros de juego
    logic        cur_player;      // 0=P1, 1=P2
    logic [3:0]  idx_a, idx_b;    // picks confirmados (después de flip_ack)
    logic [3:0]  idx_target;      // índice latcheado para el flip en curso
    logic        last_match;      // copia de pair_match cuando pair_done

    // Exponer por puertos
    assign current_player = cur_player;
    assign idx_a_out      = idx_a;
    assign idx_b_out      = idx_b;
    assign state          = s;

    // Señales “informativas”
    assign game_active    = (s != S_IDLE) && (s != S_GAMEOVER);
    assign validate_cards = (s == S_CHECK);
    assign show_winner    = (s == S_GAMEOVER);

    // Timer: cargar/arrancar al inicio del turno, pausar durante animaciones
    // (ajusta a tu timer real)
    // - load/start en S_NEW_TURN
    // - pause en flips/unflips/removes/check
    // - reset opcional (no se usa aquí)
    always_comb begin
        turn_load_15 = (s == S_NEW_TURN);
        turn_start   = (s == S_NEW_TURN);
        turn_reset   = 1'b0;
        unique case (s)
            S_DO_FLIP1, S_WAIT_FLIP1,
            S_DO_FLIP2, S_WAIT_FLIP2,
            S_CHECK,
            S_MATCH_REM_A, S_MATCH_WAIT_A,
            S_MATCH_REM_B, S_MATCH_WAIT_B,
            S_MISS_UNF_A,  S_MISS_WAIT_A,
            S_MISS_UNF_B,  S_MISS_WAIT_B: turn_pause = 1'b1;
            default:                        turn_pause = 1'b0;
        endcase
    end

    // Salidas por defecto
    always_comb begin
        // defaults
        req_flip        = 1'b0;
        req_unflip      = 1'b0;
        req_remove_pair = 1'b0;
        act_idx         = 4'd0;

        pair_start      = 1'b0;
        enable_random   = 1'b0;
        update_score    = 1'b0;

        ns = s;

        unique case (s)
            // -------------- BOOT / START --------------
            S_IDLE: begin
                if (start_game) ns = S_WAIT_START;
            end

            S_WAIT_START: begin
                ns = S_NEW_TURN;
            end

            // -------------- NUEVO TURNO ---------------
            S_NEW_TURN: begin
                ns = S_PICK1;
            end

            // -------------- PICK #1 -------------------
            S_PICK1: begin
                if (select_e && can_flip_sel) ns = S_PREP_FLIP1;
                else if (timer_done)          ns = S_AUTO1;
            end

            S_AUTO1: begin
					enable_random = 1'b1;
					if (rnd_valid && can_flip_idx_any) ns = S_PREP_FLIP1;
				end

            S_PREP_FLIP1: begin
                ns = S_DO_FLIP1;
            end

            S_DO_FLIP1: begin
                act_idx  = idx_target;
                req_flip = 1'b1;
                ns       = S_WAIT_FLIP1;
            end

            S_WAIT_FLIP1: begin
                act_idx = idx_target;
                if (flip_ack) ns = S_PICK2;
            end

            // -------------- PICK #2 -------------------
            S_PICK2: begin
                if (select_e && can_flip_sel && (sel_idx!=idx_a)) ns = S_PREP_FLIP2;
                else if (timer_done)                               ns = S_AUTO2;
            end

            S_AUTO2: begin
					enable_random = 1'b1;
					if (rnd_valid && (rnd_idx!=idx_a) && can_flip_idx_any) ns = S_PREP_FLIP2;
				end

            S_PREP_FLIP2: begin
                ns = S_DO_FLIP2;
            end

            S_DO_FLIP2: begin
                act_idx  = idx_target;
                req_flip = 1'b1;
                ns       = S_WAIT_FLIP2;
            end

            S_WAIT_FLIP2: begin
                act_idx = idx_target;
                if (flip_ack) ns = S_CHECK;
            end

            // -------------- CHECK ---------------------
            S_CHECK: begin
                pair_start = 1'b1;   // pulso 1 ciclo
                // se queda 1 ciclo y evalúa en secuencial con pair_done
                ns = S_CHECK;
                if (pair_done) begin
                    if (pair_match) ns = S_MATCH_REM_A;
                    else            ns = S_MISS_UNF_A;
                end
            end

            // -------------- MATCH PATH ----------------
            S_MATCH_REM_A: begin
                act_idx          = idx_a;
                req_remove_pair  = 1'b1;
                ns               = S_MATCH_WAIT_A;
            end
            S_MATCH_WAIT_A: begin
                if (remove_ack) ns = S_MATCH_REM_B;
            end
            S_MATCH_REM_B: begin
                act_idx          = idx_b;
                req_remove_pair  = 1'b1;
                ns               = S_MATCH_WAIT_B;
            end
            S_MATCH_WAIT_B: begin
                if (remove_ack) ns = S_NEXT_SAME;
            end
            S_NEXT_SAME: begin
                // el mismo jugador sigue
                update_score = 1'b1;
                if (all_pairs_done) ns = S_GAMEOVER;
                else                ns = S_NEW_TURN;
            end

            // -------------- MISS PATH -----------------
            S_MISS_UNF_A: begin
                act_idx    = idx_a;
                req_unflip = 1'b1;
                ns         = S_MISS_WAIT_A;
            end
            S_MISS_WAIT_A: begin
                if (unflip_ack) ns = S_MISS_UNF_B;
            end
            S_MISS_UNF_B: begin
                act_idx    = idx_b;
                req_unflip = 1'b1;
                ns         = S_MISS_WAIT_B;
            end
            S_MISS_WAIT_B: begin
                if (unflip_ack) ns = S_NEXT_PLAYER;
            end
            S_NEXT_PLAYER: begin
                ns = S_NEW_TURN; // toggle en secuencial
            end

            // -------------- GAME OVER -----------------
            S_GAMEOVER: begin
                // se queda aquí hasta reset
                ns = S_GAMEOVER;
                if (start_game) ns = S_IDLE; // opcional: reinicio por start
            end

            default: ns = S_IDLE;
        endcase
    end

    // Secuencial: estado + registros de picks y control
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            s          <= S_IDLE;
            cur_player <= 1'b0;   // P1
            idx_a      <= '0;
            idx_b      <= '0;
            idx_target <= '0;
            last_match <= 1'b0;
        end else begin
            s <= ns;

            // Latch del índice a flippear en PREP (según origen: AUTO o CLICK)
            if (ns == S_PREP_FLIP1) begin
                idx_target <= (s==S_AUTO1) ? rnd_idx : sel_idx;
            end
            if (ns == S_PREP_FLIP2) begin
                idx_target <= (s==S_AUTO2) ? rnd_idx : sel_idx;
            end

            // Confirmación de flips (cuando llega flip_ack en WAIT)
            if (s == S_WAIT_FLIP1 && flip_ack) begin
                idx_a <= idx_target;
            end
            if (s == S_WAIT_FLIP2 && flip_ack) begin
                idx_b <= idx_target;
            end

            // Captura del resultado de comparación cuando llega pair_done
            if (s == S_CHECK && pair_done) begin
                last_match <= pair_match;
            end

            // Toggle de jugador solo en final de MISS path
            if (s == S_NEXT_PLAYER) begin
                cur_player <= ~cur_player;
            end
        end
    end

endmodule
