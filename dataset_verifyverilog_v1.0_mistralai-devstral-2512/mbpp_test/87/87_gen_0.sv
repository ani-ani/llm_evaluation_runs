module dict_merge(
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
    localparam [2:0] IDLE      = 3'd0;
    localparam [2:0] READ_DICT3 = 3'd1;
    localparam [2:0] READ_DICT2 = 3'd2;
    localparam [2:0] READ_DICT1 = 3'd3;
    localparam [2:0] DONE_STATE = 3'd4;

    reg [2:0] state, next_state;
    reg [7:0] current_key, current_val;
    reg [3:0] dict3_idx, dict2_idx, dict1_idx;
    reg [3:0] out_idx;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd100;

    // Merged dictionary storage (16 entries)
    reg [7:0] merged_key [0:15];
    reg [7:0] merged_val [0:15];
    reg [3:0] merged_count;

    // Key existence check
    reg key_exists;
    reg [3:0] i;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result_valid <= 1'b0;
            done <= 1'b0;
            out_len <= 4'd0;
            dict3_idx <= 4'd0;
            dict2_idx <= 4'd0;
            dict1_idx <= 4'd0;
            out_idx <= 4'd0;
            merged_count <= 4'd0;
            cycle_count <= 8'd0;
            
            // Initialize output arrays
            for (i = 0; i < 16; i = i + 1) begin
                out_key[i] <= 8'd0;
                out_val[i] <= 8'd0;
                merged_key[i] <= 8'd0;
                merged_val[i] <= 8'd0;
            end
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
                    next_state = READ_DICT3;
                    dict3_idx = 4'd0;
                    dict2_idx = 4'd0;
                    dict1_idx = 4'd0;
                    out_idx = 4'd0;
                    merged_count = 4'd0;
                    cycle_count = 8'd0;
                    result_valid = 1'b0;
                    done = 1'b0;
                end
            end
            
            READ_DICT3: begin
                if (dict3_idx < len3) begin
                    current_key = key3[dict3_idx];
                    current_val = val3[dict3_idx];
                    next_state = READ_DICT3;
                end else begin
                    next_state = READ_DICT2;
                end
            end
            
            READ_DICT2: begin
                if (dict2_idx < len2) begin
                    current_key = key2[dict2_idx];
                    current_val = val2[dict2_idx];
                    next_state = READ_DICT2;
                end else begin
                    next_state = READ_DICT1;
                end
            end
            
            READ_DICT1: begin
                if (dict1_idx < len1) begin
                    current_key = key1[dict1_idx];
                    current_val = val1[dict1_idx];
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

    // Key processing logic
    always @(posedge clk) begin
        if (rst_n) begin
            case (state)
                READ_DICT3: begin
                    // Process dict3 entry
                    key_exists = 1'b0;
                    for (i = 0; i < merged_count; i = i + 1) begin
                        if (merged_key[i] == current_key) begin
                            key_exists = 1'b1;
                            merged_val[i] = current_val;
                        end
                    end
                    
                    if (!key_exists && merged_count < 16) begin
                        merged_key[merged_count] = current_key;
                        merged_val[merged_count] = current_val;
                        merged_count = merged_count + 4'd1;
                    end
                    
                    dict3_idx = dict3_idx + 4'd1;
                    cycle_count = cycle_count + 8'd1;
                end
                
                READ_DICT2: begin
                    // Process dict2 entry
                    key_exists = 1'b0;
                    for (i = 0; i < merged_count; i = i + 1) begin
                        if (merged_key[i] == current_key) begin
                            key_exists = 1'b1;
                            merged_val[i] = current_val;
                        end
                    end
                    
                    if (!key_exists && merged_count < 16) begin
                        merged_key[merged_count] = current_key;
                        merged_val[merged_count] = current_val;
                        merged_count = merged_count + 4'd1;
                    end
                    
                    dict2_idx = dict2_idx + 4'd1;
                    cycle_count = cycle_count + 8'd1;
                end
                
                READ_DICT1: begin
                    // Process dict1 entry
                    key_exists = 1'b0;
                    for (i = 0; i < merged_count; i = i + 1) begin
                        if (merged_key[i] == current_key) begin
                            key_exists = 1'b1;
                        end
                    end
                    
                    if (!key_exists && merged_count < 16) begin
                        merged_key[merged_count] = current_key;
                        merged_val[merged_count] = current_val;
                        merged_count = merged_count + 4'd1;
                    end
                    
                    dict1_idx = dict1_idx + 4'd1;
                    cycle_count = cycle_count + 8'd1;
                end
                
                DONE_STATE: begin
                    // Copy merged dictionary to output
                    for (i = 0; i < 16; i = i + 1) begin
                        out_key[i] = merged_key[i];
                        out_val[i] = merged_val[i];
                    end
                    out_len = merged_count;
                    result_valid = 1'b1;
                    done = 1'b1;
                end
            endcase
        end
    end

    // Safety: prevent infinite loops
    always @(posedge clk) begin
        if (cycle_count >= MAX_CYCLES && state != IDLE && state != DONE_STATE) begin
            next_state = DONE_STATE;
        end
    end

endmodule