module lex_string (
    input [5:0] n,         // String length (1-64)
    input [2:0] k,          // Distinct letters (1-8)
    output reg valid,       // 1 if inputs valid
    output reg [511:0] string_data // 64-byte string (8 bits/char, little-endian)
);

integer i;

always @(*) begin
    // Validate inputs: k must be 1-8, n≥k, and if k=1 then n=1
    if (k < 1 || k > 8 || n < k || (k == 1 && n != 1)) begin
        valid = 0;
        string_data = 512'd0;
    end else begin
        valid = 1;
        string_data = 512'd0; // Initialize to zeros
        
        // Generate string: first (n - k + 2) chars: alternating 'a' and 'b'
        // Remaining (k - 2) chars: distinct letters starting from 'c'
        for (i = 0; i < 64; i = i + 1) begin
            if (i < n) begin
                if (i < n - k + 2) begin
                    // Alternating pattern: 'a' for even indices, 'b' for odd
                    string_data[8*i +: 8] = (i % 2 == 0) ? 8'h61 : 8'h62;
                end else begin
                    // Distinct part: 'c' + offset
                    string_data[8*i +: 8] = 8'h63 + (i - (n - k + 2));
                end
            end
        end
    end
end

endmodule