module fish_shell(
    input clk,
    input rst_n,
    input start,
    input [7:0] cmd_in [0:31],
    input [5:0] cmd_len,
    output reg [7:0] cmd_out [0:31],
    output reg [5:0] out_len,
    output reg done
);

    // Parameters
    localparam MAX_CMD_LEN = 32;
    localparam MAX_HISTORY = 8;
    localparam CHAR_WIDTH = 8;

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] PROCESS = 3'd1;
    localparam [2:0] SEARCH = 3'd2;
    localparam [2:0] OUTPUT = 3'd3;
    localparam [2:0] DONE = 3'd4;

    // State registers
    reg [2:0] state, next_state;

    // History buffer
    reg [7:0] history_cmd [0:MAX_HISTORY-1][0:MAX_CMD_LEN-1];
    reg [5:0] history_len [0:MAX_HISTORY-1];
    reg [2:0] history_ptr;
    reg [2:0] history_count;

    // Current command processing
    reg [7:0] current_cmd [0:MAX_CMD_LEN-1];
    reg [5:0] current_len;
    reg [5:0] cmd_index;
    reg [5:0] up_count;
    reg [5:0] search_index;
    reg [2:0] history_search_ptr;
    reg found_match;

    // Cycle counter for timeout prevention
    reg [9:0] cycle_count;
    localparam [9:0] MAX_CYCLES = 10'd512;

    // Initialize all registers
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            history_ptr <= 3'd0;
            history_count <= 3'd0;
            current_len <= 6'd0;
            cmd_index <= 6'd0;
            up_count <= 6'd0;
            search_index <= 6'd0;
            history_search_ptr <= 3'd0;
            found_match <= 1'b0;
            cycle_count <= 10'd0;
            done <= 1'b0;
            out_len <= 6'd0;

            // Initialize history
            integer i, j;
            for (i = 0; i < MAX_HISTORY; i = i + 1) begin
                history_len[i] <= 6'd0;
                for (j = 0; j < MAX_CMD_LEN; j = j + 1) begin
                    history_cmd[i][j] <= 8'd0;
                end
            end

            // Initialize current command
            for (j = 0; j < MAX_CMD_LEN; j = j + 1) begin
                current_cmd[j] <= 8'd0;
            end

            // Initialize output
            for (j = 0; j < MAX_CMD_LEN; j = j + 1) begin
                cmd_out[j] <= 8'd0;
            end

        end else begin
            state <= next_state;

            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 10'd0;
                    if (start) begin
                        next_state <= PROCESS;
                        cmd_index <= 6'd0;
                        current_len <= 6'd0;
                        up_count <= 6'd0;
                        // Clear current command
                        integer j;
                        for (j = 0; j < MAX_CMD_LEN; j = j + 1) begin
                            current_cmd[j] <= 8'd0;
                        end
                    end else begin
                        next_state <= IDLE;
                    end
                end

                PROCESS: begin
                    cycle_count <= cycle_count + 10'd1;

                    if (cmd_index < cmd_len) begin
                        if (cmd_in[cmd_index] == 8'd94) begin  // '^'
                            up_count <= up_count + 6'd1;
                            cmd_index <= cmd_index + 6'd1;
                            if (cmd_index == cmd_len) begin
                                next_state <= SEARCH;
                                search_index <= 6'd0;
                                history_search_ptr <= history_ptr;
                                found_match <= 1'b0;
                            end
                        end else begin
                            if (up_count > 6'd0) begin
                                next_state <= SEARCH;
                                search_index <= 6'd0;
                                history_search_ptr <= history_ptr;
                                found_match <= 1'b0;
                            end else begin
                                current_cmd[current_len] <= cmd_in[cmd_index];
                                current_len <= current_len + 6'd1;
                                cmd_index <= cmd_index + 6'd1;
                            end
                        end
                    end else begin
                        next_state <= OUTPUT;
                    end

                    if (cycle_count >= MAX_CYCLES) begin
                        next_state <= DONE;
                    end
                end

                SEARCH: begin
                    cycle_count <= cycle_count + 10'd1;

                    if (!found_match && history_count > 3'd0) begin
                        // Check if current history entry matches prefix
                        reg match;
                        integer i;
                        match = 1'b1;
                        for (i = 0; i < current_len - up_count; i = i + 1) begin
                            if (history_cmd[history_search_ptr][i] != current_cmd[i]) begin
                                match = 1'b0;
                            end
                        end

                        if (match) begin
                            found_match = 1'b1;
                            // Copy matched command to current
                            current_len <= history_len[history_search_ptr];
                            for (i = 0; i < MAX_CMD_LEN; i = i + 1) begin
                                current_cmd[i] <= history_cmd[history_search_ptr][i];
                            end
                        end

                        // Move to next history entry (circular)
                        if (history_search_ptr == 3'd0) begin
                            history_search_ptr <= history_count - 3'd1;
                        end else begin
                            history_search_ptr <= history_search_ptr - 3'd1;
                        end

                        if (history_search_ptr == history_ptr) begin
                            found_match = 1'b1;  // Stop if we've checked all
                        end
                    end

                    if (found_match) begin
                        next_state <= PROCESS;
                        up_count <= 6'd0;
                    end else if (cycle_count >= MAX_CYCLES) begin
                        next_state <= DONE;
                    end
                end

                OUTPUT: begin
                    cycle_count <= cycle_count + 10'd1;

                    // Copy current command to output
                    out_len <= current_len;
                    integer i;
                    for (i = 0; i < MAX_CMD_LEN; i = i + 1) begin
                        cmd_out[i] <= current_cmd[i];
                    end

                    // Add to history
                    if (history_count < MAX_HISTORY) begin
                        history_count <= history_count + 3'd1;
                    end

                    // Store in history
                    for (i = 0; i < MAX_CMD_LEN; i = i + 1) begin
                        history_cmd[history_ptr][i] <= current_cmd[i];
                    end
                    history_len[history_ptr] <= current_len;

                    // Update history pointer
                    if (history_ptr == MAX_HISTORY - 3'd1) begin
                        history_ptr <= 3'd0;
                    end else begin
                        history_ptr <= history_ptr + 3'd1;
                    end

                    next_state <= DONE;
                end

                DONE: begin
                    done <= 1'b1;
                    next_state <= IDLE;
                end

                default: begin
                    next_state <= IDLE;
                    done <= 1'b0;
                end
            endcase
        end
    end

endmodule