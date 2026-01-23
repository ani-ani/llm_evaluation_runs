module array_to_sum(
    input [7:0] arr_0,
    input [7:0] arr_1,
    input [7:0] arr_2,
    input [7:0] arr_3,
    input [7:0] arr_4,
    input [7:0] arr_5,
    input [7:0] arr_6,
    input [7:0] arr_7,
    input [3:0] len,
    output reg [10:0] sum
);
    
    // Calculate sum of valid elements
    // Sum may need up to 11 bits for 8 * 255 = 2040
    
    always @(*) begin
        case (len)
            4'd0: sum = 11'd0;
            4'd1: sum = {3'd0, arr_0};
            4'd2: sum = {3'd0, arr_0} + {3'd0, arr_1};
            4'd3: sum = {3'd0, arr_0} + {3'd0, arr_1} + {3'd0, arr_2};
            4'd4: sum = {3'd0, arr_0} + {3'd0, arr_1} + {3'd0, arr_2} + {3'd0, arr_3};
            4'd5: sum = {3'd0, arr_0} + {3'd0, arr_1} + {3'd0, arr_2} + {3'd0, arr_3} + {3'd0, arr_4};
            4'd6: sum = {3'd0, arr_0} + {3'd0, arr_1} + {3'd0, arr_2} + {3'd0, arr_3} + {3'd0, arr_4} + {3'd0, arr_5};
            4'd7: sum = {3'd0, arr_0} + {3'd0, arr_1} + {3'd0, arr_2} + {3'd0, arr_3} + {3'd0, arr_4} + {3'd0, arr_5} + {3'd0, arr_6};
            4'd8: sum = {3'd0, arr_0} + {3'd0, arr_1} + {3'd0, arr_2} + {3'd0, arr_3} + {3'd0, arr_4} + {3'd0, arr_5} + {3'd0, arr_6} + {3'd0, arr_7};
            default: sum = 11'd0;
        endcase
    end

endmodule