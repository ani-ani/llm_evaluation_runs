module filter_by_prefix(
    input clk,
    input rst_n,
    input start,
    input [7:0] prefix [0:7],
    input [7:0] strings [0:7][0:7],
    input [2:0] num_strings,
    input [2:0] prefix_len,
    output reg [7:0] results [0:7][0:7],
    output reg [2:0] result_count,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] CHECK_STRING = 3'd1;
    localparam [2:0] COMPARE_CHAR = 3'd2;
    localparam [2:0] ADD_RESULT = 3'd3;
    localparam [2:0] DONE_STATE = 3'd4;

    reg [2:0] state, next_state;
    reg [2:0] string_index;
    reg [2:0] char_index;
    reg [2:0] result_index;
    reg [2:0] match_flag;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd100;

    // Initialize all registers
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            string_index <= 3'd0;
            char_index <= 3'd0;
            result_index <= 3'd0;
            match_flag <= 3'd0;
            result_count <= 3'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            
            // Initialize results array
            integer i, j;
            for (i = 0; i < 8; i = i + 1) begin
                for (j = 0; j < 8; j = j + 1) begin
                    results[i][j] <= 8'd0;
                end
            end
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        next_state <= CHECK_STRING;
                        string_index <= 3'd0;
                        result_index <= 3'd0;
                        result_count <= 3'd0;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                CHECK_STRING: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (string_index < num_strings) begin
                        char_index <= 3'd0;
                        match_flag <= 3'd1;
                        next_state <= COMPARE_CHAR;
                    end else begin
                        next_state <= DONE_STATE;
                    end
                end

                COMPARE_CHAR: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (char_index < prefix_len) begin
                        if (strings[string_index][char_index] != prefix[char_index]) begin
                            match_flag <= 3'd0;
                        end
                        char_index <= char_index + 3'd1;
                        next_state <= COMPARE_CHAR;
                    end else begin
                        if (match_flag) begin
                            next_state <= ADD_RESULT;
                        end else begin
                            string_index <= string_index + 3'd1;
                            next_state <= CHECK_STRING;
                        end
                    end
                end

                ADD_RESULT: begin
                    cycle_count <= cycle_count + 8'd1;
                    // Copy matching string to results
                    integer j;
                    for (j = 0; j < 8; j = j + 1) begin
                        results[result_index][j] <= strings[string_index][j];
                    end
                    result_count <= result_count + 3'd1;
                    result_index <= result_index + 3'd1;
                    string_index <= string_index + 3'd1;
                    next_state <= CHECK_STRING;
                end

                DONE_STATE: begin
                    done <= 1'b1;
                    next_state <= IDLE;
                end

                default: next_state <= IDLE;
            endcase
        end
    end
endmodule