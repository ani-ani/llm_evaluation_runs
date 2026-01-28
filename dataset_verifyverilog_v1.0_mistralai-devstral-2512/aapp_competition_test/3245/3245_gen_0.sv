module shell_history(
    input clk,
    input rst_n,
    input start,
    input [7:0] char_in,
    input char_valid,
    input char_done,
    output reg result_valid,
    output reg [7:0] result_char,
    output reg result_done,
    output reg busy
);

    // Constants
    localparam [4:0] MAX_HISTORY = 5'd32;
    localparam [5:0] MAX_LENGTH = 6'd64;
    localparam [7:0] UP_ARROW = 8'd94;

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] INPUT = 3'd1;
    localparam [2:0] OUTPUT = 3'd2;
    localparam [2:0] SEARCH = 3'd3;

    // Registers
    reg [2:0] state, next_state;
    reg [4:0] history_count;
    reg [5:0] current_length;
    reg [5:0] output_index;
    reg [5:0] search_index;
    reg [4:0] up_count;
    reg [7:0] current_line [0:63];
    reg [7:0] history [0:31][0:63];
    reg [4:0] history_lengths [0:31];
    reg [4:0] search_ptr;
    reg [4:0] match_index;
    reg match_found;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            history_count <= 5'd0;
            current_length <= 6'd0;
            output_index <= 6'd0;
            search_index <= 6'd0;
            up_count <= 5'd0;
            search_ptr <= 5'd0;
            match_index <= 5'd0;
            match_found <= 1'b0;
            result_valid <= 1'b0;
            result_char <= 8'd0;
            result_done <= 1'b0;
            busy <= 1'b0;

            // Initialize history
            integer i, j;
            for (i = 0; i < 32; i = i + 1) begin
                for (j = 0; j < 64; j = j + 1) begin
                    history[i][j] <= 8'd0;
                end
                history_lengths[i] <= 5'd0;
            end

            // Initialize current line
            for (j = 0; j < 64; j = j + 1) begin
                current_line[j] <= 8'd0;
            end
        end else begin
            state <= next_state;

            case (state)
                IDLE: begin
                    busy <= 1'b0;
                    result_valid <= 1'b0;
                    result_done <= 1'b0;
                    if (start) begin
                        next_state <= INPUT;
                        busy <= 1'b1;
                        current_length <= 6'd0;
                        up_count <= 5'd0;
                        match_found <= 1'b0;
                        // Clear current line
                        integer j;
                        for (j = 0; j < 64; j = j + 1) begin
                            current_line[j] <= 8'd0;
                        end
                    end else begin
                        next_state <= IDLE;
                    end
                end

                INPUT: begin
                    busy <= 1'b1;
                    result_valid <= 1'b0;
                    result_done <= 1'b0;

                    if (char_valid) begin
                        if (char_in == UP_ARROW) begin
                            // Up arrow pressed
                            up_count <= up_count + 5'd1;
                            next_state <= SEARCH;
                        end else begin
                            // Normal character
                            up_count <= 5'd0;
                            if (current_length < MAX_LENGTH) begin
                                current_line[current_length] <= char_in;
                                current_length <= current_length + 6'd1;
                            end
                            next_state <= INPUT;
                        end
                    end else if (char_done) begin
                        // End of input, add to history
                        if (history_count < MAX_HISTORY) begin
                            // Add to history
                            integer j;
                            for (j = 0; j < 64; j = j + 1) begin
                                history[history_count][j] <= current_line[j];
                            end
                            history_lengths[history_count] <= current_length;
                            history_count <= history_count + 5'd1;
                        end else begin
                            // Shift history
                            integer i, j;
                            for (i = 0; i < 31; i = i + 1) begin
                                for (j = 0; j < 64; j = j + 1) begin
                                    history[i][j] <= history[i + 5'd1][j];
                                end
                                history_lengths[i] <= history_lengths[i + 5'd1];
                            end
                            // Add new command
                            for (j = 0; j < 64; j = j + 1) begin
                                history[31][j] <= current_line[j];
                            end
                            history_lengths[31] <= current_length;
                        end
                        next_state <= OUTPUT;
                        output_index <= 6'd0;
                    end else begin
                        next_state <= INPUT;
                    end
                end

                SEARCH: begin
                    busy <= 1'b1;
                    result_valid <= 1'b0;
                    result_done <= 1'b0;

                    if (!match_found) begin
                        // Start search from most recent
                        search_ptr <= history_count - 5'd1;
                        match_found <= 1'b0;
                        search_index <= 6'd0;
                    end

                    if (search_ptr >= 5'd0) begin
                        // Check if current history entry matches prefix
                        if (search_index < current_length) begin
                            if (history[search_ptr][search_index] == current_line[search_index]) begin
                                search_index <= search_index + 6'd1;
                                next_state <= SEARCH;
                            end else begin
                                // No match, try next entry
                                search_ptr <= search_ptr - 5'd1;
                                search_index <= 6'd0;
                                next_state <= SEARCH;
                            end
                        end else begin
                            // Full prefix match found
                            match_found <= 1'b1;
                            match_index <= search_ptr;
                            next_state <= SEARCH;
                        end
                    end else begin
                        // No match found or search complete
                        if (match_found) begin
                            // Replace current line with matched command
                            integer j;
                            for (j = 0; j < 64; j = j + 1) begin
                                current_line[j] <= history[match_index][j];
                            end
                            current_length <= history_lengths[match_index];
                        end
                        next_state <= INPUT;
                    end
                end

                OUTPUT: begin
                    busy <= 1'b1;
                    if (output_index < current_length) begin
                        result_char <= current_line[output_index];
                        result_valid <= 1'b1;
                        result_done <= 1'b0;
                        output_index <= output_index + 6'd1;
                        next_state <= OUTPUT;
                    end else begin
                        result_char <= 8'd0;
                        result_valid <= 1'b0;
                        result_done <= 1'b1;
                        next_state <= IDLE;
                    end
                end

                default: begin
                    next_state <= IDLE;
                    busy <= 1'b0;
                    result_valid <= 1'b0;
                    result_done <= 1'b0;
                end
            endcase
        end
    end

endmodule