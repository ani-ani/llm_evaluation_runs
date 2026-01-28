module list_to_nested_dict(
    input clk,
    input rst_n,
    input start,
    input [3:0] entry_valid,
    input [7:0] id_chars_0_0, id_chars_0_1, id_chars_0_2, id_chars_0_3,
    input [7:0] id_chars_1_0, id_chars_1_1, id_chars_1_2, id_chars_1_3,
    input [7:0] id_chars_2_0, id_chars_2_1, id_chars_2_2, id_chars_2_3,
    input [7:0] id_chars_3_0, id_chars_3_1, id_chars_3_2, id_chars_3_3,
    input [7:0] name_chars_0_0, name_chars_0_1, name_chars_0_2, name_chars_0_3,
    input [7:0] name_chars_0_4, name_chars_0_5, name_chars_0_6, name_chars_0_7,
    input [7:0] name_chars_0_8, name_chars_0_9, name_chars_0_10, name_chars_0_11,
    input [7:0] name_chars_0_12, name_chars_0_13, name_chars_0_14, name_chars_0_15,
    input [7:0] name_chars_1_0, name_chars_1_1, name_chars_1_2, name_chars_1_3,
    input [7:0] name_chars_1_4, name_chars_1_5, name_chars_1_6, name_chars_1_7,
    input [7:0] name_chars_1_8, name_chars_1_9, name_chars_1_10, name_chars_1_11,
    input [7:0] name_chars_1_12, name_chars_1_13, name_chars_1_14, name_chars_1_15,
    input [7:0] name_chars_2_0, name_chars_2_1, name_chars_2_2, name_chars_2_3,
    input [7:0] name_chars_2_4, name_chars_2_5, name_chars_2_6, name_chars_2_7,
    input [7:0] name_chars_2_8, name_chars_2_9, name_chars_2_10, name_chars_2_11,
    input [7:0] name_chars_2_12, name_chars_2_13, name_chars_2_14, name_chars_2_15,
    input [7:0] name_chars_3_0, name_chars_3_1, name_chars_3_2, name_chars_3_3,
    input [7:0] name_chars_3_4, name_chars_3_5, name_chars_3_6, name_chars_3_7,
    input [7:0] name_chars_3_8, name_chars_3_9, name_chars_3_10, name_chars_3_11,
    input [7:0] name_chars_3_12, name_chars_3_13, name_chars_3_14, name_chars_3_15,
    input [7:0] scores_0, scores_1, scores_2, scores_3,
    output reg [3:0] result_valid,
    output reg [3:0] output_id_len_0, output_id_len_1, output_id_len_2, output_id_len_3,
    output reg [7:0] output_id_data_0_0, output_id_data_0_1, output_id_data_0_2, output_id_data_0_3,
    output reg [7:0] output_id_data_1_0, output_id_data_1_1, output_id_data_1_2, output_id_data_1_3,
    output reg [7:0] output_id_data_2_0, output_id_data_2_1, output_id_data_2_2, output_id_data_2_3,
    output reg [7:0] output_id_data_3_0, output_id_data_3_1, output_id_data_3_2, output_id_data_3_3,
    output reg [4:0] output_name_len_0, output_name_len_1, output_name_len_2, output_name_len_3,
    output reg [7:0] output_name_data_0_0, output_name_data_0_1, output_name_data_0_2, output_name_data_0_3,
    output reg [7:0] output_name_data_0_4, output_name_data_0_5, output_name_data_0_6, output_name_data_0_7,
    output reg [7:0] output_name_data_0_8, output_name_data_0_9, output_name_data_0_10, output_name_data_0_11,
    output reg [7:0] output_name_data_0_12, output_name_data_0_13, output_name_data_0_14, output_name_data_0_15,
    output reg [7:0] output_name_data_1_0, output_name_data_1_1, output_name_data_1_2, output_name_data_1_3,
    output reg [7:0] output_name_data_1_4, output_name_data_1_5, output_name_data_1_6, output_name_data_1_7,
    output reg [7:0] output_name_data_1_8, output_name_data_1_9, output_name_data_1_10, output_name_data_1_11,
    output reg [7:0] output_name_data_1_12, output_name_data_1_13, output_name_data_1_14, output_name_data_1_15,
    output reg [7:0] output_name_data_2_0, output_name_data_2_1, output_name_data_2_2, output_name_data_2_3,
    output reg [7:0] output_name_data_2_4, output_name_data_2_5, output_name_data_2_6, output_name_data_2_7,
    output reg [7:0] output_name_data_2_8, output_name_data_2_9, output_name_data_2_10, output_name_data_2_11,
    output reg [7:0] output_name_data_2_12, output_name_data_2_13, output_name_data_2_14, output_name_data_2_15,
    output reg [7:0] output_name_data_3_0, output_name_data_3_1, output_name_data_3_2, output_name_data_3_3,
    output reg [7:0] output_name_data_3_4, output_name_data_3_5, output_name_data_3_6, output_name_data_3_7,
    output reg [7:0] output_name_data_3_8, output_name_data_3_9, output_name_data_3_10, output_name_data_3_11,
    output reg [7:0] output_name_data_3_12, output_name_data_3_13, output_name_data_3_14, output_name_data_3_15,
    output reg [7:0] output_score_0, output_score_1, output_score_2, output_score_3,
    output reg done
);

    // State declarations
    localparam [0:0] IDLE = 1'b0;
    localparam [0:0] COMPUTE = 1'b1;
    reg [0:0] state;

    // Internal signals for combinational logic
    reg [3:0] result_valid_next;
    reg [3:0] output_id_len_0_next, output_id_len_1_next, output_id_len_2_next, output_id_len_3_next;
    reg [7:0] output_id_data_0_0_next, output_id_data_0_1_next, output_id_data_0_2_next, output_id_data_0_3_next;
    reg [7:0] output_id_data_1_0_next, output_id_data_1_1_next, output_id_data_1_2_next, output_id_data_1_3_next;
    reg [7:0] output_id_data_2_0_next, output_id_data_2_1_next, output_id_data_2_2_next, output_id_data_2_3_next;
    reg [7:0] output_id_data_3_0_next, output_id_data_3_1_next, output_id_data_3_2_next, output_id_data_3_3_next;
    reg [4:0] output_name_len_0_next, output_name_len_1_next, output_name_len_2_next, output_name_len_3_next;
    reg [7:0] output_name_data_0_0_next, output_name_data_0_1_next, output_name_data_0_2_next, output_name_data_0_3_next;
    reg [7:0] output_name_data_0_4_next, output_name_data_0_5_next, output_name_data_0_6_next, output_name_data_0_7_next;
    reg [7:0] output_name_data_0_8_next, output_name_data_0_9_next, output_name_data_0_10_next, output_name_data_0_11_next;
    reg [7:0] output_name_data_0_12_next, output_name_data_0_13_next, output_name_data_0_14_next, output_name_data_0_15_next;
    reg [7:0] output_name_data_1_0_next, output_name_data_1_1_next, output_name_data_1_2_next, output_name_data_1_3_next;
    reg [7:0] output_name_data_1_4_next, output_name_data_1_5_next, output_name_data_1_6_next, output_name_data_1_7_next;
    reg [7:0] output_name_data_1_8_next, output_name_data_1_9_next, output_name_data_1_10_next, output_name_data_1_11_next;
    reg [7:0] output_name_data_1_12_next, output_name_data_1_13_next, output_name_data_1_14_next, output_name_data_1_15_next;
    reg [7:0] output_name_data_2_0_next, output_name_data_2_1_next, output_name_data_2_2_next, output_name_data_2_3_next;
    reg [7:0] output_name_data_2_4_next, output_name_data_2_5_next, output_name_data_2_6_next, output_name_data_2_7_next;
    reg [7:0] output_name_data_2_8_next, output_name_data_2_9_next, output_name_data_2_10_next, output_name_data_2_11_next;
    reg [7:0] output_name_data_2_12_next, output_name_data_2_13_next, output_name_data_2_14_next, output_name_data_2_15_next;
    reg [7:0] output_name_data_3_0_next, output_name_data_3_1_next, output_name_data_3_2_next, output_name_data_3_3_next;
    reg [7:0] output_name_data_3_4_next, output_name_data_3_5_next, output_name_data_3_6_next, output_name_data_3_7_next;
    reg [7:0] output_name_data_3_8_next, output_name_data_3_9_next, output_name_data_3_10_next, output_name_data_3_11_next;
    reg [7:0] output_name_data_3_12_next, output_name_data_3_13_next, output_name_data_3_14_next, output_name_data_3_15_next;
    reg [7:0] output_score_0_next, output_score_1_next, output_score_2_next, output_score_3_next;
    reg done_next;

    // Combinational logic for processing
    always @(*) begin
        // Default values
        result_valid_next = 4'b0;
        output_id_len_0_next = 4'd0; output_id_len_1_next = 4'd0; output_id_len_2_next = 4'd0; output_id_len_3_next = 4'd0;
        output_id_data_0_0_next = 8'd0; output_id_data_0_1_next = 8'd0; output_id_data_0_2_next = 8'd0; output_id_data_0_3_next = 8'd0;
        output_id_data_1_0_next = 8'd0; output_id_data_1_1_next = 8'd0; output_id_data_1_2_next = 8'd0; output_id_data_1_3_next = 8'd0;
        output_id_data_2_0_next = 8'd0; output_id_data_2_1_next = 8'd0; output_id_data_2_2_next = 8'd0; output_id_data_2_3_next = 8'd0;
        output_id_data_3_0_next = 8'd0; output_id_data_3_1_next = 8'd0; output_id_data_3_2_next = 8'd0; output_id_data_3_3_next = 8'd0;
        output_name_len_0_next = 5'd0; output_name_len_1_next = 5'd0; output_name_len_2_next = 5'd0; output_name_len_3_next = 5'd0;
        output_name_data_0_0_next = 8'd0; output_name_data_0_1_next = 8'd0; output_name_data_0_2_next = 8'd0; output_name_data_0_3_next = 8'd0;
        output_name_data_0_4_next = 8'd0; output_name_data_0_5_next = 8'd0; output_name_data_0_6_next = 8'd0; output_name_data_0_7_next = 8'd0;
        output_name_data_0_8_next = 8'd0; output_name_data_0_9_next = 8'd0; output_name_data_0_10_next = 8'd0; output_name_data_0_11_next = 8'd0;
        output_name_data_0_12_next = 8'd0; output_name_data_0_13_next = 8'd0; output_name_data_0_14_next = 8'd0; output_name_data_0_15_next = 8'd0;
        output_name_data_1_0_next = 8'd0; output_name_data_1_1_next = 8'd0; output_name_data_1_2_next = 8'd0; output_name_data_1_3_next = 8'd0;
        output_name_data_1_4_next = 8'd0; output_name_data_1_5_next = 8'd0; output_name_data_1_6_next = 8'd0; output_name_data_1_7_next = 8'd0;
        output_name_data_1_8_next = 8'd0; output_name_data_1_9_next = 8'd0; output_name_data_1_10_next = 8'd0; output_name_data_1_11_next = 8'd0;
        output_name_data_1_12_next = 8'd0; output_name_data_1_13_next = 8'd0; output_name_data_1_14_next = 8'd0; output_name_data_1_15_next = 8'd0;
        output_name_data_2_0_next = 8'd0; output_name_data_2_1_next = 8'd0; output_name_data_2_2_next = 8'd0; output_name_data_2_3_next = 8'd0;
        output_name_data_2_4_next = 8'd0; output_name_data_2_5_next = 8'd0; output_name_data_2_6_next = 8'd0; output_name_data_2_7_next = 8'd0;
        output_name_data_2_8_next = 8'd0; output_name_data_2_9_next = 8'd0; output_name_data_2_10_next = 8'd0; output_name_data_2_11_next = 8'd0;
        output_name_data_2_12_next = 8'd0; output_name_data_2_13_next = 8'd0; output_name_data_2_14_next = 8'd0; output_name_data_2_15_next = 8'd0;
        output_name_data_3_0_next = 8'd0; output_name_data_3_1_next = 8'd0; output_name_data_3_2_next = 8'd0; output_name_data_3_3_next = 8'd0;
        output_name_data_3_4_next = 8'd0; output_name_data_3_5_next = 8'd0; output_name_data_3_6_next = 8'd0; output_name_data_3_7_next = 8'd0;
        output_name_data_3_8_next = 8'd0; output_name_data_3_9_next = 8'd0; output_name_data_3_10_next = 8'd0; output_name_data_3_11_next = 8'd0;
        output_name_data_3_12_next = 8'd0; output_name_data_3_13_next = 8'd0; output_name_data_3_14_next = 8'd0; output_name_data_3_15_next = 8'd0;
        output_score_0_next = 8'd0; output_score_1_next = 8'd0; output_score_2_next = 8'd0; output_score_3_next = 8'd0;
        done_next = 1'b0;

        // Process each entry
        if (entry_valid[0]) begin
            // ID length calculation (count non-null characters)
            output_id_len_0_next = 4'd0;
            if (id_chars_0_0 != 8'd0) output_id_len_0_next = 4'd1;
            if (id_chars_0_1 != 8'd0) output_id_len_0_next = 4'd2;
            if (id_chars_0_2 != 8'd0) output_id_len_0_next = 4'd3;
            if (id_chars_0_3 != 8'd0) output_id_len_0_next = 4'd4;

            // ID data
            output_id_data_0_0_next = id_chars_0_0;
            output_id_data_0_1_next = id_chars_0_1;
            output_id_data_0_2_next = id_chars_0_2;
            output_id_data_0_3_next = id_chars_0_3;

            // Name length calculation
            output_name_len_0_next = 5'd0;
            if (name_chars_0_0 != 8'd0) output_name_len_0_next = 5'd1;
            if (name_chars_0_1 != 8'd0) output_name_len_0_next = 5'd2;
            if (name_chars_0_2 != 8'd0) output_name_len_0_next = 5'd3;
            if (name_chars_0_3 != 8'd0) output_name_len_0_next = 5'd4;
            if (name_chars_0_4 != 8'd0) output_name_len_0_next = 5'd5;
            if (name_chars_0_5 != 8'd0) output_name_len_0_next = 5'd6;
            if (name_chars_0_6 != 8'd0) output_name_len_0_next = 5'd7;
            if (name_chars_0_7 != 8'd0) output_name_len_0_next = 5'd8;
            if (name_chars_0_8 != 8'd0) output_name_len_0_next = 5'd9;
            if (name_chars_0_9 != 8'd0) output_name_len_0_next = 5'd10;
            if (name_chars_0_10 != 8'd0) output_name_len_0_next = 5'd11;
            if (name_chars_0_11 != 8'd0) output_name_len_0_next = 5'd12;
            if (name_chars_0_12 != 8'd0) output_name_len_0_next = 5'd13;
            if (name_chars_0_13 != 8'd0) output_name_len_0_next = 5'd14;
            if (name_chars_0_14 != 8'd0) output_name_len_0_next = 5'd15;
            if (name_chars_0_15 != 8'd0) output_name_len_0_next = 5'd16;

            // Name data
            output_name_data_0_0_next = name_chars_0_0;
            output_name_data_0_1_next = name_chars_0_1;
            output_name_data_0_2_next = name_chars_0_2;
            output_name_data_0_3_next = name_chars_0_3;
            output_name_data_0_4_next = name_chars_0_4;
            output_name_data_0_5_next = name_chars_0_5;
            output_name_data_0_6_next = name_chars_0_6;
            output_name_data_0_7_next = name_chars_0_7;
            output_name_data_0_8_next = name_chars_0_8;
            output_name_data_0_9_next = name_chars_0_9;
            output_name_data_0_10_next = name_chars_0_10;
            output_name_data_0_11_next = name_chars_0_11;
            output_name_data_0_12_next = name_chars_0_12;
            output_name_data_0_13_next = name_chars_0_13;
            output_name_data_0_14_next = name_chars_0_14;
            output_name_data_0_15_next = name_chars_0_15;

            // Score
            output_score_0_next = scores_0;
            result_valid_next[0] = 1'b1;
        end

        if (entry_valid[1]) begin
            // ID length calculation
            output_id_len_1_next = 4'd0;
            if (id_chars_1_0 != 8'd0) output_id_len_1_next = 4'd1;
            if (id_chars_1_1 != 8'd0) output_id_len_1_next = 4'd2;
            if (id_chars_1_2 != 8'd0) output_id_len_1_next = 4'd3;
            if (id_chars_1_3 != 8'd0) output_id_len_1_next = 4'd4;

            // ID data
            output_id_data_1_0_next = id_chars_1_0;
            output_id_data_1_1_next = id_chars_1_1;
            output_id_data_1_2_next = id_chars_1_2;
            output_id_data_1_3_next = id_chars_1_3;

            // Name length calculation
            output_name_len_1_next = 5'd0;
            if (name_chars_1_0 != 8'd0) output_name_len_1_next = 5'd1;
            if (name_chars_1_1 != 8'd0) output_name_len_1_next = 5'd2;
            if (name_chars_1_2 != 8'd0) output_name_len_1_next = 5'd3;
            if (name_chars_1_3 != 8'd0) output_name_len_1_next = 5'd4;
            if (name_chars_1_4 != 8'd0) output_name_len_1_next = 5'd5;
            if (name_chars_1_5 != 8'd0) output_name_len_1_next = 5'd6;
            if (name_chars_1_6 != 8'd0) output_name_len_1_next = 5'd7;
            if (name_chars_1_7 != 8'd0) output_name_len_1_next = 5'd8;
            if (name_chars_1_8 != 8'd0) output_name_len_1_next = 5'd9;
            if (name_chars_1_9 != 8'd0) output_name_len_1_next = 5'd10;
            if (name_chars_1_10 != 8'd0) output_name_len_1_next = 5'd11;
            if (name_chars_1_11 != 8'd0) output_name_len_1_next = 5'd12;
            if (name_chars_1_12 != 8'd0) output_name_len_1_next = 5'd13;
            if (name_chars_1_13 != 8'd0) output_name_len_1_next = 5'd14;
            if (name_chars_1_14 != 8'd0) output_name_len_1_next = 5'd15;
            if (name_chars_1_15 != 8'd0) output_name_len_1_next = 5'd16;

            // Name data
            output_name_data_1_0_next = name_chars_1_0;
            output_name_data_1_1_next = name_chars_1_1;
            output_name_data_1_2_next = name_chars_1_2;
            output_name_data_1_3_next = name_chars_1_3;
            output_name_data_1_4_next = name_chars_1_4;
            output_name_data_1_5_next = name_chars_1_5;
            output_name_data_1_6_next = name_chars_1_6;
            output_name_data_1_7_next = name_chars_1_7;
            output_name_data_1_8_next = name_chars_1_8;
            output_name_data_1_9_next = name_chars_1_9;
            output_name_data_1_10_next = name_chars_1_10;
            output_name_data_1_11_next = name_chars_1_11;
            output_name_data_1_12_next = name_chars_1_12;
            output_name_data_1_13_next = name_chars_1_13;
            output_name_data_1_14_next = name_chars_1_14;
            output_name_data_1_15_next = name_chars_1_15;

            // Score
            output_score_1_next = scores_1;
            result_valid_next[1] = 1'b1;
        end

        if (entry_valid[2]) begin
            // ID length calculation
            output_id_len_2_next = 4'd0;
            if (id_chars_2_0 != 8'd0) output_id_len_2_next = 4'd1;
            if (id_chars_2_1 != 8'd0) output_id_len_2_next = 4'd2;
            if (id_chars_2_2 != 8'd0) output_id_len_2_next = 4'd3;
            if (id_chars_2_3 != 8'd0) output_id_len_2_next = 4'd4;

            // ID data
            output_id_data_2_0_next = id_chars_2_0;
            output_id_data_2_1_next = id_chars_2_1;
            output_id_data_2_2_next = id_chars_2_2;
            output_id_data_2_3_next = id_chars_2_3;

            // Name length calculation
            output_name_len_2_next = 5'd0;
            if (name_chars_2_0 != 8'd0) output_name_len_2_next = 5'd1;
            if (name_chars_2_1 != 8'd0) output_name_len_2_next = 5'd2;
            if (name_chars_2_2 != 8'd0) output_name_len_2_next = 5'd3;
            if (name_chars_2_3 != 8'd0) output_name_len_2_next = 5'd4;
            if (name_chars_2_4 != 8'd0) output_name_len_2_next = 5'd5;
            if (name_chars_2_5 != 8'd0) output_name_len_2_next = 5'd6;
            if (name_chars_2_6 != 8'd0) output_name_len_2_next = 5'd7;
            if (name_chars_2_7 != 8'd0) output_name_len_2_next = 5'd8;
            if (name_chars_2_8 != 8'd0) output_name_len_2_next = 5'd9;
            if (name_chars_2_9 != 8'd0) output_name_len_2_next = 5'd10;
            if (name_chars_2_10 != 8'd0) output_name_len_2_next = 5'd11;
            if (name_chars_2_11 != 8'd0) output_name_len_2_next = 5'd12;
            if (name_chars_2_12 != 8'd0) output_name_len_2_next = 5'd13;
            if (name_chars_2_13 != 8'd0) output_name_len_2_next = 5'd14;
            if (name_chars_2_14 != 8'd0) output_name_len_2_next = 5'd15;
            if (name_chars_2_15 != 8'd0) output_name_len_2_next = 5'd16;

            // Name data
            output_name_data_2_0_next = name_chars_2_0;
            output_name_data_2_1_next = name_chars_2_1;
            output_name_data_2_2_next = name_chars_2_2;
            output_name_data_2_3_next = name_chars_2_3;
            output_name_data_2_4_next = name_chars_2_4;
            output_name_data_2_5_next = name_chars_2_5;
            output_name_data_2_6_next = name_chars_2_6;
            output_name_data_2_7_next = name_chars_2_7;
            output_name_data_2_8_next = name_chars_2_8;
            output_name_data_2_9_next = name_chars_2_9;
            output_name_data_2_10_next = name_chars_2_10;
            output_name_data_2_11_next = name_chars_2_11;
            output_name_data_2_12_next = name_chars_2_12;
            output_name_data_2_13_next = name_chars_2_13;
            output_name_data_2_14_next = name_chars_2_14;
            output_name_data_2_15_next = name_chars_2_15;

            // Score
            output_score_2_next = scores_2;
            result_valid_next[2] = 1'b1;
        end

        if (entry_valid[3]) begin
            // ID length calculation
            output_id_len_3_next = 4'd0;
            if (id_chars_3_0 != 8'd0) output_id_len_3_next = 4'd1;
            if (id_chars_3_1 != 8'd0) output_id_len_3_next = 4'd2;
            if (id_chars_3_2 != 8'd0) output_id_len_3_next = 4'd3;
            if (id_chars_3_3 != 8'd0) output_id_len_3_next = 4'd4;

            // ID data
            output_id_data_3_0_next = id_chars_3_0;
            output_id_data_3_1_next = id_chars_3_1;
            output_id_data_3_2_next = id_chars_3_2;
            output_id_data_3_3_next = id_chars_3_3;

            // Name length calculation
            output_name_len_3_next = 5'd0;
            if (name_chars_3_0 != 8'd0) output_name_len_3_next = 5'd1;
            if (name_chars_3_1 != 8'd0) output_name_len_3_next = 5'd2;
            if (name_chars_3_2 != 8'd0) output_name_len_3_next = 5'd3;
            if (name_chars_3_3 != 8'd0) output_name_len_3_next = 5'd4;
            if (name_chars_3_4 != 8'd0) output_name_len_3_next = 5'd5;
            if (name_chars_3_5 != 8'd0) output_name_len_3_next = 5'd6;
            if (name_chars_3_6 != 8'd0) output_name_len_3_next = 5'd7;
            if (name_chars_3_7 != 8'd0) output_name_len_3_next = 5'd8;
            if (name_chars_3_8 != 8'd0) output_name_len_3_next = 5'd9;
            if (name_chars_3_9 != 8'd0) output_name_len_3_next = 5'd10;
            if (name_chars_3_10 != 8'd0) output_name_len_3_next = 5'd11;
            if (name_chars_3_11 != 8'd0) output_name_len_3_next = 5'd12;
            if (name_chars_3_12 != 8'd0) output_name_len_3_next = 5'd13;
            if (name_chars_3_13 != 8'd0) output_name_len_3_next = 5'd14;
            if (name_chars_3_14 != 8'd0) output_name_len_3_next = 5'd15;
            if (name_chars_3_15 != 8'd0) output_name_len_3_next = 5'd16;

            // Name data
            output_name_data_3_0_next = name_chars_3_0;
            output_name_data_3_1_next = name_chars_3_1;
            output_name_data_3_2_next = name_chars_3_2;
            output_name_data_3_3_next = name_chars_3_3;
            output_name_data_3_4_next = name_chars_3_4;
            output_name_data_3_5_next = name_chars_3_5;
            output_name_data_3_6_next = name_chars_3_6;
            output_name_data_3_7_next = name_chars_3_7;
            output_name_data_3_8_next = name_chars_3_8;
            output_name_data_3_9_next = name_chars_3_9;
            output_name_data_3_10_next = name_chars_3_10;
            output_name_data_3_11_next = name_chars_3_11;
            output_name_data_3_12_next = name_chars_3_12;
            output_name_data_3_13_next = name_chars_3_13;
            output_name_data_3_14_next = name_chars_3_14;
            output_name_data_3_15_next = name_chars_3_15;

            // Score
            output_score_3_next = scores_3;
            result_valid_next[3] = 1'b1;
        end

        // Set done signal when processing is complete
        if (state == COMPUTE) begin
            done_next = 1'b1;
        end
    end

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result_valid <= 4'b0;
            output_id_len_0 <= 4'd0; output_id_len_1 <= 4'd0; output_id_len_2 <= 4'd0; output_id_len_3 <= 4'd0;
            output_id_data_0_0 <= 8'd0; output_id_data_0_1 <= 8'd0; output_id_data_0_2 <= 8'd0; output_id_data_0_3 <= 8'd0;
            output_id_data_1_0 <= 8'd0; output_id_data_1_1 <= 8'd0; output_id_data_1_2 <= 8'd0; output_id_data_1_3 <= 8'd0;
            output_id_data_2_0 <= 8'd0; output_id_data_2_1 <= 8'd0; output_id_data_2_2 <= 8'd0; output_id_data_2_3 <= 8'd0;
            output_id_data_3_0 <= 8'd0; output_id_data_3_1 <= 8'd0; output_id_data_3_2 <= 8'd0; output_id_data_3_3 <= 8'd0;
            output_name_len_0 <= 5'd0; output_name_len_1 <= 5'd0; output_name_len_2 <= 5'd0; output_name_len_3 <= 5'd0;
            output_name_data_0_0 <= 8'd0; output_name_data_0_1 <= 8'd0; output_name_data_0_2 <= 8'd0; output_name_data_0_3 <= 8'd0;
            output_name_data_0_4 <= 8'd0; output_name_data_0_5 <= 8'd0; output_name_data_0_6 <= 8'd0; output_name_data_0_7 <= 8'd0;
            output_name_data_0_8 <= 8'd0; output_name_data_0_9 <= 8'd0; output_name_data_0_10 <= 8'd0; output_name_data_0_11 <= 8'd0;
            output_name_data_0_12 <= 8'd0; output_name_data_0_13 <= 8'd0; output_name_data_0_14 <= 8'd0; output_name_data_0_15 <= 8'd0;
            output_name_data_1_0 <= 8'd0; output_name_data_1_1 <= 8'd0; output_name_data_1_2 <= 8'd0; output_name_data_1_3 <= 8'd0;
            output_name_data_1_4 <= 8'd0; output_name_data_1_5 <= 8'd0; output_name_data_1_6 <= 8'd0; output_name_data_1_7 <= 8'd0;
            output_name_data_1_8 <= 8'd0; output_name_data_1_9 <= 8'd0; output_name_data_1_10 <= 8'd0; output_name_data_1_11 <= 8'd0;
            output_name_data_1_12 <= 8'd0; output_name_data_1_13 <= 8'd0; output_name_data_1_14 <= 8'd0; output_name_data_1_15 <= 8'd0;
            output_name_data_2_0 <= 8'd0; output_name_data_2_1 <= 8'd0; output_name_data_2_2 <= 8'd0; output_name_data_2_3 <= 8'd0;
            output_name_data_2_4 <= 8'd0; output_name_data_2_5 <= 8'd0; output_name_data_2_6 <= 8'd0; output_name_data_2_7 <= 8'd0;
            output_name_data_2_8 <= 8'd0; output_name_data_2_9 <= 8'd0; output_name_data_2_10 <= 8'd0; output_name_data_2_11 <= 8'd0;
            output_name_data_2_12 <= 8'd0; output_name_data_2_13 <= 8'd0; output_name_data_2_14 <= 8'd0; output_name_data_2_15 <= 8'd0;
            output_name_data_3_0 <= 8'd0; output_name_data_3_1 <= 8'd0; output_name_data_3_2 <= 8'd0; output_name_data_3_3 <= 8'd0;
            output_name_data_3_4 <= 8'd0; output_name_data_3_5 <= 8'd0; output_name_data_3_6 <= 8'd0; output_name_data_3_7 <= 8'd0;
            output_name_data_3_8 <= 8'd0; output_name_data_3_9 <= 8'd0; output_name_data_3_10 <= 8'd0; output_name_data_3_11 <= 8'd0;
            output_name_data_3_12 <= 8'd0; output_name_data_3_13 <= 8'd0; output_name_data_3_14 <= 8'd0; output_name_data_3_15 <= 8'd0;
            output_score_0 <= 8'd0; output_score_1 <= 8'd0; output_score_2 <= 8'd0; output_score_3 <= 8'd0;
            done <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= COMPUTE;
                    end
                end
                COMPUTE: begin
                    // Register outputs
                    result_valid <= result_valid_next;
                    output_id_len_0 <= output_id_len_0_next; output_id_len_1 <= output_id_len_1_next; output_id_len_2 <= output_id_len_2_next; output_id_len_3 <= output_id_len_3_next;
                    output_id_data_0_0 <= output_id_data_0_0_next; output_id_data_0_1 <= output_id_data_0_1_next; output_id_data_0_2 <= output_id_data_0_2_next; output_id_data_0_3 <= output_id_data_0_3_next;
                    output_id_data_1_0 <= output_id_data_1_0_next; output_id_data_1_1 <= output_id_data_1_1_next; output_id_data_1_2 <= output_id_data_1_2_next; output_id_data_1_3 <= output_id_data_1_3_next;
                    output_id_data_2_0 <= output_id_data_2_0_next; output_id_data_2_1 <= output_id_data_2_1_next; output_id_data_2_2 <= output_id_data_2_2_next; output_id_data_2_3 <= output_id_data_2_3_next;
                    output_id_data_3_0 <= output_id_data_3_0_next; output_id_data_3_1 <= output_id_data_3_1_next; output_id_data_3_2 <= output_id_data_3_2_next; output_id_data_3_3 <= output_id_data_3_3_next;
                    output_name_len_0 <= output_name_len_0_next; output_name_len_1 <= output_name_len_1_next; output_name_len_2 <= output_name_len_2_next; output_name_len_3 <= output_name_len_3_next;
                    output_name_data_0_0 <= output_name_data_0_0_next; output_name_data_0_1 <= output_name_data_0_1_next; output_name_data_0_2 <= output_name_data_0_2_next; output_name_data_0_3 <= output_name_data_0_3_next;
                    output_name_data_0_4 <= output_name_data_0_4_next; output_name_data_0_5 <= output_name_data_0_5_next; output_name_data_0_6 <= output_name_data_0_6_next; output_name_data_0_7 <= output_name_data_0_7_next;
                    output_name_data_0_8 <= output_name_data_0_8_next; output_name_data_0_9 <= output_name_data_0_9_next; output_name_data_0_10 <= output_name_data_0_10_next; output_name_data_0_11 <= output_name_data_0_11_next;
                    output_name_data_0_12 <= output_name_data_0_12_next; output_name_data_0_13 <= output_name_data_0_13_next; output_name_data_0_14 <= output_name_data_0_14_next; output_name_data_0_15 <= output_name_data_0_15_next;
                    output_name_data_1_0 <= output_name_data_1_0_next; output_name_data_1_1 <= output_name_data_1_1_next; output_name_data_1_2 <= output_name_data_1_2_next; output_name_data_1_3 <= output_name_data_1_3_next;
                    output_name_data_1_4 <= output_name_data_1_4_next; output_name_data_1_5 <= output_name_data_1_5_next; output_name_data_1_6 <= output_name_data_1_6_next; output_name_data_1_7 <= output_name_data_1_7_next;
                    output_name_data_1_8 <= output_name_data_1_8_next; output_name_data_1_9 <= output_name_data_1_9_next; output_name_data_1_10 <= output_name_data_1_10_next; output_name_data_1_11 <= output_name_data_1_11_next;
                    output_name_data_1_12 <= output_name_data_1_12_next; output_name_data_1_13 <= output_name_data_1_13_next; output_name_data_1_14 <= output_name_data_1_14_next; output_name_data_1_15 <= output_name_data_1_15_next;
                    output_name_data_2_0 <= output_name_data_2_0_next; output_name_data_2_1 <= output_name_data_2_1_next; output_name_data_2_2 <= output_name_data_2_2_next; output_name_data_2_3 <= output_name_data_2_3_next;
                    output_name_data_2_4 <= output_name_data_2_4_next; output_name_data_2_5 <= output_name_data_2_5_next; output_name_data_2_6 <= output_name_data_2_6_next; output_name_data_2_7 <= output_name_data_2_7_next;
                    output_name_data_2_8 <= output_name_data_2_8_next; output_name_data_2_9 <= output_name_data_2_9_next; output_name_data_2_10 <= output_name_data_2_10_next; output_name_data_2_11 <= output_name_data_2_11_next;
                    output_name_data_2_12 <= output_name_data_2_12_next; output_name_data_2_13 <= output_name_data_2_13_next; output_name_data_2_14 <= output_name_data_2_14_next; output_name_data_2_15 <= output_name_data_2_15_next;
                    output_name_data_3_0 <= output_name_data_3_0_next; output_name_data_3_1 <= output_name_data_3_1_next; output_name_data_3_2 <= output_name_data_3_2_next; output_name_data_3_3 <= output_name_data_3_3_next;
                    output_name_data_3_4 <= output_name_data_3_4_next; output_name_data_3_5 <= output_name_data_3_5_next; output_name_data_3_6 <= output_name_data_3_6_next; output_name_data_3_7 <= output_name_data_3_7_next;
                    output_name_data_3_8 <= output_name_data_3_8_next; output_name_data_3_9 <= output_name_data_3_9_next; output_name_data_3_10 <= output_name_data_3_10_next; output_name_data_3_11 <= output_name_data_3_11_next;
                    output_name_data_3_12 <= output_name_data_3_12_next; output_name_data_3_13 <= output_name_data_3_13_next; output_name_data_3_14 <= output_name_data_3_14_next; output_name_data_3_15 <= output_name_data_3_15_next;
                    output_score_0 <= output_score_0_next; output_score_1 <= output_score_1_next; output_score_2 <= output_score_2_next; output_score_3 <= output_score_3_next;
                    done <= done_next;
                    state <= IDLE;
                end
                default: state <= IDLE;
            endcase
        end
    end
endmodule