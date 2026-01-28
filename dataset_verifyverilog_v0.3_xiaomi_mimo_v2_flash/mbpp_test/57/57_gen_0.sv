module find_max_num (
    // Inputs
    input [7:0] arr_0,
    input [7:0] arr_1,
    input [7:0] arr_2,
    input [7:0] arr_3,
    input [7:0] arr_4,
    input [7:0] arr_5,
    input [7:0] arr_6,
    input [7:0] arr_7,
    input [3:0] len,           // Number of valid digits (1-8)
    
    // Outputs
    output reg [31:0] result   // Result can be up to 8 digits: 10^8 ~ 2^32
);

    // Internal state for sorted array
    reg [7:0] sorted_0, sorted_1, sorted_2, sorted_3;
    reg [7:0] sorted_4, sorted_5, sorted_6, sorted_7;
    reg [7:0] temp;
    
    // Combinational logic
    always @(*) begin
        // Initialize sorted array with input values
        sorted_0 = arr_0;
        sorted_1 = arr_1;
        sorted_2 = arr_2;
        sorted_3 = arr_3;
        sorted_4 = arr_4;
        sorted_5 = arr_5;
        sorted_6 = arr_6;
        sorted_7 = arr_7;
        
        // Bubble sort descending (for maximum number formation)
        // Pass 1
        if (sorted_0 < sorted_1) begin temp = sorted_0; sorted_0 = sorted_1; sorted_1 = temp; end
        if (sorted_1 < sorted_2) begin temp = sorted_1; sorted_1 = sorted_2; sorted_2 = temp; end
        if (sorted_2 < sorted_3) begin temp = sorted_2; sorted_2 = sorted_3; sorted_3 = temp; end
        if (sorted_3 < sorted_4) begin temp = sorted_3; sorted_3 = sorted_4; sorted_4 = temp; end
        if (sorted_4 < sorted_5) begin temp = sorted_4; sorted_4 = sorted_5; sorted_5 = temp; end
        if (sorted_5 < sorted_6) begin temp = sorted_5; sorted_5 = sorted_6; sorted_6 = temp; end
        if (sorted_6 < sorted_7) begin temp = sorted_6; sorted_6 = sorted_7; sorted_7 = temp; end
        // Pass 2
        if (sorted_0 < sorted_1) begin temp = sorted_0; sorted_0 = sorted_1; sorted_1 = temp; end
        if (sorted_1 < sorted_2) begin temp = sorted_1; sorted_1 = sorted_2; sorted_2 = temp; end
        if (sorted_2 < sorted_3) begin temp = sorted_2; sorted_2 = sorted_3; sorted_3 = temp; end
        if (sorted_3 < sorted_4) begin temp = sorted_3; sorted_3 = sorted_4; sorted_4 = temp; end
        if (sorted_4 < sorted_5) begin temp = sorted_4; sorted_4 = sorted_5; sorted_5 = temp; end
        if (sorted_5 < sorted_6) begin temp = sorted_5; sorted_5 = sorted_6; sorted_6 = temp; end
        // Pass 3
        if (sorted_0 < sorted_1) begin temp = sorted_0; sorted_0 = sorted_1; sorted_1 = temp; end
        if (sorted_1 < sorted_2) begin temp = sorted_1; sorted_1 = sorted_2; sorted_2 = temp; end
        if (sorted_2 < sorted_3) begin temp = sorted_2; sorted_2 = sorted_3; sorted_3 = temp; end
        if (sorted_3 < sorted_4) begin temp = sorted_3; sorted_3 = sorted_4; sorted_4 = temp; end
        if (sorted_4 < sorted_5) begin temp = sorted_4; sorted_4 = sorted_5; sorted_5 = temp; end
        // Pass 4
        if (sorted_0 < sorted_1) begin temp = sorted_0; sorted_0 = sorted_1; sorted_1 = temp; end
        if (sorted_1 < sorted_2) begin temp = sorted_1; sorted_1 = sorted_2; sorted_2 = temp; end
        if (sorted_2 < sorted_3) begin temp = sorted_2; sorted_2 = sorted_3; sorted_3 = temp; end
        if (sorted_3 < sorted_4) begin temp = sorted_3; sorted_3 = sorted_4; sorted_4 = temp; end
        // Pass 5
        if (sorted_0 < sorted_1) begin temp = sorted_0; sorted_0 = sorted_1; sorted_1 = temp; end
        if (sorted_1 < sorted_2) begin temp = sorted_1; sorted_1 = sorted_2; sorted_2 = temp; end
        if (sorted_2 < sorted_3) begin temp = sorted_2; sorted_2 = sorted_3; sorted_3 = temp; end
        // Pass 6
        if (sorted_0 < sorted_1) begin temp = sorted_0; sorted_0 = sorted_1; sorted_1 = temp; end
        if (sorted_1 < sorted_2) begin temp = sorted_1; sorted_1 = sorted_2; sorted_2 = temp; end
        // Pass 7
        if (sorted_0 < sorted_1) begin temp = sorted_0; sorted_0 = sorted_1; sorted_1 = temp; end
        
        // Construct the number from sorted digits
        result = 32'd0;
        if (len >= 4'd1) result = result * 32'd10 + {24'd0, sorted_0};
        if (len >= 4'd2) result = result * 32'd10 + {24'd0, sorted_1};
        if (len >= 4'd3) result = result * 32'd10 + {24'd0, sorted_2};
        if (len >= 4'd4) result = result * 32'd10 + {24'd0, sorted_3};
        if (len >= 4'd5) result = result * 32'd10 + {24'd0, sorted_4};
        if (len >= 4'd6) result = result * 32'd10 + {24'd0, sorted_5};
        if (len >= 4'd7) result = result * 32'd10 + {24'd0, sorted_6};
        if (len >= 4'd8) result = result * 32'd10 + {24'd0, sorted_7};
    end

endmodule