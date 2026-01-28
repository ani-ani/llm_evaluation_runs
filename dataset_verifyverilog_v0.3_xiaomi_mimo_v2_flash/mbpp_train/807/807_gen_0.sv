module find_first_odd (
    input [7:0] arr_0,
    input [7:0] arr_1,
    input [7:0] arr_2,
    input [7:0] arr_3,
    input [7:0] arr_4,
    input [7:0] arr_5,
    input [7:0] arr_6,
    input [7:0] arr_7,
    output reg [7:0] result,
    output reg valid,
    output reg [2:0] index
);
    // Internal flags for each element
    wire [7:0] arr [0:7];
    wire is_odd [0:7];
    
    // Assign input array elements
    assign arr[0] = arr_0;
    assign arr[1] = arr_1;
    assign arr[2] = arr_2;
    assign arr[3] = arr_3;
    assign arr[4] = arr_4;
    assign arr[5] = arr_5;
    assign arr[6] = arr_6;
    assign arr[7] = arr_7;
    
    // Check if each element is odd (LSB = 1)
    assign is_odd[0] = arr_0[0];
    assign is_odd[1] = arr_1[0];
    assign is_odd[2] = arr_2[0];
    assign is_odd[3] = arr_3[0];
    assign is_odd[4] = arr_4[0];
    assign is_odd[5] = arr_5[0];
    assign is_odd[6] = arr_6[0];
    assign is_odd[7] = arr_7[0];
    
    // Combinational logic for priority encoder style
    always @(*) begin
        // Default values (no odd found)
        result = 8'd0;
        valid = 1'b0;
        index = 3'd0;
        
        // Check from index 0 to 7 (first match wins)
        if (is_odd[0]) begin
            result = arr_0;
            valid = 1'b1;
            index = 3'd0;
        end else if (is_odd[1]) begin
            result = arr_1;
            valid = 1'b1;
            index = 3'd1;
        end else if (is_odd[2]) begin
            result = arr_2;
            valid = 1'b1;
            index = 3'd2;
        end else if (is_odd[3]) begin
            result = arr_3;
            valid = 1'b1;
            index = 3'd3;
        end else if (is_odd[4]) begin
            result = arr_4;
            valid = 1'b1;
            index = 3'd4;
        end else if (is_odd[5]) begin
            result = arr_5;
            valid = 1'b1;
            index = 3'd5;
        end else if (is_odd[6]) begin
            result = arr_6;
            valid = 1'b1;
            index = 3'd6;
        end else if (is_odd[7]) begin
            result = arr_7;
            valid = 1'b1;
            index = 3'd7;
        end
        // If none found, defaults remain (result=0, valid=0, index=0)
    end
endmodule