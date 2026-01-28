module monotonic(
    input signed [7:0] numbers [0:7],
    output reg result
);
    integer i;
    reg inc_check;
    reg dec_check;
    
    always @(*) begin
        // Initialize flags
        inc_check = 1'b1;
        dec_check = 1'b1;
        
        // Check all adjacent pairs
        for (i = 1; i < 8; i = i + 1) begin
            // Check increasing: current >= previous
            if (numbers[i] < numbers[i-1]) begin
                inc_check = 1'b0;
            end
            
            // Check decreasing: current <= previous
            if (numbers[i] > numbers[i-1]) begin
                dec_check = 1'b0;
            end
        end
        
        // Result is 1 if either condition is true
        result = inc_check | dec_check;
    end
endmodule