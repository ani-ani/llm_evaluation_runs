module min_subsegment_removal(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] arr [0:7],
    input wire [3:0] len,
    output reg [7:0] result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] CHECK_DISTINCT = 3'd1;
    localparam [2:0] EXPAND_RIGHT = 3'd2;
    localparam [2:0] SHRINK_LEFT = 3'd3;
    localparam [2:0] UPDATE_MIN = 3'd4;
    localparam [2:0] FINISH = 3'd5;

    reg [2:0] state, next_state;
    reg [7:0] left, right;
    reg [7:0] min_len;
    reg [7:0] current_len;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd255;

    // Frequency table: 256 x 4-bit counters
    reg [3:0] freq_table [0:255];
    integer i;

    // Check if array is distinct
    reg is_distinct;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 8'd0;
            done <= 1'b0;
            left <= 8'd0;
            right <= 8'd0;
            min_len <= 8'd8;
            current_len <= 8'd0;
            cycle_count <= 8'd0;
            is_distinct <= 1'b1;
            
            // Initialize frequency table
            for (i = 0; i < 256; i = i + 1) begin
                freq_table[i] <= 4'd0;
            end
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        next_state <= CHECK_DISTINCT;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                CHECK_DISTINCT: begin
                    // Check if array is already distinct
                    is_distinct <= 1'b1;
                    for (i = 0; i < len; i = i + 1) begin
                        if (freq_table[arr[i]] > 4'd0) begin
                            is_distinct <= 1'b0;
                        end
                        freq_table[arr[i]] <= freq_table[arr[i]] + 4'd1;
                    end
                    
                    if (is_distinct) begin
                        result <= 8'd0;
                        next_state <= FINISH;
                    end else begin
                        // Reset frequency table for window approach
                        for (i = 0; i < 256; i = i + 1) begin
                            freq_table[i] <= 4'd0;
                        end
                        
                        left <= 8'd0;
                        right <= 8'd0;
                        min_len <= 8'd8;
                        current_len <= 8'd0;
                        next_state <= EXPAND_RIGHT;
                    end
                end

                EXPAND_RIGHT: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Expand right pointer
                    if (right < len) begin
                        freq_table[arr[right]] <= freq_table[arr[right]] + 4'd1;
                        right <= right + 8'd1;
                        current_len <= current_len + 8'd1;
                        
                        // Check if all elements outside window are distinct
                        reg all_distinct;
                        integer j;
                        all_distinct <= 1'b1;
                        
                        for (j = 0; j < left; j = j + 1) begin
                            if (freq_table[arr[j]] > 4'd1) begin
                                all_distinct <= 1'b0;
                            end
                        end
                        
                        for (j = right; j < len; j = j + 1) begin
                            if (freq_table[arr[j]] > 4'd1) begin
                                all_distinct <= 1'b0;
                            end
                        end
                        
                        if (all_distinct) begin
                            next_state <= SHRINK_LEFT;
                        end else if (right == len) begin
                            next_state <= UPDATE_MIN;
                        end else begin
                            next_state <= EXPAND_RIGHT;
                        end
                    end else begin
                        next_state <= UPDATE_MIN;
                    end
                end

                SHRINK_LEFT: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Shrink left pointer
                    if (left < right) begin
                        freq_table[arr[left]] <= freq_table[arr[left]] - 4'd1;
                        left <= left + 8'd1;
                        current_len <= current_len - 8'd1;
                        
                        // Check if all elements outside window are distinct
                        reg all_distinct;
                        integer j;
                        all_distinct <= 1'b1;
                        
                        for (j = 0; j < left; j = j + 1) begin
                            if (freq_table[arr[j]] > 4'd1) begin
                                all_distinct <= 1'b0;
                            end
                        end
                        
                        for (j = right; j < len; j = j + 1) begin
                            if (freq_table[arr[j]] > 4'd1) begin
                                all_distinct <= 1'b0;
                            end
                        end
                        
                        if (all_distinct) begin
                            if (current_len < min_len) begin
                                min_len <= current_len;
                            end
                            next_state <= SHRINK_LEFT;
                        end else begin
                            next_state <= EXPAND_RIGHT;
                        end
                    end else begin
                        next_state <= UPDATE_MIN;
                    end
                end

                UPDATE_MIN: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Update minimum length
                    if (current_len < min_len) begin
                        min_len <= current_len;
                    end
                    
                    // Move to next window
                    if (left < len - 8'd1) begin
                        // Reset for next window
                        for (i = 0; i < 256; i = i + 1) begin
                            freq_table[i] <= 4'd0;
                        end
                        
                        left <= left + 8'd1;
                        right <= left;
                        current_len <= 8'd0;
                        next_state <= EXPAND_RIGHT;
                    end else begin
                        result <= min_len;
                        next_state <= FINISH;
                    end
                end

                FINISH: begin
                    done <= 1'b1;
                    next_state <= IDLE;
                end

                default: begin
                    next_state <= IDLE;
                    done <= 1'b0;
                end
            endcase
            
            // Safety: prevent infinite loops
            if (cycle_count >= MAX_CYCLES) begin
                result <= 8'd8;
                done <= 1'b1;
                next_state <= IDLE;
            end
        end
    end

endmodule