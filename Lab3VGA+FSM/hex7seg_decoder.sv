// hex7seg_decoder.sv
module hex7seg_decoder #(
  parameter bit ACTIVE_LOW = 1
)(
  input  logic [3:0] val,   // 0..15
  output logic [6:0] seg    // {a,b,c,d,e,f,g}
);
  logic [6:0] seg_hi;       // activo-alto interno

  always_comb begin
    unique case (val)
      4'h0: seg_hi = 7'b1111110;
      4'h1: seg_hi = 7'b0110000;
      4'h2: seg_hi = 7'b1101101;
      4'h3: seg_hi = 7'b1111001;
      4'h4: seg_hi = 7'b0110011;
      4'h5: seg_hi = 7'b1011011;
      4'h6: seg_hi = 7'b1011111;
      4'h7: seg_hi = 7'b1110000;
      4'h8: seg_hi = 7'b1111111;
      4'h9: seg_hi = 7'b1111011;
      4'hA: seg_hi = 7'b1110111; // A
      4'hB: seg_hi = 7'b0011111; // b
      4'hC: seg_hi = 7'b1001110; // C
      4'hD: seg_hi = 7'b0111101; // d
      4'hE: seg_hi = 7'b1001111; // E
      4'hF: seg_hi = 7'b1000111; // F
      default: seg_hi = 7'b0000000;
    endcase
  end

  assign seg = (ACTIVE_LOW) ? ~seg_hi : seg_hi;
endmodule
