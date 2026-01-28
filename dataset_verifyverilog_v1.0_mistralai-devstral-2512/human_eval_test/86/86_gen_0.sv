module anti_shuffle_sorter(
    input clk,
    input rst_n,
    input start,
    input [127:0] in_str,
    output reg [127:0] out_str,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] PARSE = 3'd1;
    localparam [2:0] SORT = 3'd2;
    localparam [2:0] REASSEMBLE = 3'd3;
    localparam [2:0] DONE_STATE = 3'd4;

    // Registers
    reg [2:0] state, next_state;
    reg [7:0] char_buffer [0:15];
    reg [7:0] sorted_buffer [0:15];
    reg [3:0] word_start [0:7];
    reg [3:0] word_end [0:7];
    reg [3:0] word_count;
    reg [3:0] current_word;
    reg [3:0] sort_stage;
    reg [3:0] char_index;
    reg [3:0] cycle_count;
    reg [3:0] max_cycles;

    // Initialize all registers
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            out_str <= 128'd0;
            cycle_count <= 4'd0;
            max_cycles <= 4'd255;
            
            // Initialize buffers
            integer i;
            for (i = 0; i < 16; i = i + 1) begin
                char_buffer[i] <= 8'd0;
                sorted_buffer[i] <= 8'd0;
            end
            
            // Initialize word boundaries
            for (i = 0; i < 8; i = i + 1) begin
                word_start[i] <= 4'd0;
                word_end[i] <= 4'd0;
            end
            
            word_count <= 4'd0;
            current_word <= 4'd0;
            sort_stage <= 4'd0;
            char_index <= 4'd0;
        end else begin
            state <= next_state;
        end
    end

    // State machine logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = PARSE;
                end
            end
            
            PARSE: begin
                next_state = SORT;
            end
            
            SORT: begin
                if (sort_stage == 4'd15 && current_word == word_count) begin
                    next_state = REASSEMBLE;
                end
            end
            
            REASSEMBLE: begin
                if (char_index == 4'd15) begin
                    next_state = DONE_STATE;
                end
            end
            
            DONE_STATE: begin
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end

    // Parse input string to identify word boundaries
    always @(posedge clk) begin
        if (state == PARSE) begin
            integer i;
            reg [3:0] word_idx;
            reg [3:0] word_start_idx;
            reg [3:0] word_end_idx;
            reg [3:0] char_pos;
            
            word_idx = 4'd0;
            word_start_idx = 4'd0;
            word_end_idx = 4'd0;
            char_pos = 4'd0;
            
            // Extract characters from input string
            for (i = 0; i < 16; i = i + 1) begin
                char_buffer[i] <= in_str[(i+1)*8-1:i*8];
            end
            
            // Identify word boundaries
            for (i = 0; i < 16; i = i + 1) begin
                if (char_buffer[i] > 8'd32) begin
                    if (word_start_idx == 4'd0) begin
                        word_start_idx = char_pos;
                    end
                    word_end_idx = char_pos;
                end else begin
                    if (word_start_idx != 4'd0) begin
                        word_start[word_idx] <= word_start_idx;
                        word_end[word_idx] <= word_end_idx;
                        word_idx = word_idx + 4'd1;
                        word_start_idx = 4'd0;
                        word_end_idx = 4'd0;
                    end
                end
                char_pos = char_pos + 4'd1;
            end
            
            // Store last word if any
            if (word_start_idx != 4'd0) begin
                word_start[word_idx] <= word_start_idx;
                word_end[word_idx] <= word_end_idx;
                word_idx = word_idx + 4'd1;
            end
            
            word_count <= word_idx;
            current_word <= 4'd0;
            sort_stage <= 4'd0;
            char_index <= 4'd0;
        end
    end

    // Bubble sort implementation
    always @(posedge clk) begin
        if (state == SORT) begin
            integer i;
            reg [7:0] temp;
            reg [3:0] word_len;
            
            word_len = word_end[current_word] - word_start[current_word] + 4'd1;
            
            // Copy current word to sorted buffer
            if (sort_stage == 4'd0) begin
                for (i = 0; i < 16; i = i + 1) begin
                    if (i >= word_start[current_word] && i <= word_end[current_word]) begin
                        sorted_buffer[i] <= char_buffer[i];
                    end
                end
            end
            
            // Perform bubble sort stage
            if (sort_stage < 4'd15) begin
                for (i = word_start[current_word]; i < word_end[current_word]; i = i + 1) begin
                    if (sorted_buffer[i] > sorted_buffer[i+1]) begin
                        temp = sorted_buffer[i];
                        sorted_buffer[i] <= sorted_buffer[i+1];
                        sorted_buffer[i+1] <= temp;
                    end
                end
                sort_stage <= sort_stage + 4'd1;
            end else begin
                // Move to next word
                current_word <= current_word + 4'd1;
                sort_stage <= 4'd0;
            end
        end
    end

    // Reassemble output string
    always @(posedge clk) begin
        if (state == REASSEMBLE) begin
            integer i;
            
            // Copy sorted characters back to output
            for (i = 0; i < 16; i = i + 1) begin
                if (char_buffer[i] > 8'd32) begin
                    out_str[(i+1)*8-1:i*8] <= sorted_buffer[i];
                end else begin
                    out_str[(i+1)*8-1:i*8] <= char_buffer[i];
                end
            end
            
            char_index <= char_index + 4'd1;
        end
    end

    // Done signal
    always @(posedge clk) begin
        if (state == DONE_STATE) begin
            done <= 1'b1;
        end else begin
            done <= 1'b0;
        end
    end

    // Cycle counter to prevent infinite loops
    always @(posedge clk) begin
        if (state != IDLE) begin
            cycle_count <= cycle_count + 4'd1;
            if (cycle_count >= max_cycles) begin
                state <= IDLE;
                done <= 1'b0;
                cycle_count <= 4'd0;
            end
        end
    end

endmodule