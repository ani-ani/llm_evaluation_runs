module toggle_middle_bits(
    input [15:0] n,
    output reg [15:0] result,
    output reg done
);
    // Combinational logic only
    always @(*) begin
        done = 1'b1;
        
        // Edge case: n == 1, return 1
        if (n == 16'd1) begin
            result = 16'd1;
        end else begin
            // Step 1: set_middle_bits via iterative OR-shifts
            // n |= n>>1, n|=n>>2, n|=n>>4, n|=n>>8, n|=n>>16
            reg [15:0] temp;
            temp = n;
            temp = temp | (temp >> 1);
            temp = temp | (temp >> 2);
            temp = temp | (temp >> 4);
            temp = temp | (temp >> 8);
            temp = temp | (temp >> 16);
            
            // Step 2: mask = (n >> 1) ^ 1
            reg [15:0] mask;
            mask = (temp >> 1) ^ 16'd1;
            
            // Step 3: result = n ^ mask
            result = n ^ mask;
        end
    end
endmodule