// turn_leds.sv
module turn_leds (
  input  logic clk,
  input  logic rst_n,
  input  logic game_active,     // 1 durante el juego
  input  logic current_player,  // 0 = P1, 1 = P2
  output logic led_p1,
  output logic led_p2
);
  logic [25:0] div_q;  // ~0.7 Hz @50MHz (ajusta el bit para variar la frecuencia)
  logic        blink;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) div_q <= '0;
    else        div_q <= div_q + 26'd1;
  end

  assign blink = div_q[25];

  always_comb begin
    led_p1 = 1'b0;
    led_p2 = 1'b0;
    if (game_active) begin
      // Parpadeo del LED del jugador activo
      if (current_player == 1'b0) led_p1 = blink;
      else                        led_p2 = blink;
    end
  end
endmodule

