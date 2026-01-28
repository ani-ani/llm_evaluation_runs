module ShortestTimeSequence (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [4:0] start_hh,
    input wire [5:0] start_mm,
    input wire [4:0] target_hh,
    input wire [5:0] target_mm,
    output reg result_valid,
    output reg [3:0] result_len,
    output reg [10:0] result_timestamps [0:15],
    output reg done
);

    // State encoding
    localparam [2:0] IDLE      = 3'd0;
    localparam [2:0] INIT_BFS  = 3'd1;
    localparam [2:0] EXPAND    = 3'd2;
    localparam [2:0] CHECK_FOUND = 3'd3;
    localparam [2:0] RECONSTRUCT = 3'd4;
    localparam [2:0] OUTPUT    = 3'd5;
    localparam [2:0] FINISH    = 3'd6;

    // Internal signals
    reg [2:0] state, next_state;
    reg [10:0] start_idx;  // 0-1439
    reg [10:0] target_idx; // 0-1439
    reg [10:0] current_idx;
    
    // BFS Queue: stores indices (0-1439)
    reg [10:0] queue [0:63];
    reg [5:0] queue_head;  // Read pointer
    reg [5:0] queue_tail;  // Write pointer
    reg [5:0] queue_size;
    
    // Visited array: 1440 bits (180 bytes)
    reg [1439:0] visited;
    
    // Parent pointers: stores previous index for each node
    reg [10:0] parent [0:1439];
    
    // Path reconstruction
    reg [10:0] path_stack [0:15];
    reg [3:0] stack_ptr;
    reg [10:0] reconstruct_idx;
    
    // Cycle counter for safety
    reg [9:0] cycle_count;  // 0-1023
    localparam [9:0] MAX_CYCLES = 10'd1000;
    
    // Generation counter for visited tracking
    reg [2:0] bfs_generation;  // Increments each BFS
    reg [1439:0] visited_generation; // For generation-based clearing
    
    // Temporary neighbor computation
    reg [10:0] neighbor_idx;
    reg [4:0] hour, minute;
    reg [4:0] h1, h0, m1, m0;
    reg [3:0] digit_pos;
    reg [10:0] temp_val;
    reg [10:0] neighbor_val;
    reg [1:0] digit_op;  // 0: -, 1: +
    reg valid_neighbor;
    
    // For path packing
    reg [3:0] output_idx;
    reg [10:0] packed_time;
    
    // Timing control
    reg start_dly;
    
    // Initialize outputs
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            result_valid <= 1'b0;
            result_len <= 4'd0;
            done <= 1'b0;
            result_timestamps[0] <= 11'd0;
            result_timestamps[1] <= 11'd0;
            result_timestamps[2] <= 11'd0;
            result_timestamps[3] <= 11'd0;
            result_timestamps[4] <= 11'd0;
            result_timestamps[5] <= 11'd0;
            result_timestamps[6] <= 11'd0;
            result_timestamps[7] <= 11'd0;
            result_timestamps[8] <= 11'd0;
            result_timestamps[9] <= 11'd0;
            result_timestamps[10] <= 11'd0;
            result_timestamps[11] <= 11'd0;
            result_timestamps[12] <= 11'd0;
            result_timestamps[13] <= 11'd0;
            result_timestamps[14] <= 11'd0;
            result_timestamps[15] <= 11'd0;
        end else begin
            case (state)
                OUTPUT: begin
                    result_timestamps[output_idx] <= packed_time;
                    done <= 1'b0;
                end
                FINISH: begin
                    result_valid <= 1'b1;
                    done <= 1'b1;
                end
                default: begin
                    result_valid <= 1'b0;
                    done <= 1'b0;
                end
            endcase
        end
    end

    // FSM State transition
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            start_dly <= 1'b0;
            cycle_count <= 10'd0;
            visited <= 1440'd0;
            queue_head <= 6'd0;
            queue_tail <= 6'd0;
            queue_size <= 6'd0;
            result_len <= 4'd0;
            bfs_generation <= 3'd0;
        end else begin
            start_dly <= start;
            
            case (state)
                IDLE: begin
                    cycle_count <= 10'd0;
                    if (start && !start_dly) begin
                        state <= INIT_BFS;
                    end else begin
                        state <= IDLE;
                    end
                end
                
                INIT_BFS: begin
                    // Convert times to indices
                    // start_hh (0-23), start_mm (0-59)
                    // target_hh (0-23), target_mm (0-59)
                    start_idx <= {start_hh, start_mm};
                    target_idx <= {target_hh, target_mm};
                    
                    // Clear visited for this BFS generation
                    visited <= 1440'd0;
                    
                    // Initialize queue
                    queue_head <= 6'd0;
                    queue_tail <= 6'd0;
                    queue_size <= 6'd0;
                    
                    // Mark start as visited
                    visited[{start_hh, start_mm}] <= 1'b1;
                    parent[{start_hh, start_mm}] <= 11'h7FF;  // Invalid parent
                    
                    // Push start to queue
                    queue[0] <= {start_hh, start_mm};
                    queue_tail <= 6'd1;
                    queue_size <= 6'd1;
                    
                    cycle_count <= 10'd0;
                    state <= EXPAND;
                end
                
                EXPAND: begin
                    cycle_count <= cycle_count + 10'd1;
                    
                    if (queue_size == 6'd0 || cycle_count >= MAX_CYCLES) begin
                        // No more nodes or timeout - treat as failure
                        // (Should not happen for valid inputs)
                        state <= FINISH;
                    end else begin
                        // Dequeue current node
                        current_idx <= queue[queue_head];
                        queue_head <= queue_head + 6'd1;
                        queue_size <= queue_size - 6'd1;
                        
                        // Check if we found target
                        if (queue[queue_head] == target_idx) begin
                            state <= RECONSTRUCT;
                        end else begin
                            state <= CHECK_FOUND;
                        end
                    end
                end
                
                CHECK_FOUND: begin
                    // Extract digits from current_idx
                    h1 <= current_idx[10:7];  // Tens of hours (0-2)
                    h0 <= current_idx[6:4];   // Units of hours (0-9)
                    m1 <= current_idx[3:2];   // Tens of minutes (0-5)
                    m0 <= current_idx[1:0];   // Units of minutes (0-9)
                    digit_pos <= 4'd0;  // Start with first digit
                    digit_op <= 2'd0;   // Start with decrement
                    state <= EXPAND;
                end
                
                OUTPUT: begin
                    output_idx <= output_idx + 4'd1;
                    if (output_idx >= result_len - 4'd1) begin
                        state <= FINISH;
                    end else begin
                        state <= OUTPUT;
                    end
                end
                
                RECONSTRUCT: begin
                    // Build path backwards from target to start
                    // Initialize with target
                    if (stack_ptr == 4'd0) begin
                        path_stack[0] <= target_idx;
                        stack_ptr <= 4'd1;
                        reconstruct_idx <= parent[target_idx];
                    end else if (reconstruct_idx != 11'h7FF && stack_ptr < 4'd16) begin
                        path_stack[stack_ptr] <= reconstruct_idx;
                        stack_ptr <= stack_ptr + 4'd1;
                        reconstruct_idx <= parent[reconstruct_idx];
                    end else begin
                        // Path built, prepare to output
                        result_len <= stack_ptr;
                        output_idx <= stack_ptr - 4'd1;
                        stack_ptr <= 4'd0;
                        state <= OUTPUT;
                    end
                end
                
                FINISH: begin
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end

    // Neighbor generation logic (combinational)
    always @(*) begin
        neighbor_val = 11'd0;
        valid_neighbor = 1'b0;
        
        // Decode current_idx
        h1 = current_idx[10:7];
        h0 = current_idx[6:4];
        m1 = current_idx[3:2];
        m0 = current_idx[1:0];
        
        case (digit_pos)
            4'd0: begin  // h1 (0-2)
                if (digit_op == 2'd0) begin  // Decrement
                    if (h1 > 4'd0) temp_val = h1 - 4'd1;
                    else temp_val = 4'd2;  // Wrap to 2
                end else begin  // Increment
                    if (h1 < 4'd2) temp_val = h1 + 4'd1;
                    else temp_val = 4'd0;  // Wrap to 0
                end
                // Update h1
                neighbor_val = {temp_val[3:0], h0, m1, m0};
                // Check validity: hour must be < 24
                if ({temp_val[3:0], h0} < 5'd24) valid_neighbor = 1'b1;
            end
            
            4'd1: begin  // h0 (0-9)
                if (digit_op == 2'd0) begin
                    if (h0 > 4'd0) temp_val = h0 - 4'd1;
                    else temp_val = 4'd9;  // Wrap to 9
                end else begin
                    if (h0 < 4'd9) temp_val = h0 + 4'd1;
                    else temp_val = 4'd0;  // Wrap to 0
                end
                neighbor_val = {h1, temp_val[3:0], m1, m0};
                // Check validity: hour must be < 24
                if ({h1, temp_val[3:0]} < 5'd24) valid_neighbor = 1'b1;
            end
            
            4'd2: begin  // m1 (0-5)
                if (digit_op == 2'd0) begin
                    if (m1 > 2'd0) temp_val = m1 - 2'd1;
                    else temp_val = 2'd5;  // Wrap to 5
                end else begin
                    if (m1 < 2'd5) temp_val = m1 + 2'd1;
                    else temp_val = 2'd0;  // Wrap to 0
                end
                neighbor_val = {h1, h0, temp_val[1:0], m0};
                // Check validity: minute must be < 60
                if ({temp_val[1:0], m0} < 6'd60) valid_neighbor = 1'b1;
            end
            
            4'd3: begin  // m0 (0-9)
                if (digit_op == 2'd0) begin
                    if (m0 > 4'd0) temp_val = m0 - 4'd1;
                    else temp_val = 4'd9;  // Wrap to 9
                end else begin
                    if (m0 < 4'd9) temp_val = m0 + 4'd1;
                    else temp_val = 4'd0;  // Wrap to 0
                end
                neighbor_val = {h1, h0, m1, temp_val[3:0]};
                // Check validity: minute must be < 60
                if ({m1, temp_val[3:0]} < 6'd60) valid_neighbor = 1'b1;
            end
        endcase
    end

    // Generate next neighbor during EXPAND state
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            digit_pos <= 4'd0;
            digit_op <= 2'd0;
        end else if (state == EXPAND && queue_size > 6'd0 && cycle_count < MAX_CYCLES) begin
            // Try next digit/operation combination
            if (digit_op == 2'd1 && digit_pos < 4'd3) begin
                // Next digit
                digit_pos <= digit_pos + 4'd1;
                digit_op <= 2'd0;
            end else if (digit_op == 2'd0) begin
                // Try increment for same digit
                digit_op <= 2'd1;
            end else begin
                // Both ops tried for all digits, move to next queue entry
                digit_pos <= 4'd0;
                digit_op <= 2'd0;
            end
        end
    end

    // Check and enqueue valid neighbors
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset handled elsewhere
        end else if (state == EXPAND && queue_size > 6'd0 && valid_neighbor) begin
            // Check if neighbor is unvisited
            if (!visited[neighbor_val]) begin
                // Mark visited
                visited[neighbor_val] <= 1'b1;
                parent[neighbor_val] <= current_idx;
                
                // Enqueue if not full
                if (queue_size < 64) begin
                    queue[queue_tail] <= neighbor_val;
                    queue_tail <= queue_tail + 6'd1;
                    queue_size <= queue_size + 6'd1;
                end
            end
        end
    end

    // Path reconstruction from stack
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            output_idx <= 4'd0;
            packed_time <= 11'd0;
        end else if (state == OUTPUT) begin
            // Unpack from stack (reversed order)
            packed_time <= path_stack[output_idx];
        end
    end

endmodule