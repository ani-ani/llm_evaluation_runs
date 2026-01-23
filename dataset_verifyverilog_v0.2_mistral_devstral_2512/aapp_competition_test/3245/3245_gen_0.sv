module fish_shell_sim (
    input clk,
    input rst_n,
    input start,
    input [7:0] char_in,
    output reg [15:0] result_out,
    output reg output_valid,
    output reg done
);

    // Parameters
    parameter MAX_HISTORY = 8;
    parameter MAX_CMD_LEN = 16;

    // State definitions
    typedef enum logic [2:0] {
        IDLE,
        TYPING,
        EXPANDING,
        OUTPUT,
        UPDATE_HISTORY
    } state_t;

    // Internal registers
    state_t current_state, next_state;
    reg [7:0] history [0:MAX_HISTORY-1][0:MAX_CMD_LEN-1];
    reg [2:0] history_len;
    reg [7:0] current_buffer [0:MAX_CMD_LEN-1];
    reg [3:0] buffer_len;
    reg [2:0] expansion_index;
    reg [3:0] output_index;
    reg [3:0] prefix_len;
    reg [2:0] search_index;
    reg [3:0] char_count;

    // State machine logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            history_len <= 0;
            buffer_len <= 0;
            expansion_index <= 0;
            output_index <= 0;
            prefix_len <= 0;
            search_index <= 0;
            char_count <= 0;
            result_out <= 16'b0;
            output_valid <= 0;
            done <= 0;
        end else begin
            current_state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        next_state = current_state;
        case (current_state)
            IDLE: begin
                if (start) next_state = TYPING;
            end
            TYPING: begin
                if (char_in == 8'b0) begin // Enter key
                    next_state = OUTPUT;
                end else if (char_in == "^") begin
                    next_state = EXPANDING;
                end
            end
            EXPANDING: begin
                next_state = TYPING;
            end
            OUTPUT: begin
                if (output_index == buffer_len - 1) begin
                    next_state = UPDATE_HISTORY;
                end
            end
            UPDATE_HISTORY: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

    // Datapath logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all registers
            for (int i = 0; i < MAX_HISTORY; i++) begin
                for (int j = 0; j < MAX_CMD_LEN; j++) begin
                    history[i][j] <= 8'b0;
                end
            end
            for (int j = 0; j < MAX_CMD_LEN; j++) begin
                current_buffer[j] <= 8'b0;
            end
        end else begin
            case (current_state)
                TYPING: begin
                    if (char_in == "^") begin
                        // Store prefix length
                        prefix_len <= buffer_len;
                        // Initialize search index
                        search_index <= history_len - 1;
                    end else if (char_in != 8'b0) begin
                        // Append character to buffer
                        current_buffer[buffer_len] <= char_in;
                        buffer_len <= buffer_len + 1;
                        // Reset expansion index
                        expansion_index <= 0;
                    end
                end
                EXPANDING: begin
                    // Search history for matching prefix
                    if (search_index >= 0) begin
                        reg [7:0] prefix [0:MAX_CMD_LEN-1];
                        for (int i = 0; i < prefix_len; i++) begin
                            prefix[i] = current_buffer[i];
                        end
                        reg match = 1'b1;
                        for (int i = 0; i < prefix_len; i++) begin
                            if (history[search_index][i] != prefix[i]) begin
                                match = 1'b0;
                            end
                        end
                        if (match) begin
                            // Copy matching command to current buffer
                            for (int i = 0; i < MAX_CMD_LEN; i++) begin
                                current_buffer[i] <= history[search_index][i];
                            end
                            buffer_len <= MAX_CMD_LEN;
                            // Update search index for next expansion
                            expansion_index <= expansion_index + 1;
                            search_index <= search_index - 1;
                        end else begin
                            search_index <= search_index - 1;
                        end
                    end
                end
                OUTPUT: begin
                    if (output_index < buffer_len) begin
                        result_out <= {current_buffer[output_index + 1], current_buffer[output_index]};
                        output_valid <= 1'b1;
                        output_index <= output_index + 2;
                    end
                    if (output_index >= buffer_len - 1) begin
                        done <= 1'b1;
                    end
                end
                UPDATE_HISTORY: begin
                    // Add current buffer to history
                    if (buffer_len > 0) begin
                        if (history_len < MAX_HISTORY) begin
                            for (int i = 0; i < MAX_CMD_LEN; i++) begin
                                history[history_len][i] <= current_buffer[i];
                            end
                            history_len <= history_len + 1;
                        end else begin
                            // Shift history
                            for (int i = 0; i < MAX_HISTORY - 1; i++) begin
                                for (int j = 0; j < MAX_CMD_LEN; j++) begin
                                    history[i][j] <= history[i + 1][j];
                                end
                            end
                            for (int j = 0; j < MAX_CMD_LEN; j++) begin
                                history[MAX_HISTORY - 1][j] <= current_buffer[j];
                            end
                        end
                    end
                    // Reset buffer
                    for (int j = 0; j < MAX_CMD_LEN; j++) begin
                        current_buffer[j] <= 8'b0;
                    end
                    buffer_len <= 0;
                    output_index <= 0;
                    output_valid <= 0;
                    done <= 0;
                end
            endcase
        end
    end

endmodule