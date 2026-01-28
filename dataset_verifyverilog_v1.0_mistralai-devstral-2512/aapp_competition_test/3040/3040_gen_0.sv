module longest_repeated_substring(
    input clk,
    input rst_n,
    input start,
    input [3:0] str_len,
    input [7:0] str [0:15],
    output reg [3:0] result_len,
    output reg [3:0] result_start,
    output reg [7:0] result_str [0:15],
    output reg done,
    output reg busy
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] INIT = 3'd1;
    localparam [2:0] CHECK_LEN = 3'd2;
    localparam [2:0] CHECK_START = 3'd3;
    localparam [2:0] COMPARE = 3'd4;
    localparam [2:0] UPDATE_RESULT = 3'd5;
    localparam [2:0] FINISH = 3'd6;

    reg [2:0] state, next_state;

    // Current substring length being checked
    reg [3:0] current_len;

    // Current starting position for substring
    reg [3:0] current_start;

    // Current comparison position
    reg [3:0] compare_pos;

    // Temporary storage for current substring
    reg [7:0] temp_substr [0:15];

    // Best result tracking
    reg [3:0] best_len;
    reg [3:0] best_start;
    reg [7:0] best_str [0:15];

    // Comparison result
    reg substring_found;
    reg substring_better;

    // Cycle counter for safety
    reg [9:0] cycle_count;
    localparam [9:0] MAX_CYCLES = 10'd1000;

    // Initialize all registers
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            current_len <= 4'd0;
            current_start <= 4'd0;
            compare_pos <= 4'd0;
            best_len <= 4'd0;
            best_start <= 4'd0;
            done <= 1'b0;
            busy <= 1'b0;
            cycle_count <= 10'd0;
            
            // Initialize arrays
            integer i;
            for (i = 0; i < 16; i = i + 1) begin
                temp_substr[i] <= 8'd0;
                best_str[i] <= 8'd0;
                result_str[i] <= 8'd0;
            end
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    busy <= 1'b0;
                    done <= 1'b0;
                    if (start) begin
                        next_state <= INIT;
                    end
                end

                INIT: begin
                    busy <= 1'b1;
                    done <= 1'b0;
                    cycle_count <= 10'd0;
                    current_len <= str_len;
                    best_len <= 4'd0;
                    next_state <= CHECK_LEN;
                end

                CHECK_LEN: begin
                    if (current_len == 4'd0) begin
                        next_state <= FINISH;
                    end else if (current_len > str_len) begin
                        current_len <= current_len - 4'd1;
                    end else begin
                        current_start <= 4'd0;
                        next_state <= CHECK_START;
                    end
                end

                CHECK_START: begin
                    // Extract current substring
                    integer i;
                    for (i = 0; i < 16; i = i + 1) begin
                        if (i < current_len) begin
                            temp_substr[i] <= str[current_start + i];
                        end else begin
                            temp_substr[i] <= 8'd0;
                        end
                    end

                    // Check if this substring appears at least twice
                    substring_found <= 1'b0;
                    compare_pos <= current_start + 4'd1;
                    next_state <= COMPARE;
                end

                COMPARE: begin
                    reg [7:0] match;
                    reg [3:0] j;
                    
                    // Compare temp_substr with str[compare_pos:compare_pos+current_len]
                    match = 1'b1;
                    for (j = 0; j < current_len; j = j + 1) begin
                        if (temp_substr[j] != str[compare_pos + j]) begin
                            match = 1'b0;
                        end
                    end

                    if (match && (compare_pos + current_len) <= str_len) begin
                        substring_found <= 1'b1;
                    end

                    // Move to next comparison position
                    compare_pos <= compare_pos + 4'd1;
                    
                    if (compare_pos + current_len > str_len) begin
                        if (substring_found) begin
                            // Check if this is better than current best
                            if (current_len > best_len) begin
                                substring_better <= 1'b1;
                            end else if (current_len == best_len) begin
                                // Lexicographic comparison
                                reg [3:0] k;
                                substring_better <= 1'b0;
                                for (k = 0; k < current_len; k = k + 1) begin
                                    if (temp_substr[k] < best_str[k]) begin
                                        substring_better <= 1'b1;
                                    end else if (temp_substr[k] > best_str[k]) begin
                                        substring_better <= 1'b0;
                                    end
                                end
                            end else begin
                                substring_better <= 1'b0;
                            end
                            next_state <= UPDATE_RESULT;
                        end else begin
                            // Move to next start position
                            current_start <= current_start + 4'd1;
                            if (current_start + current_len > str_len) begin
                                current_len <= current_len - 4'd1;
                                next_state <= CHECK_LEN;
                            end else begin
                                next_state <= CHECK_START;
                            end
                        end
                    end
                end

                UPDATE_RESULT: begin
                    if (substring_better) begin
                        best_len <= current_len;
                        best_start <= current_start;
                        
                        // Copy substring to best_str
                        integer i;
                        for (i = 0; i < 16; i = i + 1) begin
                            if (i < current_len) begin
                                best_str[i] <= temp_substr[i];
                            end else begin
                                best_str[i] <= 8'd0;
                            end
                        end
                    end

                    // Move to next start position
                    current_start <= current_start + 4'd1;
                    if (current_start + current_len > str_len) begin
                        current_len <= current_len - 4'd1;
                        next_state <= CHECK_LEN;
                    end else begin
                        next_state <= CHECK_START;
                    end
                end

                FINISH: begin
                    // Output results
                    result_len <= best_len;
                    result_start <= best_start;
                    
                    // Copy best_str to result_str
                    integer i;
                    for (i = 0; i < 16; i = i + 1) begin
                        result_str[i] <= best_str[i];
                    end

                    done <= 1'b1;
                    busy <= 1'b0;
                    next_state <= IDLE;
                end

                default: begin
                    next_state <= IDLE;
                    busy <= 1'b0;
                    done <= 1'b0;
                end
            endcase

            // Safety: prevent infinite loops
            cycle_count <= cycle_count + 10'd1;
            if (cycle_count >= MAX_CYCLES) begin
                next_state <= IDLE;
                busy <= 1'b0;
            end
        end
    end

endmodule