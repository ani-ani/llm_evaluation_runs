module longest_alternating_subsequence(
    input [4:0] n,
    input [15:0] s,
    output reg [4:0] result
);

integer i;
reg [4:0] changes;

always @(*) begin
    changes = 5'd0;
    // Count adjacent differences for i from 0 to n-2
    for (i = 0; i < 16; i = i + 1) begin
        if (i < n - 5'd1) begin
            if (s[i] != s[i + 5'd1])
                changes = changes + 5'd1;
        end
    end
    // Compute result = min(n, changes + 3)
    if (changes + 5'd3 > n)
        result = n;
    else
        result = changes + 5'd3;
end

endmodule