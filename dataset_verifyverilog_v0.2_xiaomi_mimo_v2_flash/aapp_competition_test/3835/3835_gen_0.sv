module array_restorer(
    input clk,
    input [31:0] M [0:7][0:7],
    input [2:0] n,
    output reg [31:0] result [0:7]
);

    // State machine
    reg [2:0] state;
    reg [2:0] i;
    reg [5:0] cnt;
    
    // Data path regs
    reg [63:0] A, B, C;
    reg [63:0] prod;
    reg [63:0] rem;
    reg [63:0] sq_rem;
    reg [63:0] sq_root;
    reg [63:0] sq_temp;
    
    // Indices
    wire [2:0] j = (i + 1) % (n == 0 ? 1 : n);
    wire [2:0] k = (i + 2) % (n == 0 ? 1 : n);
    
    always @(posedge clk) begin
        case (state)
            0: begin // Idle
                if (n >= 3) begin
                    i <= 0;
                    state <= 1;
                end
            end
            1: begin // Load and Multiply
                A <= M[i][j];
                B <= M[i][k];
                C <= M[j][k];
                prod <= M[i][j] * M[i][k]; // 64-bit product
                state <= 2;
                cnt <= 0;
            end
            2: begin // Divide (prod / C)
                // We want result as Q16.16.
                // prod is Q32.32, C is Q16.16.
                // We perform 64-bit / 32-bit.
                // We shift prod left by 16 to align? No.
                // We just need the division to result in Q16.16.
                // Standard: (prod << 16) / C yields Q32.32, taking upper 32 bits gives Q16.16.
                // But let's try: prod / C. Result is Q16.16.
                // We need to implement the restoring divider loop.
                
                if (cnt == 0) begin
                    // Setup
                    rem <= prod;
                    prod <= 0; // Will hold quotient
                    cnt <= 1;
                end else if (cnt <= 32) begin
                    // Shift Rem left
                    rem <= {rem[62:0], 1'b0};
                    // Shift Quotient left
                    prod <= {prod[62:0], 1'b0};
                    
                    // Compare upper 32 of Rem (after shift) with C
                    // Since we shifted, the new bit is in rem[63] (which was rem[62]).
                    // We need to check if {rem[62:0], 1'b0} >= {32'b0, C}
                    // We can simplify by using a temporary carry or just comparing 64-bit.
                    // {rem[62:0], 1'b0} is effectively 64-bit.
                    // C is 32-bit, so extended to 64-bit it is {32'b0, C}.
                    
                    if ({rem[62:0], 1'b0} >= {32'b0, C}) begin
                        rem <= {rem[62:0], 1'b0} - {32'b0, C};
                        prod[0] <= 1'b1;
                    end
                    
                    if (cnt == 32) begin
                        // Division done. Prod[31:0] is the result (Q16.16)
                        sq_rem <= prod[31:0]; // Use this for sqrt input
                        sq_rem <= {prod[31:0], 32'b0}; // Scale up for integer sqrt (Q16.16 input -> need Q32.0 for sqrt)
                        // Wait, we want sqrt(Q16.16).
                        // If input is X (Q16.16), X_int = X * 65536.
                        // sqrt(X_int) = sqrt(X) * 256.
                        // We want result Y (Q16.16) = sqrt(X) * 65536.
                        // So we need sqrt(X_int) * 256.
                        // Since we have X_int in sq_rem (32-bit value from prod), we need to scale it up to 64-bit with 32 zeros? 
                        // Let's pass prod[31:0] to the sqrt logic.
                        // We will implement the sqrt on prod[31:0] (Q16.16 input) treated as integer.
                        // We need to shift input left by 16 for precision?
                        // Let's use the full 64-bit width for the sqrt to maintain precision.
                        sq_rem <= {prod[31:0], 16'b0, 16'b0}; // Scale up to get correct Q16.16 result
                        // Actually, just {prod[31:0], 32'b0} makes it integer with 32 fractional bits.
                        sq_root <= 0;
                        sq_temp <= (64'h1) << 30;
                        cnt <= 33;
                    end else begin
                        cnt <= cnt + 1;
                    end
                end
            end
            3: begin // Sqrt
                // Input: sq_rem (scaled up)
                // Algorithm: Bit-pair restoring
                // If (sq_root + sq_temp <= sq_rem) ... 
                // Standard: R = 0; T = 1<<30; while(T) {...}
                
                if (sq_temp != 0) begin
                    if (sq_root + sq_temp <= sq_rem) begin
                        sq_rem <= sq_rem - (sq_root + sq_temp);
                        sq_root <= sq_root + (sq_temp << 1);
                    end
                    sq_temp <= sq_temp >> 1;
                end else begin
                    // Sqrt done.
                    // sq_root is the result. 
                    // We need to scale it back to Q16.16.
                    // sq_rem was {prod[31:0], 32'b0}.
                    // sq_root is effectively sqrt(prod[31:0] * 2^32) * 2^0?
                    // Let's just output sq_root[31:0] shifted right 8 (for the 2^16 scale vs 2^8 sqrt).
                    // Actually, if input was X << 32, output is sqrt(X << 32) = sqrt(X) << 16.
                    // We want sqrt(X) << 16. So sq_root is exactly what we want!
                    // Wait, input was prod[31:0] << 32. sqrt( (prod << 32) ) = sqrt(prod) << 16.
                    // We want sqrt(prod) << 16. 
                    // So sq_root is correct.
                    
                    result[i] <= sq_root[47:16]; // Extract correct bits? 
                    // If sq_root is 64-bit, we want the middle bits.
                    // sqrt(prod) * 2^16.
                    // prod is 32 bits. sqrt(prod) is 16 bits.
                    // Result is 16 bits * 2^16 = 32 bits.
                    // So bits [47:16] of 64-bit result should be correct.
                    // Actually, let's just take upper 32 bits of sq_root.
                    result[i] <= sq_root[63:32];
                    
                    state <= 4;
                end
            end
            4: begin // Next
                if (i < n - 1) begin
                    i <= i + 1;
                    state <= 1;
                end else begin
                    state <= 0;
                end
            end
        endcase
    end
endmodule