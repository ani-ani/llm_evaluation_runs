module PrefixFilter (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] strings [0:7],
    input wire [7:0] prefix [0:7],
    input wire [7:0] valid_strings,
    output reg [7:0] result_str [0:7],
    output reg [7:0] result_valid,
    output reg [3:0] result_count,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] LOAD_PREFIX = 3'd1;
    localparam [2:0] COMPARE = 3'd2;
    localparam [2:0] COPY = 3'd3;
    localparam [2:0] DONE = 3'd4;

    // Internal registers
    reg [2:0] state;
    reg [2:0] next_state;
    reg [2:0] string_idx;
    reg [2:0] char_idx;
    reg [2:0] prefix_len;
    reg [2:0] temp_prefix_len;
    reg match_found;
    reg [7:0] temp_result_str [0:7];
    reg [7:0] temp_result_valid;
    reg [3:0] temp_result_count;
    reg [2:0] copy_idx;
    
    // Cycle counter to prevent infinite loops
    reg [4:0] cycle_count;
    localparam [4:0] MAX_CYCLES = 5'd16;

    // Helper for prefix length detection
    integer i;
    always @(*) begin
        // Find prefix length (first null terminator or max 8)
        temp_prefix_len = 3'd0;
        for (i = 0; i < 8; i = i + 1) begin
            if (prefix[i] == 8'd0 && temp_prefix_len == 3'd0) begin
                temp_prefix_len = i;
            end
        end
        if (temp_prefix_len == 3'd0) temp_prefix_len = 3'd8;
    end

    // State transition logic
    always @(*) begin
        case (state)
            IDLE: next_state = (start) ? LOAD_PREFIX : IDLE;
            LOAD_PREFIX: next_state = COMPARE;
            COMPARE: begin
                if (string_idx >= 8) next_state = DONE;
                else if (!valid_strings[string_idx]) begin
                    // Skip invalid strings
                    if (string_idx == 8'd7) next_state = DONE;
                    else next_state = COMPARE;
                end
                else if (match_found || char_idx >= prefix_len) next_state = COPY;
                else next_state = COMPARE;
            end
            COPY: begin
                if (copy_idx >= 8'd7) begin
                    if (string_idx >= 8'd7) next_state = DONE;
                    else next_state = COMPARE;
                end
                else next_state = COPY;
            end
            DONE: next_state = IDLE;
            default: next_state = IDLE;
        endcase
    end

    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all registers
            state <= IDLE;
            string_idx <= 3'd0;
            char_idx <= 3'd0;
            prefix_len <= 3'd0;
            match_found <= 1'b0;
            copy_idx <= 3'd0;
            cycle_count <= 5'd0;
            temp_result_count <= 4'd0;
            temp_result_valid <= 8'd0;
            result_count <= 4'd0;
            result_valid <= 8'd0;
            done <= 1'b0;
            for (i = 0; i < 8; i = i + 1) begin
                temp_result_str[i] <= 8'd0;
                result_str[i] <= 8'd0;
            end
        end else begin
            state <= next_state;
            done <= 1'b0;
            
            case (state)
                IDLE: begin
                    cycle_count <= 5'd0;
                    string_idx <= 3'd0;
                    char_idx <= 3'd0;
                    temp_result_count <= 4'd0;
                    temp_result_valid <= 8'd0;
                    match_found <= 1'b0;
                end
                
                LOAD_PREFIX: begin
                    prefix_len <= temp_prefix_len;
                end
                
                COMPARE: begin
                    cycle_count <= cycle_count + 5'd1;
                    
                    if (string_idx < 8 && valid_strings[string_idx]) begin
                        // Check if we've matched all prefix characters
                        if (char_idx < prefix_len) begin
                            // Compare current character with prefix
                            if (strings[string_idx][char_idx*8 +: 8] == prefix[char_idx]) begin
                                if (char_idx == prefix_len - 3'd1) begin
                                    // Full prefix matched
                                    match_found <= 1'b1;
                                    char_idx <= 3'd0;
                                end else begin
                                    char_idx <= char_idx + 3'd1;
                                end
                            end else begin
                                // Mismatch - move to next string
                                char_idx <= 3'd0;
                                string_idx <= string_idx + 3'd1;
                                match_found <= 1'b0;
                            end
                        end else begin
                            // End of prefix reached without mismatch
                            match_found <= 1'b1;
                            char_idx <= 3'd0;
                        end
                    end else begin
                        // Skip invalid string or reached end
                        char_idx <= 3'd0;
                        string_idx <= string_idx + 3'd1;
                    end
                    
                    // Timeout protection
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= DONE;
                    end
                end
                
                COPY: begin
                    if (match_found) begin
                        // Copy string character by character
                        if (copy_idx < 8) begin
                            temp_result_str[copy_idx] <= strings[string_idx][copy_idx*8 +: 8];
                            temp_result_valid[copy_idx] <= 1'b1;
                            copy_idx <= copy_idx + 3'd1;
                        end
                    end
                    
                    if (copy_idx == 8'd7) begin
                        // Finished copying
                        copy_idx <= 3'd0;
                        match_found <= 1'b0;
                        string_idx <= string_idx + 3'd1;
                        temp_result_count <= temp_result_count + 4'd1;
                    end
                    
                    // Timeout protection
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= DONE;
                    end
                end
                
                DONE: begin
                    // Transfer to outputs and clear temp
                    result_str <= temp_result_str;
                    result_valid <= temp_result_valid;
                    result_count <= temp_result_count;
                    done <= 1'b1;
                    
                    // Clear temp for next operation
                    for (i = 0; i < 8; i = i + 1) begin
                        temp_result_str[i] <= 8'd0;
                    end
                    temp_result_valid <= 8'd0;
                    temp_result_count <= 4'd0;
                end
                
                default: begin
                    state <= IDLE;
                    string_idx <= 3'd0;
                    char_idx <= 3'd0;
                end
            endcase
        end
    end

endmodule