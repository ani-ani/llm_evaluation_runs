module min_distance (
    input [3:0] n,          // 2..8
    input signed [7:0] a0, a1, a2, a3, a4, a5, a6, a7,
    output reg [31:0] result
);
    // Prefix sums (16 bits sufficient for 8*100=800)
    wire signed [15:0] p0, p1, p2, p3, p4, p5, p6, p7, p8;
    assign p0 = 16'd0;
    assign p1 = a0;
    assign p2 = a0 + a1;
    assign p3 = a0 + a1 + a2;
    assign p4 = a0 + a1 + a2 + a3;
    assign p5 = a0 + a1 + a2 + a3 + a4;
    assign p6 = a0 + a1 + a2 + a3 + a4 + a5;
    assign p7 = a0 + a1 + a2 + a3 + a4 + a5 + a6;
    assign p8 = a0 + a1 + a2 + a3 + a4 + a5 + a6 + a7;

    // Compute all pairwise distances
    wire signed [3:0] dx12 = 4'd1 - 4'd2;
    wire signed [15:0] dy12 = p1 - p2;
    wire [31:0] dist12 = dx12*dx12 + dy12*dy12;

    wire signed [3:0] dx13 = 4'd1 - 4'd3;
    wire signed [15:0] dy13 = p1 - p3;
    wire [31:0] dist13 = dx13*dx13 + dy13*dy13;

    wire signed [3:0] dx14 = 4'd1 - 4'd4;
    wire signed [15:0] dy14 = p1 - p4;
    wire [31:0] dist14 = dx14*dx14 + dy14*dy14;

    wire signed [3:0] dx15 = 4'd1 - 4'd5;
    wire signed [15:0] dy15 = p1 - p5;
    wire [31:0] dist15 = dx15*dx15 + dy15*dy15;

    wire signed [3:0] dx16 = 4'd1 - 4'd6;
    wire signed [15:0] dy16 = p1 - p6;
    wire [31:0] dist16 = dx16*dx16 + dy16*dy16;

    wire signed [3:0] dx17 = 4'd1 - 4'd7;
    wire signed [15:0] dy17 = p1 - p7;
    wire [31:0] dist17 = dx17*dx17 + dy17*dy17;

    wire signed [3:0] dx18 = 4'd1 - 4'd8;
    wire signed [15:0] dy18 = p1 - p8;
    wire [31:0] dist18 = dx18*dx18 + dy18*dy18;

    wire signed [3:0] dx23 = 4'd2 - 4'd3;
    wire signed [15:0] dy23 = p2 - p3;
    wire [31:0] dist23 = dx23*dx23 + dy23*dy23;

    wire signed [3:0] dx24 = 4'd2 - 4'd4;
    wire signed [15:0] dy24 = p2 - p4;
    wire [31:0] dist24 = dx24*dx24 + dy24*dy24;

    wire signed [3:0] dx25 = 4'd2 - 4'd5;
    wire signed [15:0] dy25 = p2 - p5;
    wire [31:0] dist25 = dx25*dx25 + dy25*dy25;

    wire signed [3:0] dx26 = 4'd2 - 4'd6;
    wire signed [15:0] dy26 = p2 - p6;
    wire [31:0] dist26 = dx26*dx26 + dy26*dy26;

    wire signed [3:0] dx27 = 4'd2 - 4'd7;
    wire signed [15:0] dy27 = p2 - p7;
    wire [31:0] dist27 = dx27*dx27 + dy27*dy27;

    wire signed [3:0] dx28 = 4'd2 - 4'd8;
    wire signed [15:0] dy28 = p2 - p8;
    wire [31:0] dist28 = dx28*dx28 + dy28*dy28;

    wire signed [3:0] dx34 = 4'd3 - 4'd4;
    wire signed [15:0] dy34 = p3 - p4;
    wire [31:0] dist34 = dx34*dx34 + dy34*dy34;

    wire signed [3:0] dx35 = 4'd3 - 4'd5;
    wire signed [15:0] dy35 = p3 - p5;
    wire [31:0] dist35 = dx35*dx35 + dy35*dy35;

    wire signed [3:0] dx36 = 4'd3 - 4'd6;
    wire signed [15:0] dy36 = p3 - p6;
    wire [31:0] dist36 = dx36*dx36 + dy36*dy36;

    wire signed [3:0] dx37 = 4'd3 - 4'd7;
    wire signed [15:0] dy37 = p3 - p7;
    wire [31:0] dist37 = dx37*dx37 + dy37*dy37;

    wire signed [3:0] dx38 = 4'd3 - 4'd8;
    wire signed [15:0] dy38 = p3 - p8;
    wire [31:0] dist38 = dx38*dx38 + dy38*dy38;

    wire signed [3:0] dx45 = 4'd4 - 4'd5;
    wire signed [15:0] dy45 = p4 - p5;
    wire [31:0] dist45 = dx45*dx45 + dy45*dy45;

    wire signed [3:0] dx46 = 4'd4 - 4'd6;
    wire signed [15:0] dy46 = p4 - p6;
    wire [31:0] dist46 = dx46*dx46 + dy46*dy46;

    wire signed [3:0] dx47 = 4'd4 - 4'd7;
    wire signed [15:0] dy47 = p4 - p7;
    wire [31:0] dist47 = dx47*dx47 + dy47*dy47;

    wire signed [3:0] dx48 = 4'd4 - 4'd8;
    wire signed [15:0] dy48 = p4 - p8;
    wire [31:0] dist48 = dx48*dx48 + dy48*dy48;

    wire signed [3:0] dx56 = 4'd5 - 4'd6;
    wire signed [15:0] dy56 = p5 - p6;
    wire [31:0] dist56 = dx56*dx56 + dy56*dy56;

    wire signed [3:0] dx57 = 4'd5 - 4'd7;
    wire signed [15:0] dy57 = p5 - p7;
    wire [31:0] dist57 = dx57*dx57 + dy57*dy57;

    wire signed [3:0] dx58 = 4'd5 - 4'd8;
    wire signed [15:0] dy58 = p5 - p8;
    wire [31:0] dist58 = dx58*dx58 + dy58*dy58;

    wire signed [3:0] dx67 = 4'd6 - 4'd7;
    wire signed [15:0] dy67 = p6 - p7;
    wire [31:0] dist67 = dx67*dx67 + dy67*dy67;

    wire signed [3:0] dx68 = 4'd6 - 4'd8;
    wire signed [15:0] dy68 = p6 - p8;
    wire [31:0] dist68 = dx68*dx68 + dy68*dy68;

    wire signed [3:0] dx78 = 4'd7 - 4'd8;
    wire signed [15:0] dy78 = p7 - p8;
    wire [31:0] dist78 = dx78*dx78 + dy78*dy78;

    // Find minimum among valid pairs (i<=n, j<=n)
    always @(*) begin
        result = 32'hFFFF_FFFF;
        if (n >= 2) begin
            if (1 <= n && 2 <= n && dist12 < result) result = dist12;
            if (1 <= n && 3 <= n && dist13 < result) result = dist13;
            if (1 <= n && 4 <= n && dist14 < result) result = dist14;
            if (1 <= n && 5 <= n && dist15 < result) result = dist15;
            if (1 <= n && 6 <= n && dist16 < result) result = dist16;
            if (1 <= n && 7 <= n && dist17 < result) result = dist17;
            if (1 <= n && 8 <= n && dist18 < result) result = dist18;
            if (2 <= n && 3 <= n && dist23 < result) result = dist23;
            if (2 <= n && 4 <= n && dist24 < result) result = dist24;
            if (2 <= n && 5 <= n && dist25 < result) result = dist25;
            if (2 <= n && 6 <= n && dist26 < result) result = dist26;
            if (2 <= n && 7 <= n && dist27 < result) result = dist27;
            if (2 <= n && 8 <= n && dist28 < result) result = dist28;
            if (3 <= n && 4 <= n && dist34 < result) result = dist34;
            if (3 <= n && 5 <= n && dist35 < result) result = dist35;
            if (3 <= n && 6 <= n && dist36 < result) result = dist36;
            if (3 <= n && 7 <= n && dist37 < result) result = dist37;
            if (3 <= n && 8 <= n && dist38 < result) result = dist38;
            if (4 <= n && 5 <= n && dist45 < result) result = dist45;
            if (4 <= n && 6 <= n && dist46 < result) result = dist46;
            if (4 <= n && 7 <= n && dist47 < result) result = dist47;
            if (4 <= n && 8 <= n && dist48 < result) result = dist48;
            if (5 <= n && 6 <= n && dist56 < result) result = dist56;
            if (5 <= n && 7 <= n && dist57 < result) result = dist57;
            if (5 <= n && 8 <= n && dist58 < result) result = dist58;
            if (6 <= n && 7 <= n && dist67 < result) result = dist67;
            if (6 <= n && 8 <= n && dist68 < result) result = dist68;
            if (7 <= n && 8 <= n && dist78 < result) result = dist78;
        end
    end
endmodule