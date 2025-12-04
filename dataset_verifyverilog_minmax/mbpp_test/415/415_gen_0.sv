module max_product_finder (
    input [7:0][7:0] arr_input,   // 8 elements of 8-bit signed integers
    output logic signed [7:0] num1,
    output logic signed [7:0] num2
);

    integer i, j;
    integer i_max, j_max;
    logic signed [15:0] max_product;
    logic signed [15:0] curr_product;

    always_comb begin
        // Initialize max_product to the minimum possible 16-bit signed value
        max_product = 16'h8000;  // -32768
        
        // Iterate through all possible pairs
        for (i = 0; i < 8; i++) begin
            for (j = i+1; j < 8; j++) begin
                curr_product = $signed(arr_input[i]) * $signed(arr_input[j]);
                if (curr_product > max_product) begin
                    max_product = curr_product;
                    i_max = i;
                    j_max = j;
                end
            end
        end
        
        // Output the pair that gave the maximum product
        num1 = arr_input[i_max];
        num2 = arr_input[j_max];
    end

endmodule