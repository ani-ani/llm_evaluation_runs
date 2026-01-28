module pickle_sandwich (
    input [31:0] s,           // Q16.16 fixed-point radius of sandwich
    input [31:0] r,           // Q16.16 fixed-point radius of pickle
    input [3:0] n,            // number of pickles available (0-7)
    input [6:0] z,            // max area percentage (0-100)
    output reg [3:0] result   // maximum number of pickles that can be placed
);

    // Q16.16 constants for thresholds (s/r ratios)
    localparam [31:0] THRESH_1 = 32'h00010000;  // 1.0
    localparam [31:0] THRESH_2 = 32'h00020000;  // 2.0
    localparam [31:0] THRESH_3 = 32'h000228D6;  // 2.1547
    localparam [31:0] THRESH_4 = 32'h00026A0A;  // 2.4142
    localparam [31:0] THRESH_5 = 32'h0002B374;  // 2.7013
    localparam [31:0] THRESH_6 = 32'h00030000;  // 3.0
    
    // Internal signals
    reg [3:0] max_by_area;
    reg [3:0] max_by_packing;
    wire [63:0] s_sq;
    wire [63:0] r_sq;
    wire [63:0] numerator;
    wire [63:0] denominator;
    reg [63:0] temp_val;
    
    // Compute s² and r² (Q32.32 format after multiplication)
    assign s_sq = {16'b0, s} * {16'b0, s};  // s * s
    assign r_sq = {16'b0, r} * {16'b0, r};  // r * r
    
    // Compute numerator = z * s²
    assign numerator = z * s_sq;
    
    // Compute denominator = r² * 100
    assign denominator = r_sq * 7'h64;  // 100 in hex
    
    // Area constraint: max_by_area = floor((z * s²) / (r² * 100))
    // Divide and take floor, ensure result fits in 4 bits (max 7)
    always @(*) begin
        if (denominator == 64'd0) begin
            max_by_area = 4'd0;
        end else begin
            // Perform division and clamp to 4 bits
            temp_val = numerator / denominator;
            if (temp_val > 64'd7) begin
                max_by_area = 4'd7;
            end else begin
                max_by_area = temp_val[3:0];
            end
        end
    end
    
    // Packing constraint: check thresholds for s/r ratio
    // We compare s and r scaled by thresholds to avoid division
    always @(*) begin
        // Check from largest to smallest threshold
        // s >= r * THRESH_6 means s/r >= 3.0
        if (s >= (r * THRESH_6[31:16])) begin  // r * 3.0
            max_by_packing = 4'd7;  // Can fit 6 or 7, we take max
        end else if (s >= (r * THRESH_5[31:16])) begin  // r * 2.7013
            max_by_packing = 4'd5;  // Can fit 5, but not 6
        end else if (s >= (r * THRESH_4[31:16])) begin  // r * 2.4142
            max_by_packing = 4'd4;
        end else if (s >= (r * THRESH_3[31:16])) begin  // r * 2.1547
            max_by_packing = 4'd3;
        end else if (s >= (r * THRESH_2[31:16])) begin  // r * 2.0
            max_by_packing = 4'd2;
        end else if (s >= (r * THRESH_1[31:16])) begin  // r * 1.0
            max_by_packing = 4'd1;
        end else begin
            max_by_packing = 4'd0;
        end
    end
    
    // Final result: minimum of n, max_by_area, and max_by_packing
    always @(*) begin
        result = n;
        if (max_by_area < result) result = max_by_area;
        if (max_by_packing < result) result = max_by_packing;
    end

endmodule