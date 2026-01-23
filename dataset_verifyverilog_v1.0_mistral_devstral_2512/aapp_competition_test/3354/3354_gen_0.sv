module pickle_sandwich (
    input [31:0] s,
    input [31:0] r,
    input [3:0] n,
    input [6:0] z,
    output reg [3:0] result
);

    localparam [31:0] THRESH_1 = 32'h00010000;
    localparam [31:0] THRESH_2 = 32'h00020000;
    localparam [31:0] THRESH_3 = 32'h000228D6;
    localparam [31:0] THRESH_4 = 32'h00026A0A;
    localparam [31:0] THRESH_5 = 32'h0002B374;
    localparam [31:0] THRESH_6 = 32'h00030000;

    reg [3:0] max_by_area;
    reg [3:0] max_by_packing;
    wire [63:0] s_sq;
    wire [63:0] r_sq;
    wire [63:0] numerator;
    wire [63:0] denominator;

    assign s_sq = {16'b0, s} * {16'b0, s};
    assign r_sq = {16'b0, r} * {16'b0, r};
    assign numerator = z * s_sq;
    assign denominator = r_sq * 7'h64;

    always @(*) begin
        if (denominator == 0) begin
            max_by_area = 0;
        end else begin
            max_by_area = numerator / denominator;
            if (max_by_area > 7) max_by_area = 7;
        end
    end

    always @(*) begin
        if (s >= r * THRESH_6) begin
            max_by_packing = 7;
        end else if (s >= r * THRESH_5) begin
            max_by_packing = 5;
        end else if (s >= r * THRESH_4) begin
            max_by_packing = 4;
        end else if (s >= r * THRESH_3) begin
            max_by_packing = 3;
        end else if (s >= r * THRESH_2) begin
            max_by_packing = 2;
        end else if (s >= r * THRESH_1) begin
            max_by_packing = 1;
        end else begin
            max_by_packing = 0;
        end
    end

    always @(*) begin
        result = n;
        if (max_by_area < result) result = max_by_area;
        if (max_by_packing < result) result = max_by_packing;
    end

endmodule