module distinct_gcd_count (
    input [7:0] arr_0,
    input [7:0] arr_1,
    input [7:0] arr_2,
    input [7:0] arr_3,
    input [7:0] arr_4,
    input [7:0] arr_5,
    input [7:0] arr_6,
    input [7:0] arr_7,
    input [3:0] len,
    output reg [7:0] result
);

    // GCD function using Euclidean algorithm with 8 iterations
    function automatic [7:0] gcd_func;
        input [7:0] a;
        input [7:0] b;
        begin
            reg [7:0] x;
            reg [7:0] y;
            reg [3:0] i;
            x = a;
            y = b;
            for (i = 4'd0; i < 4'd8; i = i + 4'd1) begin
                if (y != 8'd0) begin
                    reg [7:0] temp;
                    temp = x % y;
                    x = y;
                    y = temp;
                end
            end
            gcd_func = x;
        end
    endfunction

    // Main combinational logic
    integer i;
    integer j;
    integer k;
    reg [255:0] mask;
    reg [7:0] current_gcd;
    reg [7:0] arr_reg [0:7];
    
    always @(*) begin
        // Store inputs in array for easier iteration
        arr_reg[0] = arr_0;
        arr_reg[1] = arr_1;
        arr_reg[2] = arr_2;
        arr_reg[3] = arr_3;
        arr_reg[4] = arr_4;
        arr_reg[5] = arr_5;
        arr_reg[6] = arr_6;
        arr_reg[7] = arr_7;
        
        // Initialize mask
        mask = 256'd0;
        
        // Iterate over all subarrays
        for (i = 0; i < 8; i = i + 1) begin
            if (i < len) begin
                // Start new subarray with first element
                current_gcd = arr_reg[i];
                
                // Process subarray of length 1 (just first element)
                mask[current_gcd] = 1'b1;
                
                // Extend subarray to include more elements
                for (j = i + 1; j < 8; j = j + 1) begin
                    if (j < len) begin
                        // Compute GCD of current subarray with new element
                        current_gcd = gcd_func(current_gcd, arr_reg[j]);
                        mask[current_gcd] = 1'b1;
                    end
                end
            end
        end
        
        // Count set bits in mask (population count)
        result = 8'd0;
        for (k = 0; k < 256; k = k + 1) begin
            if (mask[k]) begin
                result = result + 8'd1;
            end
        end
    end

endmodule