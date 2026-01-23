module string_to_tuple (
    input [7:0] char_0,
    input [7:0] char_1,
    input [7:0] char_2,
    input [7:0] char_3,
    input [7:0] char_4,
    input [7:0] char_5,
    input [7:0] char_6,
    input [7:0] char_7,
    output [7:0] result_0,
    output [7:0] result_1,
    output [7:0] result_2,
    output [7:0] result_3,
    output [7:0] result_4,
    output [7:0] result_5,
    output [7:0] result_6,
    output [7:0] result_7,
    output [3:0] count
);

    // Internal wires to hold the packed non-space characters
    wire [7:0] packed_chars [0:7];
    wire [3:0] non_space_count;

    // Combinational logic to process inputs
    // We utilize an always_comb block to handle the conditional packing logic cleanly
    always @(*) begin
        // Initialize defaults
        packed_chars[0] = 8'h00;
        packed_chars[1] = 8'h00;
        packed_chars[2] = 8'h00;
        packed_chars[3] = 8'h00;
        packed_chars[4] = 8'h00;
        packed_chars[5] = 8'h00;
        packed_chars[6] = 8'h00;
        packed_chars[7] = 8'h00;
        non_space_count = 4'h0;

        // Check char_0
        if (char_0 != 8'h20) begin
            packed_chars[non_space_count] = char_0;
            non_space_count = non_space_count + 1;
        end
        // Check char_1
        if (char_1 != 8'h20) begin
            packed_chars[non_space_count] = char_1;
            non_space_count = non_space_count + 1;
        end
        // Check char_2
        if (char_2 != 8'h20) begin
            packed_chars[non_space_count] = char_2;
            non_space_count = non_space_count + 1;
        end
        // Check char_3
        if (char_3 != 8'h20) begin
            packed_chars[non_space_count] = char_3;
            non_space_count = non_space_count + 1;
        end
        // Check char_4
        if (char_4 != 8'h20) begin
            packed_chars[non_space_count] = char_4;
            non_space_count = non_space_count + 1;
        end
        // Check char_5
        if (char_5 != 8'h20) begin
            packed_chars[non_space_count] = char_5;
            non_space_count = non_space_count + 1;
        end
        // Check char_6
        if (char_6 != 8'h20) begin
            packed_chars[non_space_count] = char_6;
            non_space_count = non_space_count + 1;
        end
        // Check char_7
        if (char_7 != 8'h20) begin
            packed_chars[non_space_count] = char_7;
            non_space_count = non_space_count + 1;
        end
    end

    // Assign internal wires to output ports
    assign result_0 = packed_chars[0];
    assign result_1 = packed_chars[1];
    assign result_2 = packed_chars[2];
    assign result_3 = packed_chars[3];
    assign result_4 = packed_chars[4];
    assign result_5 = packed_chars[5];
    assign result_6 = packed_chars[6];
    assign result_7 = packed_chars[7];
    assign count = non_space_count;

endmodule
