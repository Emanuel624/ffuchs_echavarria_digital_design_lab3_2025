// ============================================================
// tb_memory_game_top_bc.sv  (autochequeo)
// - Reloj 50 MHz
// - Reset, start
// - Prueba de MATCH: (i, i+8) -> REMOVED (+2 en el conteo)
// - Prueba de MISS: (1,2) -> se desvoltean y cambia jugador
// - Prueba de AUTO-PICK: se fuerza timer_done por 1 ciclo (x2)
//   y se verifica que el tablero reaccionó (flip/remove)
// ============================================================
`timescale 1ns/1ps

module tb_memory_game_top_bc;
  timeunit 1ns; timeprecision 1ps;

  // ---------------- DUT I/O ----------------
  logic        clk;
  logic        rst_n;

  logic        start_btn;
  logic        click_e;
  logic [3:0]  sel_idx;

  logic        show_winner_o;
  logic [15:0] card_faceup_o;
  logic [15:0] card_removed_o;
  logic        current_player_o;
  logic [3:0]  p1_pairs_o, p2_pairs_o;
  logic [1:0]  winner_code_o;
  logic [7:0]  seconds_left_o;

  // ---------------- DUT ----------------
  memory_game_top_bc dut (
    .clk            (clk),
    .rst_n          (rst_n),
    .start_btn      (start_btn),
    .click_e        (click_e),
    .sel_idx        (sel_idx),

    .show_winner_o  (show_winner_o),
    .card_faceup_o  (card_faceup_o),
    .card_removed_o (card_removed_o),
    .current_player_o(current_player_o),
    .p1_pairs_o     (p1_pairs_o),
    .p2_pairs_o     (p2_pairs_o),
    .winner_code_o  (winner_code_o),
    .seconds_left_o (seconds_left_o)
  );

  // ---------------- Clock 50 MHz ----------------
  localparam real T_CLK_NS = 20.0;  // 50 MHz
  initial clk = 1'b0;
  always #(T_CLK_NS/2.0) clk = ~clk;

  // ---------------- Utils ----------------
  function automatic int popcount16(input logic [15:0] v);
    int c;
    for (int j=0;j<16;j++) if (v[j]) c++;
    return c;
  endfunction

  function automatic int faceup_count();
    return popcount16(card_faceup_o);
  endfunction

  function automatic int removed_count();
    return popcount16(card_removed_o);
  endfunction

  // ---------------- Tasks auxiliares ----------------

  // Pulso de "start" 1 ciclo
  task automatic pulse_start();
    begin
      start_btn <= 1'b1;
      @(posedge clk);
      start_btn <= 1'b0;
      // deja correr NEW_TURN -> PICK1
      repeat (6) @(posedge clk);
    end
  endtask

  // Click en índice actual (1 ciclo), con margen de pipeline
  task automatic click_once(input [3:0] idx);
    begin
      sel_idx <= idx;
      @(posedge clk);
      click_e <= 1'b1;
      @(posedge clk);
      click_e <= 1'b0;
      // margen para PREP->DO->WAIT + ack
      repeat (8) @(posedge clk);
    end
  endtask

  // Espera hasta que una carta quede faceup o removed (lo que ocurra primero)
  task automatic click_until_flipped_or_removed(input [3:0] idx);
    int guard;
    begin
      if (card_removed_o[idx])
        $fatal(1, "idx %0d ya estaba REMOVED antes del click", idx);

      guard = 0;
      while (!(card_faceup_o[idx] || card_removed_o[idx])) begin
        click_once(idx);
        guard++;
        if (guard > 3000)
          $fatal(1, "Timeout esperando flip/remove en idx %0d", idx);
      end
      // pequeño margen adicional
      repeat (4) @(posedge clk);
    end
  endtask

  // Espera a que el total REMOVED aumente en +2 (pareja completa removida)
  task automatic wait_removed_pair(input [3:0] a, input [3:0] b);
    int removed_before, removed_now;
    int guard;
    begin
      removed_before = removed_count();
      guard = 0;
      do begin
        @(posedge clk);
        removed_now = removed_count();
        guard++;
        if (guard > 20000)
          $fatal(1, "Timeout esperando REMOVED de la pareja (%0d,%0d)", a, b);
      end while (removed_now < removed_before + 2);
      // margen para NEXT_SAME / NEW_TURN
      repeat (6) @(posedge clk);
    end
  endtask

  // Espera a que DOS cartas visibles vuelvan a ocultarse (miss path)
  task automatic wait_unflip_two(input [3:0] a, input [3:0] b);
    int guard;
    begin
      guard = 0;
      while (card_faceup_o[a] || card_faceup_o[b]) begin
        @(posedge clk);
        guard++;
        if (guard > 20000)
          $fatal(1, "Timeout esperando UNFLIP de (%0d,%0d)", a, b);
      end
      // margen para NEXT_PLAYER / NEW_TURN
      repeat (6) @(posedge clk);
    end
  endtask

  // Ejecuta un MATCH seguro sobre (i, i+8)
  task automatic do_match_pair(input [3:0] i);
    begin
      click_until_flipped_or_removed(i);
      click_until_flipped_or_removed(i+4'd8);
      wait_removed_pair(i, i+4'd8);
    end
  endtask

  // Ejecuta un MISS usando (1,2) (no forman pareja en la ROM usada)
  task automatic do_miss();
    logic [3:0] a, b;
    begin
      a = 4'd1; b = 4'd2;
      click_until_flipped_or_removed(a);
      // si justo se removió la primera (no debería), cambia b
      if (card_removed_o[a]) b = 4'd3;
      click_until_flipped_or_removed(b);
      // si por casualidad hicimos match (tampoco debería), aborta este camino
      if (card_removed_o[a] && card_removed_o[b]) begin
        $display("[%0t] Aviso: (1,2) terminó en match accidental, se continúa", $time);
        repeat (6) @(posedge clk);
      end else begin
        wait_unflip_two(a, b);
      end
    end
  endtask

  // Fuerza el timer_done por 1 ciclo para provocar AUTO pick
  task automatic force_timeout_one_cycle();
    begin
      force dut.timer_done = 1'b1;
      @(posedge clk);
      release dut.timer_done;
      @(posedge clk);
    end
  endtask

  // Espera una reacción de autoplay (cambio en faceup o removed)
  task automatic wait_autoplay_reaction();
    int f0, r0, guard;
    begin
      f0 = faceup_count();
      r0 = removed_count();
      guard = 0;
      do begin
        @(posedge clk);
        guard++;
        if (guard > 20000)
          $fatal(1, "Timeout esperando reacción al AUTO pick");
      end while (faceup_count()==f0 && removed_count()==r0);
      repeat (6) @(posedge clk);
    end
  endtask

  // ---------------- Estímulos ----------------
  initial begin
    // init
    rst_n      = 1'b0;
    start_btn  = 1'b0;
    click_e    = 1'b0;
    sel_idx    = 4'd0;

    $display("[%0t] TB start", $time);

    // reset
    repeat (5) @(posedge clk);
    rst_n = 1'b1;
    repeat (5) @(posedge clk);

    // start
    pulse_start();

    // ---- Caso 1: MATCH (3,11) ----
    do_match_pair(4'd3);
    // Verifica marcador y turno retenido
    if (p1_pairs_o != 4'd1 || p2_pairs_o != 4'd0)
      $error("Score tras primer match inválido. P1=%0d P2=%0d", p1_pairs_o, p2_pairs_o);
    if (current_player_o !== 1'b0)
      $error("Tras match, debería conservar turno P1. cur=%0b", current_player_o);

    // ---- Caso 2: MISS (1,2) ----
    do_miss();
    // Debió cambiar el jugador a P2
    if (current_player_o !== 1'b1)
      $error("Miss no cambió de jugador. cur=%0b", current_player_o);

    // ---- Caso 3: AUTO-PICK por timeout ----
    // Forzamos timer_done dos veces para que la FSM haga AUTO1 y AUTO2
    force_timeout_one_cycle();   // debe llevar a S_AUTO1 -> flip
    wait_autoplay_reaction();

    force_timeout_one_cycle();   // debe llevar a S_AUTO2 -> flip y luego CHECK
    wait_autoplay_reaction();

    // No imponemos resultado (puede ser match o miss), sólo comprobamos reacción
    $display("[%0t] Auto-pick ejercido. faceup=%0d removed=%0d",
              $time, faceup_count(), removed_count());

    // Fin de prueba corta
    repeat (50) @(posedge clk);
    $display("[%0t] TB OK (fin)", $time);
    $finish;
  end

endmodule





