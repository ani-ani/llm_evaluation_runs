module scary_subarray_counter (
    input [3:0] p[0:15],
    output reg [9:0] scary_count
);

    // Internal signals for counting
    reg [3:0] i, j, k;
    reg [3:0] len;
    reg [3:0] left_val;
    reg [3:0] less_count;
    reg [3:0] greater_count;
    reg [3:0] subarray_len;
    reg is_scary;
    
    // Combinational block
    always @(*) begin
        scary_count = 10'd0;
        
        // Iterate over all starting positions
        for (i = 0; i < 16; i = i + 1) begin
            left_val = p[i];
            
            // Iterate over all ending positions >= start
            for (j = i; j < 16; j = j + 1) begin
                subarray_len = j - i + 4'd1;
                
                // Check if length is odd (including length 1)
                if (subarray_len[0]) begin
                    // Count elements less than and greater than left_val
                    less_count = 4'd0;
                    greater_count = 4'd0;
                    
                    // Iterate through subarray elements
                    for (k = i; k <= j; k = k + 1) begin
                        if (p[k] < left_val) begin
                            less_count = less_count + 4'd1;
                        end else if (p[k] > left_val) begin
                            greater_count = greater_count + 4'd1;
                        end
                    end
                    
                    // Check if equal (median condition)
                    is_scary = (less_count == greater_count);
                    
                    if (is_scary) begin
                        scary_count = scary_count + 10'd1;
                    end
                end
            end
        end
    end

endmodule