//==============================================================
// scoreboard_pairs.sv
// - Cuenta parejas por jugador.
// - Resetea con rst_n=0 o start_game=1.
// - Incrementa en update_score (según current_player).
// - Opcional: congela cuando show_winner=1.
//==============================================================
module scoreboard_pairs (
  input  logic       clk,
  input  logic       rst_n,

  // Control
  input  logic       start_game,       // pulso/level al iniciar juego
  input  logic       update_score,     // pulso 1 ciclo por pareja encontrada
  input  logic       current_player,   // 0=P1, 1=P2
  input  logic       show_winner,      // 1 cuando terminó el juego (congela)

  // Salidas
  output logic [3:0] p1_pairs,
  output logic [3:0] p2_pairs
);

  // Reset sincrónico por start_game + reset asíncrono por rst_n
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      p1_pairs <= 4'd0;
      p2_pairs <= 4'd0;
    end else begin
      // limpiar al iniciar juego
      if (start_game) begin
        p1_pairs <= 4'd0;
        p2_pairs <= 4'd0;
      end else begin
        // contar si hay punto y no estamos en fin de juego
        if (update_score && !show_winner) begin
          if (!current_player) begin
            // P1 anota
            if (p1_pairs != 4'd15) p1_pairs <= p1_pairs + 4'd1; // saturado
          end else begin
            // P2 anota
            if (p2_pairs != 4'd15) p2_pairs <= p2_pairs + 4'd1; // saturado
          end
        end
      end
    end
  end

endmodule


