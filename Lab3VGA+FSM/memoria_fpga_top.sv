module memoria_fpga_top (
    input  logic        clk50,
    input  logic [3:0]  SW,           // sel_idx[3:0]
    input  logic        KEY0_n,       // START  (act-bajo)
    input  logic        KEY1_n,       // CLICK  (act-bajo)
    input  logic        RESET_n,      // reset global act-bajo

    // VGA
    output logic        vgaclk,
    output logic        hsync, vsync,
    output logic        sync_b, blank_b,
    output logic [7:0]  r, g, b,

    // LEDs de turno
    output logic        LED_P1,
    output logic        LED_P2,

    // Pares por jugador (opcional en LEDs externos)
    output logic [3:0]  P1_PAIRS,
    output logic [3:0]  P2_PAIRS,

    // 7 segmentos (activo-en-bajo): HEX0=P1, HEX1=P2
    output logic [6:0]  HEX0,
    output logic [6:0]  HEX1
);
    // ---------------- Clocks VGA ----------------
    pll u_pll(.inclk0(clk50), .c0(vgaclk));

    logic [9:0] x, y;
    vgaController u_vgac (
        .vgaclk (vgaclk),
        .hsync  (hsync),
        .vsync  (vsync),
        .sync_b (sync_b),
        .blank_b(blank_b),
        .x      (x),
        .y      (y)
    );

    // ---------------- Front-end de entrada ----------------
    logic start_level, start_pulse;
    logic click_level, click_pulse;

    btn_debouncer #(.CNTR_BITS(18)) u_db_start (
        .clk        (clk50),
        .rst_n      (RESET_n),
        .btn_n_raw  (KEY0_n),
        .level      (start_level),
        .rising_edge(start_pulse)
    );

    btn_debouncer #(.CNTR_BITS(18)) u_db_click (
        .clk        (clk50),
        .rst_n      (RESET_n),
        .btn_n_raw  (KEY1_n),
        .level      (click_level),
        .rising_edge(click_pulse)
    );

    // ---------------- Lógica del juego ----------------
    logic        show_winner_o;
    logic [15:0] card_faceup_o, card_removed_o;
    logic        current_player_o;

    logic [3:0] p1_pairs_o, p2_pairs_o;

    memory_game_top_bc #(
      .TICKS_PER_TURN(300)
    ) u_game (
      .clk             (clk50),
      .rst_n           (RESET_n),

      .start_btn       (start_pulse),
      .click_e         (click_pulse),
      .sel_idx         (SW[3:0]),

      .show_winner_o   (show_winner_o),
      .card_faceup_o   (card_faceup_o),
      .card_removed_o  (card_removed_o),
      .current_player_o(current_player_o),

      .p1_pairs_o      (p1_pairs_o),
      .p2_pairs_o      (p2_pairs_o)
    );

    // ---------------- LEDs de turno ----------------
    turn_leds u_leds (
      .clk            (clk50),
      .rst_n          (RESET_n),
      .game_active    (!show_winner_o),   // encendidos solo durante el juego
      .current_player (current_player_o),
      .led_p1         (LED_P1),
      .led_p2         (LED_P2)
    );

    // Exporta contadores crudos (LEDs externos opcionales)
    assign P1_PAIRS = p1_pairs_o;
    assign P2_PAIRS = p2_pairs_o;

    // ---------------- 7-segmentos: P1 -> HEX0, P2 -> HEX1 ----------------
    // Decoder activo-en-bajo, orden {a,b,c,d,e,f,g}
    hex7seg_active_low u_hex_p1 (
      .hex (p1_pairs_o),
      .seg (HEX0)
    );

    hex7seg_active_low u_hex_p2 (
      .hex (p2_pairs_o),
      .seg (HEX1)
    );

    // ---------------- Video de juego ----------------
    videoGen_game u_vgen (
        .vgaclk       (vgaclk),
        .blank_b      (blank_b),
        .x            (x),
        .y            (y),
        .faceup_mask  (card_faceup_o),
        .removed_mask (card_removed_o),
        .sel_idx      (SW[3:0]),
        .show_winner  (show_winner_o),
        .r            (r),
        .g            (g),
        .b            (b)
    );
endmodule

