module highest_power_of_2 (
    input [15:0] n,
    output reg [15:0] result
);
    // Combinational logic to find highest power of 2 <= n
    // Algorithm: propagate bits, then compute (n+1)>>1
    
    reg [15:0] temp;
    
    always @(*) begin
        if (n == 16'd0) begin
            result = 16'd0;
        end else begin
            // Step 1: Propagate MSB to all lower bits
            temp = n;
            temp = temp | (temp >> 1);
            temp = temp | (temp >> 2);
            temp = temp | (temp >> 4);
            temp = temp | (temp >> 8);
            
            // Step 2: Result is (temp + 1) >> 1
            result = (temp + 16'd1) >> 1;
        end
    end
    
endmodule