module max_product_pair (
    input [7:0][15:0] data_in,
    output reg [15:0] value_a,
    output reg [15:0] value_b
);

    // Internal signals for storing best pair and max product
    reg [15:0] best_a, best_b;
    reg signed [31:0] max_product;
    
    // Temporary variables for loop unrolling
    integer i, j;
    reg signed [31:0] current_product;
    reg [15:0] temp_a, temp_b;
    reg signed [31:0] temp_product;
    
    always @(*) begin
        // Initialize with first pair
        best_a = data_in[0];
        best_b = data_in[1];
        max_product = {16'b0, data_in[0]} * {16'b0, data_in[1]}; // Using signed multiplication
        
        // Actually need to handle signed properly
        max_product = $signed(data_in[0]) * $signed(data_in[1]);
        
        // Check all 28 pairs (8 choose 2)
        // Unrolled nested loop approach
        
        // i = 0
        // j = 1 (already done above, but we'll do it again systematically)
        
        // This will be unrolled by synthesis tool
        for (i = 0; i < 8; i = i + 1) begin
            for (j = i + 1; j < 8; j = j + 1) begin
                current_product = $signed(data_in[i]) * $signed(data_in[j]);
                if (current_product > max_product) begin
                    max_product = current_product;
                    best_a = data_in[i];
                    best_b = data_in[j];
                end
            end
        end
        
        value_a = best_a;
        value_b = best_b;
    end

endmodule

// Alternative without loops (for explicit unrolling):
// module max_product_pair (
//     input [7:0][15:0] data_in,
//     output reg [15:0] value_a,
//     output reg [15:0] value_b
// );
// 
//     // Combinational logic to find max product pair
//     // Using parallel comparisons
//     
//     // This is a simplified approach that finds max product
//     // by computing all pairs and comparing
//     
//     wire signed [31:0] prod_01, prod_02, prod_03, prod_04, prod_05, prod_06, prod_07,
//                        prod_12, prod_13, prod_14, prod_15, prod_16, prod_17,
//                        prod_23, prod_24, prod_25, prod_26, prod_27,
//                        prod_34, prod_35, prod_36, prod_37,
//                        prod_45, prod_46, prod_47,
//                        prod_56, prod_57,
//                        prod_67;
//     
//     assign prod_01 = $signed(data_in[0]) * $signed(data_in[1]);
//     assign prod_02 = $signed(data_in[0]) * $signed(data_in[2]);
//     assign prod_03 = $signed(data_in[0]) * $signed(data_in[3]);
//     assign prod_04 = $signed(data_in[0]) * $signed(data_in[4]);
//     assign prod_05 = $signed(data_in[0]) * $signed(data_in[5]);
//     assign prod_06 = $signed(data_in[0]) * $signed(data_in[6]);
//     assign prod_07 = $signed(data_in[0]) * $signed(data_in[7]);
//     
//     assign prod_12 = $signed(data_in[1]) * $signed(data_in[2]);
//     assign prod_13 = $signed(data_in[1]) * $signed(data_in[3]);
//     assign prod_14 = $signed(data_in[1]) * $signed(data_in[4]);
//     assign prod_15 = $signed(data_in[1]) * $signed(data_in[5]);
//     assign prod_16 = $signed(data_in[1]) * $signed(data_in[6]);
//     assign prod_17 = $signed(data_in[1]) * $signed(data_in[7]);
//     
//     assign prod_23 = $signed(data_in[2]) * $signed(data_in[3]);
//     assign prod_24 = $signed(data_in[2]) * $signed(data_in[4]);
//     assign prod_25 = $signed(data_in[2]) * $signed(data_in[5]);
//     assign prod_26 = $signed(data_in[2]) * $signed(data_in[6]);
//     assign prod_27 = $signed(data_in[2]) * $signed(data_in[7]);
//     
//     assign prod_34 = $signed(data_in[3]) * $signed(data_in[4]);
//     assign prod_35 = $signed(data_in[3]) * $signed(data_in[5]);
//     assign prod_36 = $signed(data_in[3]) * $signed(data_in[6]);
//     assign prod_37 = $signed(data_in[3]) * $signed(data_in[7]);
//     
//     assign prod_45 = $signed(data_in[4]) * $signed(data_in[5]);
//     assign prod_46 = $signed(data_in[4]) * $signed(data_in[6]);
//     assign prod_47 = $signed(data_in[4]) * $signed(data_in[7]);
//     
//     assign prod_56 = $signed(data_in[5]) * $signed(data_in[6]);
//     assign prod_57 = $signed(data_in[5]) * $signed(data_in[7]);
//     
//     assign prod_67 = $signed(data_in[6]) * $signed(data_in[7]);
//     
//     // Tree of comparators to find maximum
//     // This would be very verbose, so the loop approach is preferred
//     // for synthesis while still being combinational
// 
// endmodule
