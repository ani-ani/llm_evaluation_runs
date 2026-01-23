module big_diff(
    // Individual 8-bit input ports for array elements
    input [7:0] arr_0,
    input [7:0] arr_1,
    input [7:0] arr_2,
    input [7:0] arr_3,
    input [7:0] arr_4,
    input [7:0] arr_5,
    input [7:0] arr_6,
    input [7:0] arr_7,
    
    // Number of valid elements (1-8)
    input [3:0] len,
    
    // 16-bit result output
    output reg [15:0] result
);

    // Internal storage for input array
    reg [7:0] arr [0:7];
    
    // Max and min tracking variables
    reg [7:0] max_val;
    reg [7:0] min_val;
    
    integer i;

    always @(*) begin
        // Load inputs into internal array
        arr[0] = arr_0;
        arr[1] = arr_1;
        arr[2] = arr_2;
        arr[3] = arr_3;
        arr[4] = arr_4;
        arr[5] = arr_5;
        arr[6] = arr_6;
        arr[7] = arr_7;
        
        // Handle edge case: len = 0
        if (len == 4'd0) begin
            max_val = 8'h00;
            min_val = 8'h00;
        end else begin
            // Initialize max and min with first element
            max_val = arr[0];
            min_val = arr[0];
            
            // Iterate through remaining valid elements
            for (i = 1; i < 8; i = i + 1) begin
                if (i < len) begin
                    if (arr[i] > max_val)
                        max_val = arr[i];
                    if (arr[i] < min_val)
                        min_val = arr[i];
                end
            end
        end
        
        // Compute difference (max - min)
        result = {8'd0, max_val} - {8'd0, min_val};
    end

endmodule