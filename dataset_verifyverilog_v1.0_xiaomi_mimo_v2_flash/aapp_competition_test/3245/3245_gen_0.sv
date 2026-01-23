module fish_shell (
    input clk,
    input rst_n,
    input start,
    input [31:0][7:0] cmd_in,
    input [5:0] cmd_len,
    output reg [31:0][7:0] cmd_out,
    output reg [5:0] out_len,
    output reg done
);

    // Parameters
    localparam [5:0] MAX_CMD_LEN = 6'd32;
    localparam [3:0] MAX_HISTORY = 4'd8;
    localparam [2:0] CHAR_WIDTH = 3'd8;
    localparam [5:0] MAX_CYCLES = 6'd64;

    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] INIT_PROCESS = 3'd1;
    localparam [2:0] PROCESS_CHAR = 3'd2;
    localparam [2:0] SEARCH_HISTORY = 3'd3;
    localparam [2:0] UPDATE_BUFFER = 3'd4;
    localparam [2:0] ADD_TO_HISTORY = 3'd5;
    localparam [2:0] FINISH = 3'd6;

    // State and control registers
    reg [2:0] state, next_state;
    reg [5:0] char_idx;
    reg [5:0] buffer_len;
    reg [7:0] current_buffer [0:31];
    reg [5:0] current_len;
    reg [3:0] history_wr_ptr;
    reg [3:0] hist_search_idx;
    reg [5:0] hist_search_len;
    reg [5:0] caret_count;
    reg [5:0] cycles;
    reg [7:0] temp_char;
    reg match_found;
    reg [5:0] prefix_len;
    reg [7:0] hist_cmd [0:7][0:31];
    reg [5:0] hist_lens [0:7];
    reg valid_history [0:7];

    integer i;

    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            cmd_out <= '{default: 8'd0};
            out_len <= 6'd0;
            char_idx <= 6'd0;
            buffer_len <= 6'd0;
            current_len <= 6'd0;
            history_wr_ptr <= 4'd0;
            hist_search_idx <= 4'd0;
            hist_search_len <= 6'd0;
            caret_count <= 6'd0;
            cycles <= 6'd0;
            match_found <= 1'b0;
            prefix_len <= 6'd0;
            temp_char <= 8'd0;
            for (i = 0; i < 32; i = i + 1) begin
                current_buffer[i] <= 8'd0;
                for (j = 0; j < 8; j = j + 1) begin
                    hist_cmd[j][i] <= 8'd0;
                end
            end
            for (i = 0; i < 8; i = i + 1) begin
                hist_lens[i] <= 6'd0;
                valid_history[i] <= 1'b0;
            end
        end else begin
            state <= next_state;
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycles <= 6'd0;
                    if (start) begin
                        char_idx <= 6'd0;
                        current_len <= 6'd0;
                    end
                end
                INIT_PROCESS: begin
                    cycles <= cycles + 6'd1;
                end
                PROCESS_CHAR: begin
                    cycles <= cycles + 6'd1;
                    char_idx <= char_idx + 6'd1;
                    if (temp_char != 8'h5E) begin
                        if (current_len < MAX_CMD_LEN) begin
                            current_buffer[current_len] <= temp_char;
                            current_len <= current_len + 6'd1;
                        end
                    end
                end
                SEARCH_HISTORY: begin
                    cycles <= cycles + 6'd1;
                    if (hist_search_idx < MAX_HISTORY) begin
                        if (valid_history[hist_search_idx] && (hist_lens[hist_search_idx] >= prefix_len)) begin
                            if (hist_lens[hist_search_idx] >= prefix_len) begin
                                match_found <= 1'b1;
                            end else begin
                                match_found <= 1'b0;
                            end
                        end else begin
                            match_found <= 1'b0;
                        end
                        hist_search_idx <= hist_search_idx + 4'd1;
                    end
                end
                UPDATE_BUFFER: begin
                    cycles <= cycles + 6'd1;
                    if (match_found) begin
                        current_len <= hist_lens[hist_search_idx - 4'd1];
                        for (i = 0; i < 32; i = i + 1) begin
                            if (i < hist_lens[hist_search_idx - 4'd1]) begin
                                current_buffer[i] <= hist_cmd[hist_search_idx - 4'd1][i];
                            end else begin
                                current_buffer[i] <= 8'd0;
                            end
                        end
                    end
                end
                ADD_TO_HISTORY: begin
                    cycles <= cycles + 6'd1;
                    if (current_len > 6'd0) begin
                        hist_lens[history_wr_ptr] <= current_len;
                        for (i = 0; i < 32; i = i + 1) begin
                            if (i < current_len) begin
                                hist_cmd[history_wr_ptr][i] <= current_buffer[i];
                            end else begin
                                hist_cmd[history_wr_ptr][i] <= 8'd0;
                            end
                        end
                        valid_history[history_wr_ptr] <= 1'b1;
                        history_wr_ptr <= (history_wr_ptr + 4'd1) % MAX_HISTORY;
                    end
                end
                FINISH: begin
                    done <= 1'b1;
                    out_len <= current_len;
                    for (i = 0; i < 32; i = i + 1) begin
                        if (i < current_len) begin
                            cmd_out[i] <= current_buffer[i];
                        end else begin
                            cmd_out[i] <= 8'd0;
                        end
                    end
                end
            endcase
        end
    end

    // Combinational next state logic
    always @(*) begin
        next_state = state;
        temp_char = 8'd0;
        prefix_len = 6'd0;
        match_found = 1'b0;
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = INIT_PROCESS;
                end
            end
            INIT_PROCESS: begin
                if (char_idx < cmd_len && cycles < MAX_CYCLES) begin
                    temp_char = cmd_in[char_idx];
                    next_state = SEARCH_HISTORY;
                    if (temp_char == 8'h5E) begin
                        prefix_len = current_len;
                        if (prefix_len > 6'd0) begin
                            next_state = SEARCH_HISTORY;
                        end else begin
                            next_state = UPDATE_BUFFER;
                        end
                    end else begin
                        next_state = PROCESS_CHAR;
                    end
                end else if (char_idx >= cmd_len) begin
                    next_state = ADD_TO_HISTORY;
                end else begin
                    next_state = FINISH;
                end
            end
            PROCESS_CHAR: begin
                if (char_idx < cmd_len && cycles < MAX_CYCLES) begin
                    temp_char = cmd_in[char_idx];
                    if (temp_char == 8'h5E) begin
                        prefix_len = current_len;
                        if (prefix_len > 6'd0) begin
                            next_state = SEARCH_HISTORY;
                        end else begin
                            next_state = UPDATE_BUFFER;
                        end
                    end else begin
                        next_state = PROCESS_CHAR;
                    end
                end else if (char_idx >= cmd_len) begin
                    next_state = ADD_TO_HISTORY;
                end else begin
                    next_state = FINISH;
                end
            end
            SEARCH_HISTORY: begin
                if (hist_search_idx >= MAX_HISTORY) begin
                    next_state = UPDATE_BUFFER;
                end
            end
            UPDATE_BUFFER: begin
                next_state = INIT_PROCESS;
            end
            ADD_TO_HISTORY: begin
                next_state = FINISH;
            end
            FINISH: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

endmodule