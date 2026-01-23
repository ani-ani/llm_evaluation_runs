module total_match(
    input clk,
    input rst_n,
    input start,
    input [2:0] len1,
    input [2:0] len2,
    input [255:0] list1_str0,
    input [255:0] list1_str1,
    input [255:0] list1_str2,
    input [255:0] list1_str3,
    input [255:0] list1_str4,
    input [255:0] list1_str5,
    input [255:0] list1_str6,
    input [255:0] list1_str7,
    input [255:0] list2_str0,
    input [255:0] list2_str1,
    input [255:0] list2_str2,
    input [255:0] list2_str3,
    input [255:0] list2_str4,
    input [255:0] list2_str5,
    input [255:0] list2_str6,
    input [255:0] list2_str7,
    output reg [2:0] result_len,
    output reg [7:0] result_sel,
    output reg done
);

    // State definitions
    localparam [3:0] STATE_IDLE = 4'd0;
    localparam [3:0] STATE_COUNT1_START = 4'd1;
    localparam [3:0] STATE_COUNT1_LOOP = 4'd2;
    localparam [3:0] STATE_COUNT1_NEXT_STR = 4'd3;
    localparam [3:0] STATE_COUNT2_START = 4'd4;
    localparam [3:0] STATE_COUNT2_LOOP = 4'd5;
    localparam [3:0] STATE_COUNT2_NEXT_STR = 4'd6;
    localparam [3:0] STATE_COMPARE = 4'd7;
    localparam [3:0] STATE_DONE = 4'd8;

    // Counters and accumulators
    reg [3:0] state;
    reg [15:0] count1;
    reg [15:0] count2;
    reg [2:0] str_idx1;
    reg [2:0] str_idx2;
    reg [4:0] char_idx1;
    reg [4:0] char_idx2;
    reg [7:0] current_byte1;
    reg [7:0] current_byte2;

    // Arrays for list1 and list2 strings
    reg [255:0] list1_strings [0:7];
    reg [255:0] list2_strings [0:7];

    // Initialize arrays
    integer i;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 0; i < 8; i = i + 1) begin
                list1_strings[i] <= 256'd0;
                list2_strings[i] <= 256'd0;
            end
        end else begin
            list1_strings[0] <= list1_str0;
            list1_strings[1] <= list1_str1;
            list1_strings[2] <= list1_str2;
            list1_strings[3] <= list1_str3;
            list1_strings[4] <= list1_str4;
            list1_strings[5] <= list1_str5;
            list1_strings[6] <= list1_str6;
            list1_strings[7] <= list1_str7;
            list2_strings[0] <= list2_str0;
            list2_strings[1] <= list2_str1;
            list2_strings[2] <= list2_str2;
            list2_strings[3] <= list2_str3;
            list2_strings[4] <= list2_str4;
            list2_strings[5] <= list2_str5;
            list2_strings[6] <= list2_str6;
            list2_strings[7] <= list2_str7;
        end
    end

    // Main state machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= STATE_IDLE;
            count1 <= 16'd0;
            count2 <= 16'd0;
            str_idx1 <= 3'd0;
            str_idx2 <= 3'd0;
            char_idx1 <= 5'd0;
            char_idx2 <= 5'd0;
            current_byte1 <= 8'd0;
            current_byte2 <= 8'd0;
            done <= 1'b0;
            result_sel <= 8'd0;
            result_len <= 3'd0;
        end else begin
            case (state)
                STATE_IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= STATE_COUNT1_START;
                    end
                end

                STATE_COUNT1_START: begin
                    str_idx1 <= 3'd0;
                    char_idx1 <= 5'd0;
                    count1 <= 16'd0;
                    state <= STATE_COUNT1_LOOP;
                end

                STATE_COUNT1_LOOP: begin
                    current_byte1 <= list1_strings[str_idx1][char_idx1*8 +: 8];
                    if (current_byte1 == 8'd0) begin
                        state <= STATE_COUNT1_NEXT_STR;
                    end else begin
                        count1 <= count1 + 16'd1;
                        char_idx1 <= char_idx1 + 5'd1;
                        if (char_idx1 == 5'd32) begin
                            state <= STATE_COUNT1_NEXT_STR;
                        end
                    end
                end

                STATE_COUNT1_NEXT_STR: begin
                    str_idx1 <= str_idx1 + 3'd1;
                    char_idx1 <= 5'd0;
                    if (str_idx1 == len1) begin
                        state <= STATE_COUNT2_START;
                    end else begin
                        state <= STATE_COUNT1_LOOP;
                    end
                end

                STATE_COUNT2_START: begin
                    str_idx2 <= 3'd0;
                    char_idx2 <= 5'd0;
                    count2 <= 16'd0;
                    state <= STATE_COUNT2_LOOP;
                end

                STATE_COUNT2_LOOP: begin
                    current_byte2 <= list2_strings[str_idx2][char_idx2*8 +: 8];
                    if (current_byte2 == 8'd0) begin
                        state <= STATE_COUNT2_NEXT_STR;
                    end else begin
                        count2 <= count2 + 16'd1;
                        char_idx2 <= char_idx2 + 5'd1;
                        if (char_idx2 == 5'd32) begin
                            state <= STATE_COUNT2_NEXT_STR;
                        end
                    end
                end

                STATE_COUNT2_NEXT_STR: begin
                    str_idx2 <= str_idx2 + 3'd1;
                    char_idx2 <= 5'd0;
                    if (str_idx2 == len2) begin
                        state <= STATE_COMPARE;
                    end else begin
                        state <= STATE_COUNT2_LOOP;
                    end
                end

                STATE_COMPARE: begin
                    if (count1 <= count2) begin
                        result_sel <= 8'd0;
                        result_len <= len1;
                    end else begin
                        result_sel <= 8'd1;
                        result_len <= len2;
                    end
                    state <= STATE_DONE;
                end

                STATE_DONE: begin
                    done <= 1'b1;
                    state <= STATE_IDLE;
                end

                default: begin
                    state <= STATE_IDLE;
                    done <= 1'b0;
                end
            endcase
        end
    end

endmodule