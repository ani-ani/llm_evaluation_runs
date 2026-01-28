module total_match (
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
    localparam [3:0] STATE_IDLE          = 4'd0;
    localparam [3:0] STATE_COUNT1_START  = 4'd1;
    localparam [3:0] STATE_COUNT1_LOOP   = 4'd2;
    localparam [3:0] STATE_COUNT1_NEXT   = 4'd3;
    localparam [3:0] STATE_COUNT2_START  = 4'd4;
    localparam [3:0] STATE_COUNT2_LOOP   = 4'd5;
    localparam [3:0] STATE_COUNT2_NEXT   = 4'd6;
    localparam [3:0] STATE_COMPARE       = 4'd7;
    localparam [3:0] STATE_DONE          = 4'd8;

    reg [3:0] state;
    
    // Counters and registers
    reg [2:0] str_idx;        // Current string index (0-7)
    reg [4:0] char_idx;       // Character index within string (0-31)
    reg [15:0] total_count1;  // Accumulator for list 1
    reg [15:0] total_count2;  // Accumulator for list 2
    reg [15:0] current_total; // Working accumulator
    reg list_sel;             // 0 for list 1, 1 for list 2
    
    // Helper signal to get current string data based on list and index
    reg [255:0] current_str_data;
    
    always @(*) begin
        // Mux to select string data based on list_sel and str_idx
        if (list_sel == 1'b0) begin
            case (str_idx)
                3'd0: current_str_data = list1_str0;
                3'd1: current_str_data = list1_str1;
                3'd2: current_str_data = list1_str2;
                3'd3: current_str_data = list1_str3;
                3'd4: current_str_data = list1_str4;
                3'd5: current_str_data = list1_str5;
                3'd6: current_str_data = list1_str6;
                3'd7: current_str_data = list1_str7;
                default: current_str_data = 256'd0;
            endcase
        end else begin
            case (str_idx)
                3'd0: current_str_data = list2_str0;
                3'd1: current_str_data = list2_str1;
                3'd2: current_str_data = list2_str2;
                3'd3: current_str_data = list2_str3;
                3'd4: current_str_data = list2_str4;
                3'd5: current_str_data = list2_str5;
                3'd6: current_str_data = list2_str6;
                3'd7: current_str_data = list2_str7;
                default: current_str_data = 256'd0;
            endcase
        end
    end

    // Extract byte at current char index (Little Endian: index 0 is bits 7:0)
    wire [7:0] current_char;
    assign current_char = current_str_data[(char_idx * 8) +: 8];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= STATE_IDLE;
            result_len <= 3'd0;
            result_sel <= 8'd0;
            done <= 1'b0;
            str_idx <= 3'd0;
            char_idx <= 5'd0;
            total_count1 <= 16'd0;
            total_count2 <= 16'd0;
            current_total <= 16'd0;
            list_sel <= 1'b0;
        end else begin
            case (state)
                STATE_IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        total_count1 <= 16'd0;
                        total_count2 <= 16'd0;
                        current_total <= 16'd0;
                        str_idx <= 3'd0;
                        char_idx <= 5'd0;
                        list_sel <= 1'b0;
                        state <= STATE_COUNT1_START;
                    end
                end

                // --- List 1 Processing ---
                STATE_COUNT1_START: begin
                    // Check if we have processed all strings in list 1
                    if (str_idx >= len1) begin
                        state <= STATE_COUNT2_START;
                        str_idx <= 3'd0;
                    end else begin
                        char_idx <= 5'd0;
                        state <= STATE_COUNT1_LOOP;
                    end
                end

                STATE_COUNT1_LOOP: begin
                    if (char_idx >= 5'd32) begin
                        // End of fixed-width string reached
                        total_count1 <= current_total;
                        current_total <= 16'd0;
                        state <= STATE_COUNT1_NEXT;
                    end else if (current_char == 8'd0) begin
                        // Found null terminator
                        total_count1 <= current_total;
                        current_total <= 16'd0;
                        state <= STATE_COUNT1_NEXT;
                    end else begin
                        // Valid character, increment count
                        current_total <= current_total + 16'd1;
                        char_idx <= char_idx + 5'd1;
                    end
                end

                STATE_COUNT1_NEXT: begin
                    str_idx <= str_idx + 3'd1;
                    state <= STATE_COUNT1_START;
                end

                // --- List 2 Processing ---
                STATE_COUNT2_START: begin
                    list_sel <= 1'b1;
                    // Check if we have processed all strings in list 2
                    if (str_idx >= len2) begin
                        state <= STATE_COMPARE;
                    end else begin
                        char_idx <= 5'd0;
                        state <= STATE_COUNT2_LOOP;
                    end
                end

                STATE_COUNT2_LOOP: begin
                    if (char_idx >= 5'd32) begin
                        total_count2 <= current_total;
                        current_total <= 16'd0;
                        state <= STATE_COUNT2_NEXT;
                    end else if (current_char == 8'd0) begin
                        total_count2 <= current_total;
                        current_total <= 16'd0;
                        state <= STATE_COUNT2_NEXT;
                    end else begin
                        current_total <= current_total + 16'd1;
                        char_idx <= char_idx + 5'd1;
                    end
                end

                STATE_COUNT2_NEXT: begin
                    str_idx <= str_idx + 3'd1;
                    state <= STATE_COUNT2_START;
                end

                // --- Comparison ---
                STATE_COMPARE: begin
                    if (total_count1 <= total_count2) begin
                        result_sel <= 8'd0; // List 1 wins (including tie)
                        result_len <= len1;
                    end else begin
                        result_sel <= 8'd1; // List 2 wins
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
                end
            endcase
        end
    end

endmodule