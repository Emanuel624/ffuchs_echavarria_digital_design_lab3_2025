module vgaController #(
    parameter HACTIVE = 10'd640,
              HFP     = 10'd16,
              HSYN    = 10'd96,
              HBP     = 10'd48,
              HMAX    = HACTIVE + HFP + HSYN + HBP, // 800

              VBP     = 10'd33,
              VACTIVE = 10'd480,
              VFP     = 10'd10,
              VSYN    = 10'd2,
              VMAX    = VACTIVE + VFP + VSYN + VBP   // 525
)(
    input  logic       vgaclk,
    output logic       hsync, vsync,
    output logic       sync_b, blank_b,
    output logic [9:0] x, y
);
    initial begin x=10'd0; y=10'd0; end

    // x:0..799  y:0..524
    always_ff @(posedge vgaclk) begin
        if (x == HMAX-1) begin
            x <= 10'd0;
            y <= (y == VMAX-1) ? 10'd0 : (y + 10'd1);
        end else begin
            x <= x + 10'd1;
        end
    end

    assign hsync   = ~((x >= HACTIVE + HFP) && (x < HACTIVE + HFP + HSYN)); // activo-bajo
    assign vsync   = ~((y >= VACTIVE + VFP) && (y < VACTIVE + VFP + VSYN)); // activo-bajo
    assign sync_b  = hsync & vsync;
    assign blank_b = (x < HACTIVE) && (y < VACTIVE); // <<---  define 640×48
endmodule
