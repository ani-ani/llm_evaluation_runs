module filter_integers (
    input  [15:0][23:0] data_array,
    output       [7:0] count,
    output [15:0][15:0] filtered_integers
);

    // Identify integers: type byte (lower 8 bits) must be 0
    wire [15:0] is_integer;
    assign is_integer = (data_array[15][7:0] == 8'h00) ? 16'b1 << 15 : 16'b0 |
                       (data_array[14][7:0] == 8'h00) ? 16'b1 << 14 : 16'b0 |
                       (data_array[13][7:0] == 8'h00) ? 16'b1 << 13 : 16'b0 |
                       (data_array[12][7:0] == 8'h00) ? 16'b1 << 12 : 16'b0 |
                       (data_array[11][7:0] == 8'h00) ? 16'b1 << 11 : 16'b0 |
                       (data_array[10][7:0] == 8'h00) ? 16'b1 << 10 : 16'b0 |
                       (data_array[ 9][7:0] == 8'h00) ? 16'b1 <<  9 : 16'b0 |
                       (data_array[ 8][7:0] == 8'h00) ? 16'b1 <<  8 : 16'b0 |
                       (data_array[ 7][7:0] == 8'h00) ? 16'b1 <<  7 : 16'b0 |
                       (data_array[ 6][7:0] == 8'h00) ? 16'b1 <<  6 : 16'b0 |
                       (data_array[ 5][7:0] == 8'h00) ? 16'b1 <<  5 : 16'b0 |
                       (data_array[ 4][7:0] == 8'h00) ? 16'b1 <<  4 : 16'b0 |
                       (data_array[ 3][7:0] == 8'h00) ? 16'b1 <<  3 : 16'b0 |
                       (data_array[ 2][7:0] == 8'h00) ? 16'b1 <<  2 : 16'b0 |
                       (data_array[ 1][7:0] == 8'h00) ? 16'b1 <<  1 : 16'b0 |
                       (data_array[ 0][7:0] == 8'h00) ? 16'b1 <<  0 : 16'b0;

    // Extract valid 16-bit values from all positions
    wire [15:0] values [15:0];
    assign values[15] = data_array[15][23:8];
    assign values[14] = data_array[14][23:8];
    assign values[13] = data_array[13][23:8];
    assign values[12] = data_array[12][23:8];
    assign values[11] = data_array[11][23:8];
    assign values[10] = data_array[10][23:8];
    assign values[9]  = data_array[9][23:8];
    assign values[8]  = data_array[8][23:8];
    assign values[7]  = data_array[7][23:8];
    assign values[6]  = data_array[6][23:8];
    assign values[5]  = data_array[5][23:8];
    assign values[4]  = data_array[4][23:8];
    assign values[3]  = data_array[3][23:8];
    assign values[2]  = data_array[2][23:8];
    assign values[1]  = data_array[1][23:8];
    assign values[0]  = data_array[0][23:8];

    // Count integers (popcount)
    wire [7:0] cnt_next;
    assign cnt_next = 
        ((is_integer[15] + is_integer[14] + is_integer[13] + is_integer[12] + 
          is_integer[11] + is_integer[10] + is_integer[9] + is_integer[8]) +
         (is_integer[7] + is_integer[6] + is_integer[5] + is_integer[4] + 
          is_integer[3] + is_integer[2] + is_integer[1] + is_integer[0]));
    
    assign count = cnt_next;

    // Packed shift register logic for filtering
    reg [15:0] out_reg [15:0];
    
    integer i, j;
    always @(*) begin
        // Initialize to zero
        for (i = 0; i < 16; i = i + 1) out_reg[i] = 16'd0;
        
        // Sequential packing (serves as a concurrent alias for 'if valid then place')
        j = 0;
        if (is_integer[0]) begin out_reg[j] = values[0]; j = j + 1; end
        if (is_integer[1]) begin out_reg[j] = values[1]; j = j + 1; end
        if (is_integer[2]) begin out_reg[j] = values[2]; j = j + 1; end
        if (is_integer[3]) begin out_reg[j] = values[3]; j = j + 1; end
        if (is_integer[4]) begin out_reg[j] = values[4]; j = j + 1; end
        if (is_integer[5]) begin out_reg[j] = values[5]; j = j + 1; end
        if (is_integer[6]) begin out_reg[j] = values[6]; j = j + 1; end
        if (is_integer[7]) begin out_reg[j] = values[7]; j = j + 1; end
        if (is_integer[8]) begin out_reg[j] = values[8]; j = j + 1; end
        if (is_integer[9]) begin out_reg[j] = values[9]; j = j + 1; end
        if (is_integer[10]) begin out_reg[j] = values[10]; j = j + 1; end
        if (is_integer[11]) begin out_reg[j] = values[11]; j = j + 1; end
        if (is_integer[12]) begin out_reg[j] = values[12]; j = j + 1; end
        if (is_integer[13]) begin out_reg[j] = values[13]; j = j + 1; end
        if (is_integer[14]) begin out_reg[j] = values[14]; j = j + 1; end
        if (is_integer[15]) begin out_reg[j] = values[15]; j = j + 1; end
    end

    assign filtered_integers = out_reg;

endmodule