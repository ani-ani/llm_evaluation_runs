module MaxNumberWithKSwaps(
    input clk,
    input rst_n,
    input start,
    input [3:0] digits_in [0:7],
    input [2:0] num_digits,
    input [4:0] k,
    output reg [3:0] digits_out [0:7],
    output reg valid,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE      = 3'd0;
    localparam [2:0] INIT      = 3'd1;
    localparam [2:0] PROCESS   = 3'd2;
    localparam [2:0] FINISH    = 3'd3;
    
    reg [2:0] state, next_state;
    
    // State cache: 64 states max
    localparam [5:0] MAX_STATES = 6'd64;
    localparam [5:0] MAX_ITER   = 7'd100;
    
    // State FIFO
    reg [3:0] state_cache [0:63][0:7];  // 64 states, 8 digits each
    reg [4:0] swaps_left [0:63];        // Swaps remaining for each state
    reg [5:0] fifo_head, fifo_tail;
    reg [5:0] fifo_count;
    
    // Best solution tracking
    reg [3:0] best_digits [0:7];
    reg [31:0] best_value;
    reg [31:0] current_value;
    
    // Iteration control
    reg [6:0] iter_count;
    reg [5:0] state_idx;
    reg [5:0] swap_i, swap_j;
    reg [5:0] new_state_idx;
    
    // Temporary storage for swapping
    reg [3:0] temp_digits [0:7];
    reg [3:0] temp_digit;
    
    // Helper signals
    reg state_cache_full;
    reg state_cache_empty;
    reg found_better;
    reg swap_valid;
    
    // Convert digits to value for comparison
    always @(*) begin
        current_value = 32'd0;
        for (integer i = 0; i < 8; i = i + 1) begin
            if (i < num_digits) begin
                current_value = current_value * 10 + temp_digits[i];
            end
        end
    end
    
    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            valid <= 1'b0;
            done <= 1'b0;
            fifo_head <= 6'd0;
            fifo_tail <= 6'd0;
            fifo_count <= 6'd0;
            iter_count <= 7'd0;
            state_idx <= 5'd0;
            swap_i <= 5'd0;
            swap_j <= 5'd0;
            new_state_idx <= 5'd0;
            best_value <= 32'd0;
            
            // Initialize state cache
            for (integer i = 0; i < 64; i = i + 1) begin
                for (integer j = 0; j < 8; j = j + 1) begin
                    state_cache[i][j] <= 4'd0;
                end
                swaps_left[i] <= 5'd0;
            end
            
            // Initialize output
            for (integer i = 0; i < 8; i = i + 1) begin
                digits_out[i] <= 4'd0;
                best_digits[i] <= 4'd0;
            end
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    valid <= 1'b0;
                    done <= 1'b0;
                    if (start) begin
                        next_state <= INIT;
                    end
                end
                
                INIT: begin
                    // Initialize FIFO with starting state
                    for (integer i = 0; i < 8; i = i + 1) begin
                        state_cache[0][i] <= digits_in[i];
                    end
                    swaps_left[0] <= k;
                    fifo_head <= 6'd0;
                    fifo_tail <= 6'd1;
                    fifo_count <= 6'd1;
                    
                    // Initialize best solution
                    for (integer i = 0; i < 8; i = i + 1) begin
                        best_digits[i] <= digits_in[i];
                    end
                    
                    // Calculate initial value
                    best_value = 32'd0;
                    for (integer i = 0; i < num_digits; i = i + 1) begin
                        best_value = best_value * 10 + digits_in[i];
                    end
                    
                    iter_count <= 7'd0;
                    state_idx <= 5'd0;
                    next_state <= PROCESS;
                end
                
                PROCESS: begin
                    valid <= 1'b0;
                    done <= 1'b0;
                    
                    // Check if we've processed all states or reached max iterations
                    if (fifo_count == 6'd0 || iter_count >= MAX_ITER) begin
                        next_state <= FINISH;
                    end else begin
                        // Process current state
                        for (integer i = 0; i < 8; i = i + 1) begin
                            temp_digits[i] <= state_cache[state_idx][i];
                        end
                        
                        // Generate new states by swapping
                        if (swap_i < 8 && swap_j < 8) begin
                            if (swap_i != swap_j && swap_i < num_digits && swap_j < num_digits) begin
                                // Check if swap would create leading zero
                                swap_valid = 1'b1;
                                if (swap_i == 0 && temp_digits[swap_j] == 4'd0) begin
                                    swap_valid = 1'b0;
                                end else if (swap_j == 0 && temp_digits[swap_i] == 4'd0) begin
                                    swap_valid = 1'b0;
                                end
                                
                                if (swap_valid && swaps_left[state_idx] > 5'd0) begin
                                    // Perform swap
                                    temp_digit <= temp_digits[swap_i];
                                    temp_digits[swap_i] <= temp_digits[swap_j];
                                    temp_digits[swap_j] <= temp_digit;
                                    
                                    // Check if this is a better solution for exactly k swaps
                                    if (swaps_left[state_idx] - 5'd1 == k) begin
                                        found_better = 1'b0;
                                        if (current_value > best_value) begin
                                            found_better = 1'b1;
                                            best_value <= current_value;
                                            for (integer i = 0; i < 8; i = i + 1) begin
                                                best_digits[i] <= temp_digits[i];
                                            end
                                        end
                                    end
                                    
                                    // Add to FIFO if not full and swaps remaining > 0
                                    if (fifo_count < MAX_STATES && swaps_left[state_idx] > 5'd1) begin
                                        for (integer i = 0; i < 8; i = i + 1) begin
                                            state_cache[fifo_tail][i] <= temp_digits[i];
                                        end
                                        swaps_left[fifo_tail] <= swaps_left[state_idx] - 5'd1;
                                        fifo_tail <= fifo_tail + 6'd1;
                                        fifo_count <= fifo_count + 6'd1;
                                    end
                                    
                                    // Swap back
                                    temp_digit <= temp_digits[swap_i];
                                    temp_digits[swap_i] <= temp_digits[swap_j];
                                    temp_digits[swap_j] <= temp_digit;
                                end
                                
                                // Move to next swap pair
                                if (swap_j == 7) begin
                                    swap_j <= 5'd0;
                                    swap_i <= swap_i + 5'd1;
                                end else begin
                                    swap_j <= swap_j + 5'd1;
                                end
                            end else begin
                                if (swap_j == 7) begin
                                    swap_j <= 5'd0;
                                    swap_i <= swap_i + 5'd1;
                                end else begin
                                    swap_j <= swap_j + 5'd1;
                                end
                            end
                        end else begin
                            // Move to next state
                            state_idx <= state_idx + 5'd1;
                            fifo_count <= fifo_count - 6'd1;
                            swap_i <= 5'd0;
                            swap_j <= 5'd0;
                            iter_count <= iter_count + 7'd1;
                        end
                    end
                end
                
                FINISH: begin
                    // Output best solution
                    for (integer i = 0; i < 8; i = i + 1) begin
                        digits_out[i] <= best_digits[i];
                    end
                    valid <= 1'b1;
                    done <= 1'b1;
                    next_state <= IDLE;
                end
                
                default: begin
                    next_state <= IDLE;
                    valid <= 1'b0;
                    done <= 1'b0;
                end
            endcase
        end
    end
    
    // State cache full/empty signals
    always @(*) begin
        state_cache_full = (fifo_count == MAX_STATES);
        state_cache_empty = (fifo_count == 6'd0);
    end

endmodule