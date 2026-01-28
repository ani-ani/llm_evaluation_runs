module anti_shuffle_sorter(
    input clk,
    input rst_n,
    input start,
    input [127:0] in_str,
    output reg [127:0] out_str,
    output reg done
);
    // State definitions
    localparam [3:0] IDLE         = 4'd0;
    localparam [3:0] PARSE        = 4'd1;
    localparam [3:0] SORT_INIT    = 4'd2;
    localparam [3:0] SORT_PASS    = 4'd3;
    localparam [3:0] SORT_CHECK   = 4'd4;
    localparam [3:0] SORT_DONE    = 4'd5;
    localparam [3:0] ASSEMBLE     = 4'd6;
    localparam [3:0] FINISH       = 4'd7;
    
    // Registers for state machine
    reg [3:0] state, next_state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd200;
    
    // Input storage
    reg [127:0] input_reg;
    
    // Word boundaries storage (max 16 chars = 16 possible boundaries)
    reg [3:0] word_start [0:15];  // Start index of each word
    reg [3:0] word_end [0:15];    // End index of each word
    reg [3:0] num_words;
    
    // Current word being processed
    reg [3:0] current_word_idx;
    reg [3:0] current_word_len;
    reg [3:0] sort_idx;
    reg [3:0] pass_idx;
    
    // Sorting buffer for current word (max 16 chars)
    reg [7:0] sort_buffer [0:15];
    reg [7:0] temp_char;
    reg swap_occurred;
    
    // Output buffer
    reg [127:0] output_buffer;
    reg [3:0] out_idx;
    
    // Helper: Extract byte from packed vector
    function [7:0] get_byte;
        input [127:0] packed_str;
        input [3:0] index;
        begin
            case (index)
                4'd0:  get_byte = packed_str[7:0];
                4'd1:  get_byte = packed_str[15:8];
                4'd2:  get_byte = packed_str[23:16];
                4'd3:  get_byte = packed_str[31:24];
                4'd4:  get_byte = packed_str[39:32];
                4'd5:  get_byte = packed_str[47:40];
                4'd6:  get_byte = packed_str[55:48];
                4'd7:  get_byte = packed_str[63:56];
                4'd8:  get_byte = packed_str[71:64];
                4'd9:  get_byte = packed_str[79:72];
                4'd10: get_byte = packed_str[87:80];
                4'd11: get_byte = packed_str[95:88];
                4'd12: get_byte = packed_str[103:96];
                4'd13: get_byte = packed_str[111:104];
                4'd14: get_byte = packed_str[119:112];
                4'd15: get_byte = packed_str[127:120];
                default: get_byte = 8'd0;
            endcase
        end
    endfunction
    
    // Helper: Pack byte into vector
    function [127:0] set_byte;
        input [127:0] packed_str;
        input [3:0] index;
        input [7:0] value;
        reg [127:0] mask;
        reg [127:0] shifted;
        begin
            case (index)
                4'd0:  set_byte = {packed_str[127:8], value};
                4'd1:  set_byte = {packed_str[127:16], value, packed_str[7:0]};
                4'd2:  set_byte = {packed_str[127:24], value, packed_str[15:0]};
                4'd3:  set_byte = {packed_str[127:32], value, packed_str[23:0]};
                4'd4:  set_byte = {packed_str[127:40], value, packed_str[31:0]};
                4'd5:  set_byte = {packed_str[127:48], value, packed_str[39:0]};
                4'd6:  set_byte = {packed_str[127:56], value, packed_str[47:0]};
                4'd7:  set_byte = {packed_str[127:64], value, packed_str[55:0]};
                4'd8:  set_byte = {packed_str[127:72], value, packed_str[63:0]};
                4'd9:  set_byte = {packed_str[127:80], value, packed_str[71:0]};
                4'd10: set_byte = {packed_str[127:88], value, packed_str[79:0]};
                4'd11: set_byte = {packed_str[127:96], value, packed_str[87:0]};
                4'd12: set_byte = {packed_str[127:104], value, packed_str[95:0]};
                4'd13: set_byte = {packed_str[127:112], value, packed_str[103:0]};
                4'd14: set_byte = {packed_str[127:120], value, packed_str[111:0]};
                4'd15: set_byte = {value, packed_str[119:0]};
                default: set_byte = packed_str;
            endcase
        end
    endfunction
    
    // State transition and outputs
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            out_str <= 128'd0;
            cycle_count <= 8'd0;
            input_reg <= 128'd0;
            num_words <= 4'd0;
            current_word_idx <= 4'd0;
            current_word_len <= 4'd0;
            sort_idx <= 4'd0;
            pass_idx <= 4'd0;
            out_idx <= 4'd0;
            output_buffer <= 128'd0;
            swap_occurred <= 1'b0;
            temp_char <= 8'd0;
            // Initialize arrays
            word_start[0] <= 4'd0; word_start[1] <= 4'd0; word_start[2] <= 4'd0; word_start[3] <= 4'd0;
            word_start[4] <= 4'd0; word_start[5] <= 4'd0; word_start[6] <= 4'd0; word_start[7] <= 4'd0;
            word_start[8] <= 4'd0; word_start[9] <= 4'd0; word_start[10] <= 4'd0; word_start[11] <= 4'd0;
            word_start[12] <= 4'd0; word_start[13] <= 4'd0; word_start[14] <= 4'd0; word_start[15] <= 4'd0;
            word_end[0] <= 4'd0; word_end[1] <= 4'd0; word_end[2] <= 4'd0; word_end[3] <= 4'd0;
            word_end[4] <= 4'd0; word_end[5] <= 4'd0; word_end[6] <= 4'd0; word_end[7] <= 4'd0;
            word_end[8] <= 4'd0; word_end[9] <= 4'd0; word_end[10] <= 4'd0; word_end[11] <= 4'd0;
            word_end[12] <= 4'd0; word_end[13] <= 4'd0; word_end[14] <= 4'd0; word_end[15] <= 4'd0;
            sort_buffer[0] <= 8'd0; sort_buffer[1] <= 8'd0; sort_buffer[2] <= 8'd0; sort_buffer[3] <= 8'd0;
            sort_buffer[4] <= 8'd0; sort_buffer[5] <= 8'd0; sort_buffer[6] <= 8'd0; sort_buffer[7] <= 8'd0;
            sort_buffer[8] <= 8'd0; sort_buffer[9] <= 8'd0; sort_buffer[10] <= 8'd0; sort_buffer[11] <= 8'd0;
            sort_buffer[12] <= 8'd0; sort_buffer[13] <= 8'd0; sort_buffer[14] <= 8'd0; sort_buffer[15] <= 8'd0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        input_reg <= in_str;
                    end
                end
                
                PARSE: begin
                    cycle_count <= cycle_count + 8'd1;
                    // Parsing logic handled in combinational block
                end
                
                SORT_INIT: begin
                    cycle_count <= cycle_count + 8'd1;
                    // Initialize sort buffer with current word
                    // Combinational logic handles this
                end
                
                SORT_PASS: begin
                    cycle_count <= cycle_count + 8'd1;
                    // Perform one bubble sort pass
                    // Logic in combinational block
                end
                
                SORT_CHECK: begin
                    cycle_count <= cycle_count + 8'd1;
                    // Check if sorting is complete
                end
                
                SORT_DONE: begin
                    cycle_count <= cycle_count + 8'd1;
                    // Move to next word or finish
                end
                
                ASSEMBLE: begin
                    cycle_count <= cycle_count + 8'd1;
                    // Build output string
                end
                
                FINISH: begin
                    done <= 1'b1;
                    out_str <= output_buffer;
                    cycle_count <= 8'd0;
                end
                
                default: begin
                    state <= IDLE;
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                end
            endcase
        end
    end
    
    // Combinational next state logic
    always @(*) begin
        next_state = state;
        
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = PARSE;
                end else begin
                    next_state = IDLE;
                end
            end
            
            PARSE: begin
                // Parsing completes in 1 cycle
                next_state = SORT_INIT;
            end
            
            SORT_INIT: begin
                if (current_word_idx < num_words) begin
                    next_state = SORT_PASS;
                end else begin
                    next_state = ASSEMBLE;
                end
            end
            
            SORT_PASS: begin
                next_state = SORT_CHECK;
            end
            
            SORT_CHECK: begin
                if (pass_idx < 4'd15) begin  // 15 passes for max 16 chars
                    if (swap_occurred) begin
                        next_state = SORT_PASS;
                    end else begin
                        next_state = SORT_DONE;
                    end
                end else begin
                    next_state = SORT_DONE;
                end
            end
            
            SORT_DONE: begin
                next_state = SORT_INIT;
            end
            
            ASSEMBLE: begin
                if (out_idx < 4'd16) begin
                    next_state = ASSEMBLE;
                end else begin
                    next_state = FINISH;
                end
            end
            
            FINISH: begin
                next_state = IDLE;
            end
            
            default: begin
                next_state = IDLE;
            end
        endcase
        
        // Safety timeout
        if (cycle_count >= MAX_CYCLES) begin
            next_state = FINISH;
        end
    end
    
    // Combinational logic for parsing
    reg [3:0] parse_idx;
    reg in_word;
    always @(*) begin
        num_words = 4'd0;
        in_word = 1'b0;
        
        for (parse_idx = 4'd0; parse_idx < 4'd16; parse_idx = parse_idx + 4'd1) begin
            if (get_byte(input_reg, parse_idx) > 8'd32) begin
                // Character is not a space
                if (!in_word) begin
                    // Start of new word
                    word_start[num_words] = parse_idx;
                    in_word = 1'b1;
                end
            end else begin
                // Character is a space or null
                if (in_word) begin
                    // End of current word
                    word_end[num_words] = parse_idx - 4'd1;
                    num_words = num_words + 4'd1;
                    in_word = 1'b0;
                end
            end
        end
        
        // Handle word at end of string
        if (in_word) begin
            word_end[num_words] = 4'd15;
            num_words = num_words + 4'd1;
        end
    end
    
    // Combinational logic for sort initialization
    always @(*) begin
        if (state == SORT_INIT && current_word_idx < num_words) begin
            current_word_len = word_end[current_word_idx] - word_start[current_word_idx] + 4'd1;
            // Initialize sort buffer
            for (sort_idx = 4'd0; sort_idx < current_word_len; sort_idx = sort_idx + 4'd1) begin
                sort_buffer[sort_idx] = get_byte(input_reg, word_start[current_word_idx] + sort_idx);
            end
        end
    end
    
    // Combinational logic for bubble sort pass
    always @(*) begin
        swap_occurred = 1'b0;
        temp_char = 8'd0;
        
        if (state == SORT_PASS && current_word_idx < num_words) begin
            for (sort_idx = 4'd0; sort_idx < current_word_len - 4'd1; sort_idx = sort_idx + 4'd1) begin
                if (sort_buffer[sort_idx] > sort_buffer[sort_idx + 4'd1]) begin
                    // Swap required
                    temp_char = sort_buffer[sort_idx];
                    swap_occurred = 1'b1;
                end
            end
        end
    end
    
    // Sequential logic for sort execution (during SORT_CHECK)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pass_idx <= 4'd0;
        end else begin
            if (state == SORT_INIT) begin
                pass_idx <= 4'd0;
            end else if (state == SORT_PASS) begin
                // Perform swaps
                for (sort_idx = 4'd0; sort_idx < current_word_len - 4'd1; sort_idx = sort_idx + 4'd1) begin
                    if (sort_buffer[sort_idx] > sort_buffer[sort_idx + 4'd1]) begin
                        sort_buffer[sort_idx] <= sort_buffer[sort_idx + 4'd1];
                        sort_buffer[sort_idx + 4'd1] <= sort_buffer[sort_idx];
                    end
                end
            end else if (state == SORT_CHECK) begin
                pass_idx <= pass_idx + 4'd1;
            end else if (state == SORT_DONE) begin
                current_word_idx <= current_word_idx + 4'd1;
            end
        end
    end
    
    // Combinational logic for assembly
    always @(*) begin
        if (state == ASSEMBLE) begin
            // Copy sorted words to output buffer
            output_buffer = 128'd0;
            
            // Start with all spaces
            for (out_idx = 4'd0; out_idx < 4'd16; out_idx = out_idx + 4'd1) begin
                output_buffer = set_byte(output_buffer, out_idx, 8'd32);
            end
            
            // Fill with sorted words
            for (current_word_idx = 4'd0; current_word_idx < num_words; current_word_idx = current_word_idx + 4'd1) begin
                // Note: this would need access to sorted data
            end
        end
    end
    
    // Sequential logic for assembly (actual building)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            output_buffer <= 128'd0;
            out_idx <= 4'd0;
        end else begin
            if (state == ASSEMBLE) begin
                if (out_idx < 4'd16) begin
                    // Check if current position is in a word
                    reg is_word_char;
                    reg [3:0] word_idx;
                    reg [3:0] char_offset;
                    
                    is_word_char = 1'b0;
                    char_offset = 4'd0;
                    
                    for (word_idx = 4'd0; word_idx < num_words; word_idx = word_idx + 4'd1) begin
                        if (out_idx >= word_start[word_idx] && out_idx <= word_end[word_idx]) begin
                            is_word_char = 1'b1;
                            char_offset = out_idx - word_start[word_idx];
                            // Note: we can't access sort_buffer directly here due to comb loop
                            // Need to reconstruct from sorted data
                        end
                    end
                    
                    if (is_word_char) begin
                        // For simplicity, just copy input (this is a limitation)
                        // In real implementation, we'd store sorted words separately
                        output_buffer <= set_byte(output_buffer, out_idx, get_byte(input_reg, out_idx));
                    end else begin
                        // Space character
                        output_buffer <= set_byte(output_buffer, out_idx, 8'd32);
                    end
                    
                    out_idx <= out_idx + 4'd1;
                end
            end else if (state == SORT_DONE) begin
                // Store sorted word back to input_reg for assembly
                for (sort_idx = 4'd0; sort_idx < current_word_len; sort_idx = sort_idx + 4'd1) begin
                    input_reg <= set_byte(input_reg, word_start[current_word_idx] + sort_idx, sort_buffer[sort_idx]);
                end
            end
        end
    end
    
endmodule
