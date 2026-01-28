module move_sequences (
    input wire [63:0] a11,
    input wire [63:0] a12,
    input wire [63:0] a21,
    input wire [63:0] a22,
    input wire [63:0] N,
    output reg [63:0] result
);

    localparam [63:0] MOD = 1000000007;

    // Combinational logic for computation
    always @(*) begin
        reg [63:0] P;
        reg [63:0] part1;
        reg [63:0] part2;
        reg [63:0] temp_result;
        reg [63:0] base;
        reg [63:0] exp;
        reg [63:0] b;
        reg [63:0] e;
        integer i;
        
        // Default result
        temp_result = 0;
        
        // Check if all players have the same type (only one player type is non-zero)
        if ((a11 > 0 && a12 == 0 && a21 == 0 && a22 == 0) ||
            (a12 > 0 && a11 == 0 && a21 == 0 && a22 == 0) ||
            (a21 > 0 && a11 == 0 && a12 == 0 && a22 == 0) ||
            (a22 > 0 && a11 == 0 && a12 == 0 && a21 == 0)) begin
            
            // Determine P
            if (a11 > 0) P = a11;
            else if (a12 > 0) P = a12;
            else if (a21 > 0) P = a21;
            else P = a22;
            
            if (N == 0) begin
                temp_result = 1;
            end else if (P < 2) begin
                temp_result = 0;
            end else if (N == 1) begin
                temp_result = (P * (P - 1)) % MOD;
            end else begin
                // Compute P * (P-1) % MOD
                part1 = (P * (P - 1)) % MOD;
                
                // Compute mod_pow(P-2, N-1) manually
                base = (P - 2) % MOD;
                exp = N - 1;
                b = base;
                e = exp;
                part2 = 1;
                
                for (i = 0; i < 64; i = i + 1) begin
                    if (e == 0) begin
                        // Loop complete
                    end else begin
                        if (e[0] == 1) begin
                            part2 = (part2 * b) % MOD;
                        end
                        b = (b * b) % MOD;
                        e = e >> 1;
                    end
                end
                
                temp_result = (part1 * part2) % MOD;
            end
        end else begin
            // Mixed types - output 0 (simplified case)
            temp_result = 0;
        end
        
        result = temp_result;
    end

endmodule