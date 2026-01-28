module substring_search(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] str_0 [0:7],
    input wire [7:0] str_1 [0:7],
    input wire [7:0] str_2 [0:7],
    input wire [7:0] str_3 [0:7],
    input wire [7:0] str_4 [0:7],
    input wire [7:0] str_5 [0:7],
    input wire [7:0] str_6 [0:7],
    input wire [7:0] str_7 [0:7],
    input wire [7:0] str_8 [0:7],
    input wire [7:0] str_9 [0:7],
    input wire [7:0] str_10 [0:7],
    input wire [7:0] str_11 [0:7],
    input wire [7:0] str_12 [0:7],
    input wire [7:0] str_13 [0:7],
    input wire [7:0] str_14 [0:7],
    input wire [7:0] str_15 [0:7],
    input wire [7:0] sub_str [0:7],
    input wire [3:0] num_strings,
    input wire [3:0] sub_len,
    output reg found,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] SEARCH = 3'd1;
    localparam [2:0] COMPARE = 3'd2;
    localparam [2:0] FINISH = 3'd3;

    reg [2:0] state, next_state;
    reg [3:0] str_idx;
    reg [3:0] char_idx;
    reg [3:0] sub_idx;
    reg [3:0] match_count;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd100;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            str_idx <= 4'd0;
            char_idx <= 4'd0;
            sub_idx <= 4'd0;
            match_count <= 4'd0;
            found <= 1'b0;
            done <= 1'b0;
            cycle_count <= 8'd0;
        end else begin
            state <= next_state;
            cycle_count <= cycle_count + 8'd1;
        end
    end

    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = SEARCH;
                    str_idx = 4'd0;
                    char_idx = 4'd0;
                    sub_idx = 4'd0;
                    match_count = 4'd0;
                    found = 1'b0;
                    done = 1'b0;
                end
            end

            SEARCH: begin
                if (str_idx < num_strings) begin
                    if (char_idx <= 8'd7 - sub_len) begin
                        next_state = COMPARE;
                    end else begin
                        char_idx = 4'd0;
                        str_idx = str_idx + 4'd1;
                    end
                end else begin
                    next_state = FINISH;
                end
            end

            COMPARE: begin
                if (sub_idx < sub_len) begin
                    case (str_idx)
                        4'd0: if (str_0[char_idx + sub_idx] == sub_str[sub_idx]) match_count = match_count + 4'd1;
                        4'd1: if (str_1[char_idx + sub_idx] == sub_str[sub_idx]) match_count = match_count + 4'd1;
                        4'd2: if (str_2[char_idx + sub_idx] == sub_str[sub_idx]) match_count = match_count + 4'd1;
                        4'd3: if (str_3[char_idx + sub_idx] == sub_str[sub_idx]) match_count = match_count + 4'd1;
                        4'd4: if (str_4[char_idx + sub_idx] == sub_str[sub_idx]) match_count = match_count + 4'd1;
                        4'd5: if (str_5[char_idx + sub_idx] == sub_str[sub_idx]) match_count = match_count + 4'd1;
                        4'd6: if (str_6[char_idx + sub_idx] == sub_str[sub_idx]) match_count = match_count + 4'd1;
                        4'd7: if (str_7[char_idx + sub_idx] == sub_str[sub_idx]) match_count = match_count + 4'd1;
                        4'd8: if (str_8[char_idx + sub_idx] == sub_str[sub_idx]) match_count = match_count + 4'd1;
                        4'd9: if (str_9[char_idx + sub_idx] == sub_str[sub_idx]) match_count = match_count + 4'd1;
                        4'd10: if (str_10[char_idx + sub_idx] == sub_str[sub_idx]) match_count = match_count + 4'd1;
                        4'd11: if (str_11[char_idx + sub_idx] == sub_str[sub_idx]) match_count = match_count + 4'd1;
                        4'd12: if (str_12[char_idx + sub_idx] == sub_str[sub_idx]) match_count = match_count + 4'd1;
                        4'd13: if (str_13[char_idx + sub_idx] == sub_str[sub_idx]) match_count = match_count + 4'd1;
                        4'd14: if (str_14[char_idx + sub_idx] == sub_str[sub_idx]) match_count = match_count + 4'd1;
                        4'd15: if (str_15[char_idx + sub_idx] == sub_str[sub_idx]) match_count = match_count + 4'd1;
                        default: ;
                    endcase
                    sub_idx = sub_idx + 4'd1;
                end else begin
                    if (match_count == sub_len) begin
                        found = 1'b1;
                    end
                    sub_idx = 4'd0;
                    match_count = 4'd0;
                    char_idx = char_idx + 4'd1;
                    next_state = SEARCH;
                end
            end

            FINISH: begin
                done = 1'b1;
                next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
    end

    // Prevent infinite loops
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cycle_count <= 8'd0;
        end else if (cycle_count >= MAX_CYCLES) begin
            next_state = FINISH;
        end
    end

endmodule