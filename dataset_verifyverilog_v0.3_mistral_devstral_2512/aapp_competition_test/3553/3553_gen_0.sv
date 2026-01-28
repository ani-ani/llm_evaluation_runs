module ArrayQueryProcessor(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [1:0] query_type,
    input wire [3:0] update_pos,
    input wire [2:0] update_value,
    output reg [15:0] result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE      = 3'd0;
    localparam [2:0] UPDATE    = 3'd1;
    localparam [2:0] QUERY     = 3'd2;
    localparam [2:0] COMPUTE   = 3'd3;
    localparam [2:0] FINISH    = 3'd4;

    // Array storage (16 elements, 3-bit each)
    reg [2:0] array [0:15];
    
    // State machine registers
    reg [2:0] state, next_state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd200;
    
    // Query processing registers
    reg [3:0] left_idx;
    reg [3:0] right_idx;
    reg [3:0] min_length;
    reg [4:0] found_count;
    reg [4:0] target_count;
    reg [3:0] current_left;
    reg [3:0] current_right;
    reg [3:0] temp_min;
    reg found_valid;
    reg [4:0] temp_found;
    reg [3:0] i, j, k;

    // Initialize all registers
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            
            // Initialize array
            for (i = 0; i < 16; i = i + 1) begin
                array[i] <= 3'd0;
            end
            
            // Initialize query processing registers
            left_idx <= 4'd0;
            right_idx <= 4'd0;
            min_length <= 4'd16;
            found_count <= 5'd0;
            target_count <= 5'd0;
            current_left <= 4'd0;
            current_right <= 4'd0;
            temp_min <= 4'd16;
            found_valid <= 1'b0;
            temp_found <= 5'd0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    
                    if (start) begin
                        if (query_type == 2'd1) begin
                            next_state <= UPDATE;
                        end else if (query_type == 2'd2) begin
                            next_state <= QUERY;
                        end
                    end
                end
                
                UPDATE: begin
                    // Perform update operation
                    array[update_pos - 4'd1] <= update_value;
                    next_state <= IDLE;
                end
                
                QUERY: begin
                    // Initialize query parameters
                    min_length <= 4'd16;
                    found_valid <= 1'b0;
                    current_left <= 4'd0;
                    next_state <= COMPUTE;
                end
                
                COMPUTE: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Sliding window algorithm
                    if (current_left < 4'd16) begin
                        // Reset for new left index
                        if (current_left == 4'd0 || current_left == left_idx + 4'd1) begin
                            temp_found <= 5'd0;
                            current_right <= current_left;
                        end
                        
                        // Check current window
                        if (current_right < 4'd16) begin
                            // Count unique values in window [current_left, current_right]
                            for (k = 0; k < 5; k = k + 1) begin
                                for (j = current_left; j <= current_right; j = j + 1) begin
                                    if (array[j] == k) begin
                                        temp_found[k] <= 1'b1;
                                    end
                                end
                            end
                            
                            // Check if all values 1-5 are present
                            if (temp_found[1:5] == 5'b11111) begin
                                // Found valid window, check if it's the shortest
                                temp_min <= current_right - current_left + 4'd1;
                                if (temp_min < min_length) begin
                                    min_length <= temp_min;
                                    found_valid <= 1'b1;
                                end
                                
                                // Move to next left index
                                current_left <= current_left + 4'd1;
                            end else begin
                                // Expand window to the right
                                current_right <= current_right + 4'd1;
                            end
                        end else begin
                            // Reached end of array, move to next left index
                            current_left <= current_left + 4'd1;
                        end
                    end else begin
                        // Finished processing all windows
                        if (found_valid) begin
                            result <= min_length;
                        end else begin
                            result <= 16'd65535; // -1 in 16-bit unsigned
                        end
                        next_state <= FINISH;
                    end
                    
                    // Safety exit condition
                    if (cycle_count >= MAX_CYCLES) begin
                        result <= 16'd65535;
                        next_state <= FINISH;
                    end
                end
                
                FINISH: begin
                    done <= 1'b1;
                    next_state <= IDLE;
                end
                
                default: next_state <= IDLE;
            endcase
        end
    end
endmodule