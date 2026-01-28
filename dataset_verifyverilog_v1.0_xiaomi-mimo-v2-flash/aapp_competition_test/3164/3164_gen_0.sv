module findLongestSubarray (
    input clk,
    input rst_n,
    input start,
    input [15:0] arr [0:255],
    input [5:0] len,
    output reg [15:0] result,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE     = 3'd0;
    localparam [2:0] SETUP    = 3'd1;
    localparam [2:0] SCAN     = 3'd2;
    localparam [2:0] VALIDATE = 3'd3;
    localparam [2:0] OPTIMIZE = 3'd4;
    localparam [2:0] COMPLETE = 3'd5;

    // Registers
    reg [2:0] state;
    reg [2:0] next_state;
    reg [5:0] left_ptr;
    reg [5:0] right_ptr;
    reg [5:0] max_len;
    reg [5:0] cur_len;
    reg [5:0] opt_left;
    reg [7:0] freq [0:255];  // Frequency counters for values 0-255
    reg [15:0] temp_val;
    reg valid_flag;
    reg [7:0] i;
    reg [15:0] cycle_count;
    localparam [15:0] MAX_CYCLES = 16'd16384;

    // Temporal registers for combinational logic
    reg [5:0] temp_len;
    reg [5:0] temp_opt_left;
    reg temp_valid;
    reg [7:0] idx;

    // Next state logic
    always @(*) begin
        case (state)
            IDLE:       next_state = start ? SETUP : IDLE;
            SETUP:      next_state = SCAN;
            SCAN:       next_state = (right_ptr >= len) ? VALIDATE : SCAN;
            VALIDATE:   next_state = valid_flag ? OPTIMIZE : COMPLETE;
            OPTIMIZE:   next_state = (opt_left >= len) ? COMPLETE : OPTIMIZE;
            COMPLETE:   next_state = IDLE;
            default:    next_state = IDLE;
        endcase
    end

    // Combinational validation logic
    always @(*) begin
        temp_valid = 1'b1;
        temp_len = right_ptr - left_ptr;
        temp_opt_left = opt_left;
        
        // Check all frequencies in current window
        for (idx = left_ptr; idx < right_ptr; idx = idx + 1) begin
            if (freq[arr[idx]] != 8'd2) begin
                temp_valid = 1'b0;
            end
        end
    end

    // State machine and data path
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            left_ptr <= 6'd0;
            right_ptr <= 6'd0;
            max_len <= 6'd0;
            cur_len <= 6'd0;
            opt_left <= 6'd0;
            temp_val <= 16'd0;
            valid_flag <= 1'b0;
            cycle_count <= 16'd0;
            // Initialize frequency array
            for (i = 0; i < 8'd255; i = i + 1) begin
                freq[i] <= 8'd0;
            end
            freq[255] <= 8'd0;
        end else begin
            cycle_count <= cycle_count + 16'd1;
            done <= 1'b0;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 16'd0;
                end
                
                SETUP: begin
                    left_ptr <= 6'd0;
                    right_ptr <= 6'd0;
                    max_len <= 6'd0;
                    opt_left <= 6'd0;
                    // Clear frequency array
                    for (i = 0; i < 8'd255; i = i + 1) begin
                        freq[i] <= 8'd0;
                    end
                    freq[255] <= 8'd0;
                end
                
                SCAN: begin
                    // Expand window to right
                    if (right_ptr < len) begin
                        temp_val <= arr[right_ptr];
                        if (arr[right_ptr] < 16'd256) begin
                            freq[arr[right_ptr]] <= freq[arr[right_ptr]] + 8'd1;
                        end
                        right_ptr <= right_ptr + 6'd1;
                    end
                end
                
                VALIDATE: begin
                    valid_flag <= temp_valid;
                    cur_len <= temp_len;
                end
                
                OPTIMIZE: begin
                    // Try to shrink from left
                    if (opt_left < len) begin
                        temp_val <= arr[opt_left];
                        if (arr[opt_left] < 16'd256) begin
                            if (freq[arr[opt_left]] > 8'd0) begin
                                freq[arr[opt_left]] <= freq[arr[opt_left]] - 8'd1;
                            end
                        end
                        opt_left <= opt_left + 6'd1;
                        
                        // Re-check validity with new window
                        if (temp_valid && (right_ptr - (opt_left + 6'd1)) < cur_len) begin
                            cur_len <= right_ptr - (opt_left + 1);
                        end
                    end
                end
                
                COMPLETE: begin
                    // Update max length
                    if (cur_len > max_len) begin
                        max_len <= cur_len;
                    end
                    done <= 1'b1;
                    result <= {10'd0, max_len};
                    // Reset pointers for next window
                    left_ptr <= left_ptr + 6'd1;
                    right_ptr <= left_ptr + 6'd1;
                    opt_left <= left_ptr + 6'd1;
                    // Clear frequency array for next window
                    for (i = 0; i < 8'd255; i = i + 1) begin
                        freq[i] <= 8'd0;
                    end
                    freq[255] <= 8'd0;
                    
                    // Check if all windows processed
                    if (left_ptr >= len) begin
                        state <= IDLE;
                    end else begin
                        state <= SCAN;
                    end
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule