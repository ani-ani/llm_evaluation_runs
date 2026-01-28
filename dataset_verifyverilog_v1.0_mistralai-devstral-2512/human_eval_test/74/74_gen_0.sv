module total_match(
    input clk,
    input rst_n,
    input start,
    input [2:0] len1,
    input [2:0] len2,
    input str1_valid,
    input str2_valid,
    input [7:0] char_data,
    input char_valid,
    output reg [1:0] result_select,
    output reg [2:0] result_len,
    output reg result_ready,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE    = 3'd0;
    localparam [2:0] COUNT1  = 3'd1;
    localparam [2:0] COUNT2  = 3'd2;
    localparam [2:0] COMPARE = 3'd3;
    localparam [2:0] DONE    = 3'd4;

    reg [2:0] state;
    reg [2:0] next_state;

    // Counters
    reg [2:0] str1_idx;
    reg [2:0] str2_idx;
    reg [5:0] total1;
    reg [5:0] total2;
    reg [2:0] char_count;

    // Control signals
    reg char_received;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            str1_idx <= 3'd0;
            str2_idx <= 3'd0;
            total1 <= 6'd0;
            total2 <= 6'd0;
            char_count <= 3'd0;
            result_select <= 2'd0;
            result_len <= 3'd0;
            result_ready <= 1'b0;
            done <= 1'b0;
            char_received <= 1'b0;
        end else begin
            state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = COUNT1;
                end
            end

            COUNT1: begin
                if (char_valid) begin
                    char_received = 1'b1;
                end else if (char_received) begin
                    // End of current string
                    total1 = total1 + char_count + 3'd1;  // +1 for current char
                    char_count = 3'd0;
                    char_received = 1'b0;
                    if (str1_idx == len1 - 3'd1) begin
                        next_state = COUNT2;
                    end else begin
                        str1_idx = str1_idx + 3'd1;
                    end
                end else if (!str1_valid) begin
                    // No more strings in list 1
                    next_state = COUNT2;
                end
            end

            COUNT2: begin
                if (char_valid) begin
                    char_received = 1'b1;
                end else if (char_received) begin
                    // End of current string
                    total2 = total2 + char_count + 3'd1;  // +1 for current char
                    char_count = 3'd0;
                    char_received = 1'b0;
                    if (str2_idx == len2 - 3'd1) begin
                        next_state = COMPARE;
                    end else begin
                        str2_idx = str2_idx + 3'd1;
                    end
                end else if (!str2_valid) begin
                    // No more strings in list 2
                    next_state = COMPARE;
                end
            end

            COMPARE: begin
                if (total1 <= total2) begin
                    result_select = 2'd0;
                    result_len = len1;
                end else begin
                    result_select = 2'd1;
                    result_len = len2;
                end
                result_ready = 1'b1;
                next_state = DONE;
            end

            DONE: begin
                done = 1'b1;
                next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
    end

    // Character counting logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            char_count <= 3'd0;
        end else begin
            if (char_valid && (state == COUNT1 || state == COUNT2)) begin
                char_count <= char_count + 3'd1;
            end
        end
    end

    // Reset outputs after one cycle
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            result_ready <= 1'b0;
            done <= 1'b0;
        end else begin
            if (state == DONE) begin
                result_ready <= 1'b0;
            end
            if (state != DONE) begin
                done <= 1'b0;
            end
        end
    end

endmodule