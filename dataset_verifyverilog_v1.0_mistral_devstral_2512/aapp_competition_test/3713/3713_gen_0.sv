module longest_alternating_subsequence(
    input [4:0] n,
    input [15:0] s,
    output reg [4:0] result
);

    integer i;
    reg [4:0] changes;

    always @(*) begin
        changes = 5'd0;
        for (i = 0; i < 15; i = i + 1) begin
            if (i < n - 1) begin
                if (s[i] != s[i + 1]) begin
                    changes = changes + 5'd1;
                end
            end
        end
        if (changes + 5'd3 > n) begin
            result = n;
        end else begin
            result = changes + 5'd3;
        end
    end

endmodule