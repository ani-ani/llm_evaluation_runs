module shell_history (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] char_in,
    input wire char_valid,
    input wire char_done,
    output reg result_valid,
    output reg [7:0] result_char,
    output reg result_done,
    output reg busy
);

    // Parameters
    localparam [7:0] UP_CHAR = 8'd94; // '^'
    localparam [5:0] MAX_CMD_LEN = 6'd64; // 64 chars max
    localparam [4:0] MAX_HISTORY = 5'd16; // 16 commands max (smaller for area)
    
    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] COLLECT = 3'd1;
    localparam [2:0] SEARCH_HISTORY = 3'd2;
    localparam [2:0] OUTPUT_CHAR = 3'd3;
    localparam [2:0] ADD_TO_HISTORY = 3'd4;
    
    // Registers and memories
    reg [2:0] state, next_state;
    reg [2:0] state_next;
    
    // Current line buffer (unpacked array for Icarus compatibility)
    reg [7:0] current_line [0:63];
    reg [6:0] cmd_idx; // Index into current_line
    
    // History storage: array of 16 commands, each 64 chars
    reg [7:0] history [0:15][0:63];
    reg [4:0] history_count; // Number of commands in history
    reg [4:0] history_write_idx; // Next write position (FIFO style)
    reg [4:0] history_read_idx; // For searching
    
    // Search state
    reg [4:0] search_count; // Consecutive up-arrows
    reg [4:0] search_idx; // Current history index to check
    reg [6:0] search_char_idx; // Character index in comparison
    reg [6:0] match_length; // Length of current match
    reg [4:0] match_cmd_idx; // Matching command index
    reg match_found;
    
    // Output state
    reg [6:0] output_idx;
    reg [4:0] output_cmd_idx;
    reg [2:0] out_state, out_state_next;
    localparam [2:0] OUT_IDLE = 3'd0;
    localparam [2:0] OUT_CHAR = 3'd1;
    localparam [2:0] OUT_DONE = 3'd2;
    
    // Cycle counter for timeout prevention
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd200;
    
    // Index variables for loops
    integer i, j;

    // State transition logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start)
                    next_state = COLLECT;
                else
                    next_state = IDLE;
            end
            
            COLLECT: begin
                if (char_done) begin
                    if (cmd_idx > 7'd0) // Only process if command not empty
                        next_state = SEARCH_HISTORY;
                    else
                        next_state = IDLE;
                end else if (char_valid && char_in == UP_CHAR) begin
                    next_state = SEARCH_HISTORY;
                end else begin
                    next_state = COLLECT;
                end
            end
            
            SEARCH_HISTORY: begin
                // Wait for search to complete
                if (search_count >= MAX_HISTORY || 
                    (match_found && search_char_idx == match_length)) begin
                    next_state = OUTPUT_CHAR;
                end else begin
                    next_state = SEARCH_HISTORY;
                end
            end
            
            OUTPUT_CHAR: begin
                if (out_state == OUT_DONE) begin
                    next_state = ADD_TO_HISTORY;
                end else begin
                    next_state = OUTPUT_CHAR;
                end
            end
            
            ADD_TO_HISTORY: begin
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end

    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            out_state <= OUT_IDLE;
            cmd_idx <= 7'd0;
            history_count <= 5'd0;
            history_write_idx <= 5'd0;
            search_count <= 5'd0;
            search_idx <= 5'd0;
            search_char_idx <= 7'd0;
            match_length <= 7'd0;
            match_cmd_idx <= 5'd0;
            match_found <= 1'b0;
            output_idx <= 7'd0;
            output_cmd_idx <= 5'd0;
            cycle_count <= 8'd0;
            result_valid <= 1'b0;
            result_done <= 1'b0;
            busy <= 1'b0;
            result_char <= 8'd0;
            
            // Initialize current_line
            for (i = 0; i < 64; i = i + 1) begin
                current_line[i] <= 8'd0;
            end
            
            // Initialize history (not strictly needed but good practice)
            for (i = 0; i < 16; i = i + 1) begin
                for (j = 0; j < 64; j = j + 1) begin
                    history[i][j] <= 8'd0;
                end
            end
            
        end else begin
            state <= next_state;
            
            // Default outputs
            result_valid <= 1'b0;
            result_done <= 1'b0;
            
            case (state)
                IDLE: begin
                    busy <= 1'b0;
                    if (start) begin
                        cmd_idx <= 7'd0;
                        search_count <= 5'd0;
                        busy <= 1'b1;
                    end
                end
                
                COLLECT: begin
                    if (char_valid) begin
                        if (char_in == UP_CHAR) begin
                            // Up arrow pressed
                            search_count <= search_count + 5'd1;
                            search_idx <= history_write_idx - search_count - 5'd1;
                            // If history is empty or we've searched too far, reset
                            if (history_count == 5'd0 || search_count >= history_count) begin
                                search_count <= 5'd0;
                                match_found <= 1'b0;
                            end else begin
                                // Start search
                                search_char_idx <= 7'd0;
                                match_length <= cmd_idx;
                                match_found <= 1'b0;
                            end
                        end else if (cmd_idx < MAX_CMD_LEN) begin
                            // Normal character
                            current_line[cmd_idx] <= char_in;
                            cmd_idx <= cmd_idx + 7'd1;
                            search_count <= 5'd0; // Reset consecutive counter
                        end
                    end
                end
                
                SEARCH_HISTORY: begin
                    // Perform prefix search
                    if (history_count > 5'd0 && search_count <= history_count) begin
                        // Check if we're at a valid history index
                        if (search_char_idx < match_length) begin
                            // Compare characters
                            if (history[search_idx][search_char_idx] == 
                                current_line[search_char_idx]) begin
                                search_char_idx <= search_char_idx + 7'd1;
                            end else begin
                                // No match, try next command
                                search_count <= search_count + 5'd1;
                                search_idx <= history_write_idx - search_count - 5'd2;
                                search_char_idx <= 7'd0;
                            end
                        end else begin
                            // Match found (all characters matched)
                            match_found <= 1'b1;
                            match_cmd_idx <= search_idx;
                        end
                    end else begin
                        // No match found
                        match_found <= 1'b0;
                    end
                end
                
                OUTPUT_CHAR: begin
                    // Output state machine
                    case (out_state)
                        OUT_IDLE: begin
                            output_idx <= 7'd0;
                            if (match_found) begin
                                output_cmd_idx <= match_cmd_idx;
                            end else begin
                                output_cmd_idx <= history_write_idx; // Use current buffer
                            end
                            out_state <= OUT_CHAR;
                        end
                        
                        OUT_CHAR: begin
                            if (output_idx < cmd_idx) begin
                                // Output character
                                if (match_found) begin
                                    result_char <= history[output_cmd_idx][output_idx];
                                end else begin
                                    result_char <= current_line[output_idx];
                                end
                                result_valid <= 1'b1;
                                output_idx <= output_idx + 7'd1;
                            end else begin
                                // Done outputting
                                out_state <= OUT_DONE;
                                result_done <= 1'b1;
                            end
                        end
                        
                        OUT_DONE: begin
                            out_state <= OUT_IDLE;
                        end
                        
                        default: out_state <= OUT_IDLE;
                    endcase
                end
                
                ADD_TO_HISTORY: begin
                    // Add current command to history
                    if (cmd_idx > 7'd0) begin
                        // Store the command
                        for (i = 0; i < 64; i = i + 1) begin
                            if (i < cmd_idx) begin
                                history[history_write_idx][i] <= current_line[i];
                            end else begin
                                history[history_write_idx][i] <= 8'd0;
                            end
                        end
                        
                        // Update write index (FIFO)
                        if (history_count < MAX_HISTORY) begin
                            history_write_idx <= history_write_idx + 5'd1;
                            history_count <= history_count + 5'd1;
                        end else begin
                            // Circular buffer - overwrite oldest
                            history_write_idx <= (history_write_idx + 5'd1) % MAX_HISTORY;
                        end
                    end
                    
                    // Reset for next command
                    cmd_idx <= 7'd0;
                    search_count <= 5'd0;
                    busy <= 1'b0;
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule