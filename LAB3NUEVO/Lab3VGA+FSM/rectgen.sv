module rectgen(
    input  logic [9:0] x, y, left, right, top, bot,
    output logic       inrect
);
    assign inrect = (x >= left) & (x < right) & (y >= top) & (y < bot);
endmodule

module pll (
    input  logic inclk0,
    output logic c0
);
    logic toggle;
    initial toggle = 1'b0;
    always_ff @(posedge inclk0) toggle <= ~toggle;
    assign c0 = toggle;
endmodule