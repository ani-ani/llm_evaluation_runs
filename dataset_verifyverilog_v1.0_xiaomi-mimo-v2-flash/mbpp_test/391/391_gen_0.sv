module list_to_nested_dict(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] entry_valid,
    input wire [7:0] id_chars_0_0, id_chars_0_1, id_chars_0_2, id_chars_0_3,
    input wire [7:0] id_chars_1_0, id_chars_1_1, id_chars_1_2, id_chars_1_3,
    input wire [7:0] id_chars_2_0, id_chars_2_1, id_chars_2_2, id_chars_2_3,
    input wire [7:0] id_chars_3_0, id_chars_3_1, id_chars_3_2, id_chars_3_3,
    input wire [7:0] name_chars_0_0, name_chars_0_1, name_chars_0_2, name_chars_0_3,
    input wire [7:0] name_chars_0_4, name_chars_0_5, name_chars_0_6, name_chars_0_7,
    input wire [7:0] name_chars_0_8, name_chars_0_9, name_chars_0_10, name_chars_0_11,
    input wire [7:0] name_chars_0_12, name_chars_0_13, name_chars_0_14, name_chars_0_15,
    input wire [7:0] name_chars_1_0, name_chars_1_1, name_chars_1_2, name_chars_1_3,
    input wire [7:0] name_chars_1_4, name_chars_1_5, name_chars_1_6, name_chars_1_7,
    input wire [7:0] name_chars_1_8, name_chars_1_9, name_chars_1_10, name_chars_1_11,
    input wire [7:0] name_chars_1_12, name_chars_1_13, name_chars_1_14, name_chars_1_15,
    input wire [7:0] name_chars_2_0, name_chars_2_1, name_chars_2_2, name_chars_2_3,
    input wire [7:0] name_chars_2_4, name_chars_2_5, name_chars_2_6, name_chars_2_7,
    input wire [7:0] name_chars_2_8, name_chars_2_9, name_chars_2_10, name_chars_2_11,
    input wire [7:0] name_chars_2_12, name_chars_2_13, name_chars_2_14, name_chars_2_15,
    input wire [7:0] name_chars_3_0, name_chars_3_1, name_chars_3_2, name_chars_3_3,
    input wire [7:0] name_chars_3_4, name_chars_3_5, name_chars_3_6, name_chars_3_7,
    input wire [7:0] name_chars_3_8, name_chars_3_9, name_chars_3_10, name_chars_3_11,
    input wire [7:0] name_chars_3_12, name_chars_3_13, name_chars_3_14, name_chars_3_15,
    input wire [7:0] scores_0, scores_1, scores_2, scores_3,
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

    // State definitions
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;
    localparam [1:0] DONE_STATE = 2'd2;

    reg [1:0] state, next_state;
    reg [3:0] id_len_0, id_len_1, id_len_2, id_len_3;
    reg [4:0] name_len_0, name_len_1, name_len_2, name_len_3;
    integer i;

    // State register and reset logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result_valid <= 4'd0;
            output_id_len_0 <= 4'd0;
            output_id_len_1 <= 4'd0;
            output_id_len_2 <= 4'd0;
            output_id_len_3 <= 4'd0;
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
            id_len_0 <= 4'd0; id_len_1 <= 4'd0; id_len_2 <= 4'd0; id_len_3 <= 4'd0;
            name_len_0 <= 5'd0; name_len_1 <= 5'd0; name_len_2 <= 5'd0; name_len_3 <= 5'd0;
        end else begin
            state <= next_state;
            case (state)
                IDLE: begin
                    done <= 1'b0;
                end
                COMPUTE: begin
                    // Calculate ID lengths
                    if (entry_valid[0]) begin
                        id_len_0 <= (id_chars_0_0 != 8'd0) ? 4'd1 : 4'd0;
                        if (id_chars_0_1 != 8'd0) id_len_0 <= 4'd2;
                        if (id_chars_0_2 != 8'd0) id_len_0 <= 4'd3;
                        if (id_chars_0_3 != 8'd0) id_len_0 <= 4'd4;
                    end
                    if (entry_valid[1]) begin
                        id_len_1 <= (id_chars_1_0 != 8'd0) ? 4'd1 : 4'd0;
                        if (id_chars_1_1 != 8'd0) id_len_1 <= 4'd2;
                        if (id_chars_1_2 != 8'd0) id_len_1 <= 4'd3;
                        if (id_chars_1_3 != 8'd0) id_len_1 <= 4'd4;
                    end
                    if (entry_valid[2]) begin
                        id_len_2 <= (id_chars_2_0 != 8'd0) ? 4'd1 : 4'd0;
                        if (id_chars_2_1 != 8'd0) id_len_2 <= 4'd2;
                        if (id_chars_2_2 != 8'd0) id_len_2 <= 4'd3;
                        if (id_chars_2_3 != 8'd0) id_len_2 <= 4'd4;
                    end
                    if (entry_valid[3]) begin
                        id_len_3 <= (id_chars_3_0 != 8'd0) ? 4'd1 : 4'd0;
                        if (id_chars_3_1 != 8'd0) id_len_3 <= 4'd2;
                        if (id_chars_3_2 != 8'd0) id_len_3 <= 4'd3;
                        if (id_chars_3_3 != 8'd0) id_len_3 <= 4'd4;
                    end
                    // Calculate Name lengths
                    if (entry_valid[0]) begin
                        name_len_0 <= 5'd0;
                        if (name_chars_0_0 != 8'd0) name_len_0 <= 5'd1;
                        if (name_chars_0_1 != 8'd0) name_len_0 <= 5'd2;
                        if (name_chars_0_2 != 8'd0) name_len_0 <= 5'd3;
                        if (name_chars_0_3 != 8'd0) name_len_0 <= 5'd4;
                        if (name_chars_0_4 != 8'd0) name_len_0 <= 5'd5;
                        if (name_chars_0_5 != 8'd0) name_len_0 <= 5'd6;
                        if (name_chars_0_6 != 8'd0) name_len_0 <= 5'd7;
                        if (name_chars_0_7 != 8'd0) name_len_0 <= 5'd8;
                        if (name_chars_0_8 != 8'd0) name_len_0 <= 5'd9;
                        if (name_chars_0_9 != 8'd0) name_len_0 <= 5'd10;
                        if (name_chars_0_10 != 8'd0) name_len_0 <= 5'd11;
                        if (name_chars_0_11 != 8'd0) name_len_0 <= 5'd12;
                        if (name_chars_0_12 != 8'd0) name_len_0 <= 5'd13;
                        if (name_chars_0_13 != 8'd0) name_len_0 <= 5'd14;
                        if (name_chars_0_14 != 8'd0) name_len_0 <= 5'd15;
                        if (name_chars_0_15 != 8'd0) name_len_0 <= 5'd16;
                    end
                    if (entry_valid[1]) begin
                        name_len_1 <= 5'd0;
                        if (name_chars_1_0 != 8'd0) name_len_1 <= 5'd1;
                        if (name_chars_1_1 != 8'd0) name_len_1 <= 5'd2;
                        if (name_chars_1_2 != 8'd0) name_len_1 <= 5'd3;
                        if (name_chars_1_3 != 8'd0) name_len_1 <= 5'd4;
                        if (name_chars_1_4 != 8'd0) name_len_1 <= 5'd5;
                        if (name_chars_1_5 != 8'd0) name_len_1 <= 5'd6;
                        if (name_chars_1_6 != 8'd0) name_len_1 <= 5'd7;
                        if (name_chars_1_7 != 8'd0) name_len_1 <= 5'd8;
                        if (name_chars_1_8 != 8'd0) name_len_1 <= 5'd9;
                        if (name_chars_1_9 != 8'd0) name_len_1 <= 5'd10;
                        if (name_chars_1_10 != 8'd0) name_len_1 <= 5'd11;
                        if (name_chars_1_11 != 8'd0) name_len_1 <= 5'd12;
                        if (name_chars_1_12 != 8'd0) name_len_1 <= 5'd13;
                        if (name_chars_1_13 != 8'd0) name_len_1 <= 5'd14;
                        if (name_chars_1_14 != 8'd0) name_len_1 <= 5'd15;
                        if (name_chars_1_15 != 8'd0) name_len_1 <= 5'd16;
                    end
                    if (entry_valid[2]) begin
                        name_len_2 <= 5'd0;
                        if (name_chars_2_0 != 8'd0) name_len_2 <= 5'd1;
                        if (name_chars_2_1 != 8'd0) name_len_2 <= 5'd2;
                        if (name_chars_2_2 != 8'd0) name_len_2 <= 5'd3;
                        if (name_chars_2_3 != 8'd0) name_len_2 <= 5'd4;
                        if (name_chars_2_4 != 8'd0) name_len_2 <= 5'd5;
                        if (name_chars_2_5 != 8'd0) name_len_2 <= 5'd6;
                        if (name_chars_2_6 != 8'd0) name_len_2 <= 5'd7;
                        if (name_chars_2_7 != 8'd0) name_len_2 <= 5'd8;
                        if (name_chars_2_8 != 8'd0) name_len_2 <= 5'd9;
                        if (name_chars_2_9 != 8'd0) name_len_2 <= 5'd10;
                        if (name_chars_2_10 != 8'd0) name_len_2 <= 5'd11;
                        if (name_chars_2_11 != 8'd0) name_len_2 <= 5'd12;
                        if (name_chars_2_12 != 8'd0) name_len_2 <= 5'd13;
                        if (name_chars_2_13 != 8'd0) name_len_2 <= 5'd14;
                        if (name_chars_2_14 != 8'd0) name_len_2 <= 5'd15;
                        if (name_chars_2_15 != 8'd0) name_len_2 <= 5'd16;
                    end
                    if (entry_valid[3]) begin
                        name_len_3 <= 5'd0;
                        if (name_chars_3_0 != 8'd0) name_len_3 <= 5'd1;
                        if (name_chars_3_1 != 8'd0) name_len_3 <= 5'd2;
                        if (name_chars_3_2 != 8'd0) name_len_3 <= 5'd3;
                        if (name_chars_3_3 != 8'd0) name_len_3 <= 5'd4;
                        if (name_chars_3_4 != 8'd0) name_len_3 <= 5'd5;
                        if (name_chars_3_5 != 8'd0) name_len_3 <= 5'd6;
                        if (name_chars_3_6 != 8'd0) name_len_3 <= 5'd7;
                        if (name_chars_3_7 != 8'd0) name_len_3 <= 5'd8;
                        if (name_chars_3_8 != 8'd0) name_len_3 <= 5'd9;
                        if (name_chars_3_9 != 8'd0) name_len_3 <= 5'd10;
                        if (name_chars_3_10 != 8'd0) name_len_3 <= 5'd11;
                        if (name_chars_3_11 != 8'd0) name_len_3 <= 5'd12;
                        if (name_chars_3_12 != 8'd0) name_len_3 <= 5'd13;
                        if (name_chars_3_13 != 8'd0) name_len_3 <= 5'd14;
                        if (name_chars_3_14 != 8'd0) name_len_3 <= 5'd15;
                        if (name_chars_3_15 != 8'd0) name_len_3 <= 5'd16;
                    end
                    // Register outputs
                    result_valid <= entry_valid;
                    output_id_len_0 <= id_len_0;
                    output_id_len_1 <= id_len_1;
                    output_id_len_2 <= id_len_2;
                    output_id_len_3 <= id_len_3;
                    output_id_data_0_0 <= id_chars_0_0; output_id_data_0_1 <= id_chars_0_1; output_id_data_0_2 <= id_chars_0_2; output_id_data_0_3 <= id_chars_0_3;
                    output_id_data_1_0 <= id_chars_1_0; output_id_data_1_1 <= id_chars_1_1; output_id_data_1_2 <= id_chars_1_2; output_id_data_1_3 <= id_chars_1_3;
                    output_id_data_2_0 <= id_chars_2_0; output_id_data_2_1 <= id_chars_2_1; output_id_data_2_2 <= id_chars_2_2; output_id_data_2_3 <= id_chars_2_3;
                    output_id_data_3_0 <= id_chars_3_0; output_id_data_3_1 <= id_chars_3_1; output_id_data_3_2 <= id_chars_3_2; output_id_data_3_3 <= id_chars_3_3;
                    output_name_len_0 <= name_len_0;
                    output_name_len_1 <= name_len_1;
                    output_name_len_2 <= name_len_2;
                    output_name_len_3 <= name_len_3;
                    output_name_data_0_0 <= name_chars_0_0; output_name_data_0_1 <= name_chars_0_1; output_name_data_0_2 <= name_chars_0_2; output_name_data_0_3 <= name_chars_0_3;
                    output_name_data_0_4 <= name_chars_0_4; output_name_data_0_5 <= name_chars_0_5; output_name_data_0_6 <= name_chars_0_6; output_name_data_0_7 <= name_chars_0_7;
                    output_name_data_0_8 <= name_chars_0_8; output_name_data_0_9 <= name_chars_0_9; output_name_data_0_10 <= name_chars_0_10; output_name_data_0_11 <= name_chars_0_11;
                    output_name_data_0_12 <= name_chars_0_12; output_name_data_0_13 <= name_chars_0_13; output_name_data_0_14 <= name_chars_0_14; output_name_data_0_15 <= name_chars_0_15;
                    output_name_data_1_0 <= name_chars_1_0; output_name_data_1_1 <= name_chars_1_1; output_name_data_1_2 <= name_chars_1_2; output_name_data_1_3 <= name_chars_1_3;
                    output_name_data_1_4 <= name_chars_1_4; output_name_data_1_5 <= name_chars_1_5; output_name_data_1_6 <= name_chars_1_6; output_name_data_1_7 <= name_chars_1_7;
                    output_name_data_1_8 <= name_chars_1_8; output_name_data_1_9 <= name_chars_1_9; output_name_data_1_10 <= name_chars_1_10; output_name_data_1_11 <= name_chars_1_11;
                    output_name_data_1_12 <= name_chars_1_12; output_name_data_1_13 <= name_chars_1_13; output_name_data_1_14 <= name_chars_1_14; output_name_data_1_15 <= name_chars_1_15;
                    output_name_data_2_0 <= name_chars_2_0; output_name_data_2_1 <= name_chars_2_1; output_name_data_2_2 <= name_chars_2_2; output_name_data_2_3 <= name_chars_2_3;
                    output_name_data_2_4 <= name_chars_2_4; output_name_data_2_5 <= name_chars_2_5; output_name_data_2_6 <= name_chars_2_6; output_name_data_2_7 <= name_chars_2_7;
                    output_name_data_2_8 <= name_chars_2_8; output_name_data_2_9 <= name_chars_2_9; output_name_data_2_10 <= name_chars_2_10; output_name_data_2_11 <= name_chars_2_11;
                    output_name_data_2_12 <= name_chars_2_12; output_name_data_2_13 <= name_chars_2_13; output_name_data_2_14 <= name_chars_2_14; output_name_data_2_15 <= name_chars_2_15;
                    output_name_data_3_0 <= name_chars_3_0; output_name_data_3_1 <= name_chars_3_1; output_name_data_3_2 <= name_chars_3_2; output_name_data_3_3 <= name_chars_3_3;
                    output_name_data_3_4 <= name_chars_3_4; output_name_data_3_5 <= name_chars_3_5; output_name_data_3_6 <= name_chars_3_6; output_name_data_3_7 <= name_chars_3_7;
                    output_name_data_3_8 <= name_chars_3_8; output_name_data_3_9 <= name_chars_3_9; output_name_data_3_10 <= name_chars_3_10; output_name_data_3_11 <= name_chars_3_11;
                    output_name_data_3_12 <= name_chars_3_12; output_name_data_3_13 <= name_chars_3_13; output_name_data_3_14 <= name_chars_3_14; output_name_data_3_15 <= name_chars_3_15;
                    output_score_0 <= scores_0;
                    output_score_1 <= scores_1;
                    output_score_2 <= scores_2;
                    output_score_3 <= scores_3;
                end
                DONE_STATE: begin
                    done <= 1'b1;
                end
                default: begin
                    state <= IDLE;
                    done <= 1'b0;
                end
            endcase
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) next_state = COMPUTE;
            end
            COMPUTE: begin
                next_state = DONE_STATE;
            end
            DONE_STATE: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

endmodule