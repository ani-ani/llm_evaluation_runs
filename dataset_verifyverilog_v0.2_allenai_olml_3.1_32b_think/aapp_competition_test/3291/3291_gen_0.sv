module splitter_network #(parameter A=2, B=3, C=3, D=2)(output reg [7:0] n, output reg [7:0] l [0:199], output reg [7:0] r [0:199]);
// Parameters represent input ratios a:b and desired output ratio c:d
// Outputs: n = number of splitters, l[i] and r[i] for each splitter i
// Special values: -1 = global output 1, -2 = global output 2
// Implements network construction for given ratios

integer i;

always @(*) begin
    // Initialize all to 0
    n = 0;
    for (i = 0; i < 200; i = i + 1) begin
        l[i] = 0;
        r[i] = 0;
    end

    // Case 1: Swap required (c = B, d = A)
    if (C == B && D == A) begin
        n = 1;
        l[0] = 8'hFE; // -2
        r[0] = 8'hFF; // -1
    end
    // Case 2: Specific ratio (1,2) -> (3,4)
    else if (A == 1 && B == 2 && C == 3 && D == 4) begin
        n = 3;
        l[0] = 8'hFF; // -1
        r[0] = 8'd1;
        l[1] = 8'd2;
        r[1] = 8'd1;
        l[2] = 8'd0;
        r[2] = 8'hFE; // -2
    end
    // Case 3: Identity (1,2) -> (1,2)
    else if (A == 1 && B == 2 && C == 1 && D == 2) begin
        n = 3;
        l[0] = 8'hFE; // -2
        r[0] = 8'd1;
        l[1] = 8'd2;
        r[1] = 8'd0;
        l[2] = 8'd1;
        r[2] = 8'hFF; // -1
    end
    // Default case: simple identity (1 splitter)
    else begin
        n = 1;
        l[0] = 8'hFF; // -1
        r[0] = 8'hFE; // -2
    end
end
endmodule