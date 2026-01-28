module dictionary_merge_3way (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] len1,
    input wire [3:0] len2,
    input wire [3:0] len3,
    input wire [7:0] key1 [0:7],
    input wire [7:0] val1 [0:7],
    input wire [7:0] key2 [0:7],
    input wire [7:0] val2 [0:7],
    input wire [7:0] key3 [0:7],
    input wire [7:0] val3 [0:7],
    output reg result_valid,
    output reg [7:0] out_key [0:15],
    output reg [7:0] out_val [0:15],
    output reg [3:0] out_len,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] READ_DICT3 = 3'd1;
    localparam [2:0] READ_DICT2 = 3'd2;
    localparam [2:0] READ_DICT1 = 3'd3;
    localparam [2:0] PROCESS_DICT3 = 3'd4;
    localparam [2:0] PROCESS_DICT2 = 3'd5;
    localparam [2:0] PROCESS_DICT1 = 3'd6;
    localparam [2:0] DONE_STATE = 3'd7;

    reg [2:0] state;
    reg [2:0] next_state;
    
    // Internal counters and registers
    reg [3:0] idx;              // Index for current input dictionary
    reg [3:0] output_idx;       // Index for output dictionary
    reg [3:0] current_len;      // Current dictionary length being processed
    reg [7:0] current_key;      // Current key to process
    reg [7:0] current_val;      // Current value to process
    reg [7:0] temp_key;
    reg [7:0] temp_val;
    reg [3:0] loop_idx;         // For searching output array
    reg found;                  // Flag for key found in output
    reg [7:0] cycle_count;      // Prevent infinite loops
    localparam [7:0] MAX_CYCLES = 8'd100;
    
    // Input dictionary selection
    reg [7:0] selected_key;
    reg [7:0] selected_val;
    
    // Combinational logic for input selection
    always @(*) begin
        if (state == READ_DICT3) begin
            selected_key = key3[idx];
            selected_val = val3[idx];
        end else if (state == READ_DICT2) begin
            selected_key = key2[idx];
            selected_val = val2[idx];
        end else begin // READ_DICT1
            selected_key = key1[idx];
            selected_val = val1[idx];
        end
    end

    // Sequential logic for output array operations
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Initialize output arrays
            out_len <= 4'd0;
            result_valid <= 1'b0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            for (loop_idx = 0; loop_idx < 16; loop_idx = loop_idx + 1) begin
                out_key[loop_idx] <= 8'd0;
                out_val[loop_idx] <= 8'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    result_valid <= 1'b0;
                    cycle_count <= 8'd0;
                    out_len <= 4'd0;
                    // Initialize output arrays in IDLE as well
                    for (loop_idx = 0; loop_idx < 16; loop_idx = loop_idx + 1) begin
                        out_key[loop_idx] <= 8'd0;
                        out_val[loop_idx] <= 8'd0;
                    end
                end
                
                PROCESS_DICT3: begin
                    cycle_count <= cycle_count + 8'd1;
                    // Check if key is already in output
                    found <= 1'b0;
                    for (loop_idx = 0; loop_idx < out_len; loop_idx = loop_idx + 1) begin
                        if (out_key[loop_idx] == current_key) begin
                            found <= 1'b1;
                        end
                    end
                    
                    // After search, check if we should add
                    if (!found && out_len < 16'd16) begin
                        out_key[out_len] <= current_key;
                        out_val[out_len] <= current_val;
                        out_len <= out_len + 4'd1;
                    end else if (found) begin
                        // Overwrite existing entry
                        for (loop_idx = 0; loop_idx < out_len; loop_idx = loop_idx + 1) begin
                            if (out_key[loop_idx] == current_key) begin
                                out_val[loop_idx] <= current_val;
                            end
                        end
                    end
                end
                
                PROCESS_DICT2: begin
                    cycle_count <= cycle_count + 8'd1;
                    found <= 1'b0;
                    for (loop_idx = 0; loop_idx < out_len; loop_idx = loop_idx + 1) begin
                        if (out_key[loop_idx] == current_key) begin
                            found <= 1'b1;
                        end
                    end
                    
                    if (!found && out_len < 16'd16) begin
                        out_key[out_len] <= current_key;
                        out_val[out_len] <= current_val;
                        out_len <= out_len + 4'd1;
                    end else if (found) begin
                        for (loop_idx = 0; loop_idx < out_len; loop_idx = loop_idx + 1) begin
                            if (out_key[loop_idx] == current_key) begin
                                out_val[loop_idx] <= current_val;
                            end
                        end
                    end
                end
                
                PROCESS_DICT1: begin
                    cycle_count <= cycle_count + 8'd1;
                    found <= 1'b0;
                    for (loop_idx = 0; loop_idx < out_len; loop_idx = loop_idx + 1) begin
                        if (out_key[loop_idx] == current_key) begin
                            found <= 1'b1;
                        end
                    end
                    
                    // Only add if not found (do not overwrite dict1)
                    if (!found && out_len < 16'd16) begin
                        out_key[out_len] <= current_key;
                        out_val[out_len] <= current_val;
                        out_len <= out_len + 4'd1;
                    end
                end
                
                DONE_STATE: begin
                    done <= 1'b1;
                    result_valid <= 1'b1;
                end
                
                default: begin
                    out_len <= 4'd0;
                    result_valid <= 1'b0;
                    done <= 1'b0;
                end
            endcase
        end
    end

    // Combinational next state logic
    always @(*) begin
        next_state = IDLE;
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = READ_DICT3;
                end else begin
                    next_state = IDLE;
                end
            end
            
            READ_DICT3: begin
                if (len3 == 4'd0) begin
                    next_state = READ_DICT2;
                end else begin
                    next_state = PROCESS_DICT3;
                end
            end
            
            PROCESS_DICT3: begin
                if (idx < len3 - 4'd1) begin
                    next_state = READ_DICT3;
                end else begin
                    next_state = READ_DICT2;
                end
            end
            
            READ_DICT2: begin
                if (len2 == 4'd0) begin
                    next_state = READ_DICT1;
                end else begin
                    next_state = PROCESS_DICT2;
                end
            end
            
            PROCESS_DICT2: begin
                if (idx < len2 - 4'd1) begin
                    next_state = READ_DICT2;
                end else begin
                    next_state = READ_DICT1;
                end
            end
            
            READ_DICT1: begin
                if (len1 == 4'd0) begin
                    next_state = DONE_STATE;
                end else begin
                    next_state = PROCESS_DICT1;
                end
            end
            
            PROCESS_DICT1: begin
                if (idx < len1 - 4'd1) begin
                    next_state = READ_DICT1;
                end else begin
                    next_state = DONE_STATE;
                end
            end
            
            DONE_STATE: begin
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end

    // Update state and handle idx increment
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            idx <= 4'd0;
        end else begin
            state <= next_state;
            
            // Update current_key and current_val when transitioning to process states
            if (next_state == PROCESS_DICT3) begin
                current_key <= key3[idx];
                current_val <= val3[idx];
            end else if (next_state == PROCESS_DICT2) begin
                current_key <= key2[idx];
                current_val <= val2[idx];
            end else if (next_state == PROCESS_DICT1) begin
                current_key <= key1[idx];
                current_val <= val1[idx];
            end
            
            // Manage idx counter
            if (state == IDLE) begin
                idx <= 4'd0;
            end else if (next_state == READ_DICT3) begin
                idx <= idx + 4'd1;
            end else if (next_state == READ_DICT2) begin
                idx <= idx + 4'd1;
            end else if (next_state == READ_DICT1) begin
                idx <= idx + 4'd1;
            end else if (next_state == DONE_STATE) begin
                idx <= 4'd0;
            end
        end
    end

endmodule