module spec_list_subtractor(
    // Clock and reset
    input wire clk,
    input wire rst_n,
    input wire start,
    
    // Input arrays (8 elements, 8-bit each)
    input wire [7:0] arr1_0, arr1_1, arr1_2, arr1_3,
    input wire [7:0] arr1_4, arr1_5, arr1_6, arr1_7,
    input wire [7:0] arr2_0, arr2_1, arr2_2, arr2_3,
    input wire [7:0] arr2_4, arr2_5, arr2_6, arr2_7,
    
    // Length control (1-8 elements)
    input wire [3:0] len,
    
    // Output array (9-bit signed results)
    output reg [8:0] result_0, result_1, result_2, result_3,
    output reg [8:0] result_4, result_5, result_6, result_7,
    
    // Status
    output reg done
);

// Implement combinational logic
always @(*) begin
    // Default outputs
    result_0 = 9'sd0;
    result_1 = 9'sd0;
    result_2 = 9'sd0;
    result_3 = 9'sd0;
    result_4 = 9'sd0;
    result_5 = 9'sd0;
    result_6 = 9'sd0;
    result_7 = 9'sd0;
    
    // Perform subtraction where enabled
    if (start && len > 3'd0) begin
        result_0 = {1'b0, arr1_0} - {1'b0, arr2_0};
        if (len > 3'd1) result_1 = {1'b0, arr1_1} - {1'b0, arr2_1};
        if (len > 3'd2) result_2 = {1'b0, arr1_2} - {1'b0, arr2_2};
        if (len > 3'd3) result_3 = {1'b0, arr1_3} - {1'b0, arr2_3};
        if (len > 3'd4) result_4 = {1'b0, arr1_4} - {1'b0, arr2_4};
        if (len > 3'd5) result_5 = {1'b0, arr1_5} - {1'b0, arr2_5};
        if (len > 3'd6) result_6 = {1'b0, arr1_6} - {1'b0, arr2_6};
        if (len > 3'd7) result_7 = {1'b0, arr1_7} - {1'b0, arr2_7};
    end
end

// Done signal logic
always @(*) begin
    done = start && (len > 3'd0);
end

endmodule