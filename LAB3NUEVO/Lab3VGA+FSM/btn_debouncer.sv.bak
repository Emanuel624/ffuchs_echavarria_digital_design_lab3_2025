// Debouncer simple (sincroniza a clk y filtra durante N ciclos)
module btn_debouncer #(
  parameter integer CNTR_BITS = 18       // ~2.6 ms a 50 MHz
)(
  input  logic clk,
  input  logic rst_n,
  input  logic btn_n_raw,                // botón activo en bajo típico de placa
  output logic level,                    // nivel estable (activo en alto)
  output logic rising_edge               // pulso 1 ciclo al presionar
);
  logic        btn_sync0, btn_sync1;
  logic [CNTR_BITS-1:0] cnt_q;
  logic        stable_q;

  // sincronizadores
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      btn_sync0 <= 1'b1;
      btn_sync1 <= 1'b1;
    end else begin
      btn_sync0 <= btn_n_raw;
      btn_sync1 <= btn_sync0;
    end
  end

  // filtro (cuenta mientras cambie)
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      cnt_q    <= '0;
      stable_q <= 1'b1;
    end else begin
      if (btn_sync1 != stable_q) begin
        cnt_q <= cnt_q + 1'b1;
        if (&cnt_q) begin
          stable_q <= btn_sync1;
          cnt_q    <= '0;
        end
      end else begin
        cnt_q <= '0;
      end
    end
  end

  // activo alto (invertimos porque btn_n_raw es activo-bajo)
  logic level_q, level_d;
  always_comb level_d = ~stable_q;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      level_q <= 1'b0;
    end else begin
      level_q <= level_d;
    end
  end

  assign level       = level_q;
  assign rising_edge = level_d & ~level_q; // flanco de subida
endmodule
