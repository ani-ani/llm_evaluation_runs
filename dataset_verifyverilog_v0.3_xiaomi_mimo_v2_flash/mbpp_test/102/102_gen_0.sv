module snake_to_camel_case (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [15:0][7:0] input_str,
    input wire [4:0] input_len,
    output reg [15:0][7:0] output_str,
    output reg [4:0] output_len,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE           = 3'd0;
    localparam [2:0] CAPITALIZE     = 3'd1;
    localparam [2:0] UNDERSCORE_WAIT = 3'd2;
    localparam [2:0] COPY_UPPER     = 3'd3;
    localparam [2:0] COPY_LOWER     = 3'd4;
    localparam [2:0] DONE           = 3'd5;

    // Registers
    reg [2:0] state, next_state;
    reg [4:0] idx_in, idx_in_next;
    reg [4:0] idx_out, idx_out_next;
    reg capital_flag, capital_flag_next;
    reg underscore_seen, underscore_seen_next;
    reg [7:0] char, char_next;
    reg [4:0] cycle_count, cycle_count_next;
    
    // ASCII constants
    localparam [7:0] UNDERSCORE = 8'd95;
    localparam [7:0] LOWER_A    = 8'd97;
    localparam [7:0] LOWER_Z    = 8'd122;
    localparam [7:0] UPPER_A    = 8'd65;
    localparam [7:0] UPPER_Z    = 8'd90;
    localparam [7:0] TO_UPPER   = 8'd32;  // diff between lower and upper

    // State transition and next state logic
    always @(*) begin
        next_state = state;
        idx_in_next = idx_in;
        idx_out_next = idx_out;
        capital_flag_next = capital_flag;
        underscore_seen_next = underscore_seen;
        char_next = char;
        cycle_count_next = cycle_count;
        
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = CAPITALIZE;
                    idx_in_next = 5'd0;
                    idx_out_next = 5'd0;
                    capital_flag_next = 1'b1;  // First char always capitalize
                    underscore_seen_next = 1'b0;
                    cycle_count_next = 5'd0;
                end
            end
            
            CAPITALIZE: begin
                if (idx_in < input_len && cycle_count < 5'd16) begin
                    char_next = input_str[idx_in];
                    if (char_next == UNDERSCORE) begin
                        // Skip underscore, wait for next char
                        idx_in_next = idx_in + 5'd1;
                        underscore_seen_next = 1'b1;
                        next_state = UNDERSCORE_WAIT;
                    end else begin
                        // Valid char, process it
                        if (capital_flag && char_next >= LOWER_A && char_next <= LOWER_Z) begin
                            // Capitalize lowercase letter
                            output_str[idx_out] = char_next - TO_UPPER;
                        end else begin
                            output_str[idx_out] = char_next;
                        end
                        idx_out_next = idx_out + 5'd1;
                        idx_in_next = idx_in + 5'd1;
                        capital_flag_next = 1'b0;
                        next_state = COPY_LOWER;
                    end
                    cycle_count_next = cycle_count + 5'd1;
                end else begin
                    // Input exhausted
                    next_state = DONE;
                end
            end
            
            UNDERSCORE_WAIT: begin
                if (idx_in < input_len && cycle_count < 5'd16) begin
                    char_next = input_str[idx_in];
                    if (char_next == UNDERSCORE) begin
                        // Multiple underscores, skip
                        idx_in_next = idx_in + 5'd1;
                        cycle_count_next = cycle_count + 5'd1;
                    end else begin
                        // Found non-underscore after underscore
                        // Capitalize it
                        if (char_next >= LOWER_A && char_next <= LOWER_Z) begin
                            output_str[idx_out] = char_next - TO_UPPER;
                        end else begin
                            output_str[idx_out] = char_next;
                        end
                        idx_out_next = idx_out + 5'd1;
                        idx_in_next = idx_in + 5'd1;
                        underscore_seen_next = 1'b0;
                        next_state = COPY_LOWER;
                        cycle_count_next = cycle_count + 5'd1;
                    end
                end else begin
                    // Input exhausted
                    next_state = DONE;
                end
            end
            
            COPY_LOWER: begin
                if (idx_in < input_len && cycle_count < 5'd16) begin
                    char_next = input_str[idx_in];
                    if (char_next == UNDERSCORE) begin
                        // Found underscore, skip it and wait for next char
                        idx_in_next = idx_in + 5'd1;
                        underscore_seen_next = 1'b1;
                        next_state = UNDERSCORE_WAIT;
                        cycle_count_next = cycle_count + 5'd1;
                    end else begin
                        // Copy character as-is (no capitalization)
                        output_str[idx_out] = char_next;
                        idx_out_next = idx_out + 5'd1;
                        idx_in_next = idx_in + 5'd1;
                        cycle_count_next = cycle_count + 5'd1;
                    end
                end else begin
                    // Input exhausted
                    next_state = DONE;
                end
            end
            
            DONE: begin
                next_state = IDLE;
            end
            
            default: begin
                next_state = IDLE;
            end
        endcase
    end

    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            idx_in <= 5'd0;
            idx_out <= 5'd0;
            capital_flag <= 1'b0;
            underscore_seen <= 1'b0;
            char <= 8'd0;
            cycle_count <= 5'd0;
            done <= 1'b0;
            output_len <= 5'd0;
            // Clear all output characters
            output_str[0] <= 8'd0;
            output_str[1] <= 8'd0;
            output_str[2] <= 8'd0;
            output_str[3] <= 8'd0;
            output_str[4] <= 8'd0;
            output_str[5] <= 8'd0;
            output_str[6] <= 8'd0;
            output_str[7] <= 8'd0;
            output_str[8] <= 8'd0;
            output_str[9] <= 8'd0;
            output_str[10] <= 8'd0;
            output_str[11] <= 8'd0;
            output_str[12] <= 8'd0;
            output_str[13] <= 8'd0;
            output_str[14] <= 8'd0;
            output_str[15] <= 8'd0;
        end else begin
            state <= next_state;
            idx_in <= idx_in_next;
            idx_out <= idx_out_next;
            capital_flag <= capital_flag_next;
            underscore_seen <= underscore_seen_next;
            char <= char_next;
            cycle_count <= cycle_count_next;
            
            if (state == DONE) begin
                done <= 1'b1;
                output_len <= idx_out;
            end else if (state == IDLE && start) begin
                done <= 1'b0;
            end else begin
                done <= 1'b0;
            end
        end
    end

endmodule