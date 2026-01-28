module MixCokes(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [10:0] target_n,
    input wire [2047:0] diff_avail,
    output reg [11:0] result,
    output reg done,
    output reg valid
);

    // State definitions for BFS controller
    localparam [1:0] IDLE      = 2'd0;
    localparam [1:0] POP       = 2'd1;
    localparam [1:0] EXPAND    = 2'd2;
    localparam [1:0] FINISHED  = 2'd3;

    // Constants
    localparam [10:0] OFFSET   = 11'd1000;
    localparam [10:0] MIN_STATE = -11'd1000;
    localparam [10:0] MAX_STATE = 11'd1000;
    localparam [11:0] MAX_DIST  = 12'd1024;
    localparam [4:0]  MAX_DIFFS = 5'd20; // Max unique diffs to check per cycle

    // Registers
    reg [1:0] state;
    reg [1:0] next_state;
    
    // BFS Queue: 256 entries, each (state:11b, dist:12b) = 23 bits
    // Using packed array for synthesis compatibility
    reg [22:0] queue [0:255];
    reg [7:0] queue_head; // Read pointer
    reg [7:0] queue_tail; // Write pointer
    reg [7:0] queue_count;
    
    // Visited states (2048 bits for -1000 to 1000)
    reg [2047:0] visited;
    
    // Current processing registers
    reg [10:0] current_state;
    reg [11:0] current_dist;
    reg [4:0] diff_index; // Counter for iterating through diff_avail bits
    
    // Result tracking
    reg found;
    reg [11:0] result_reg;
    
    // Combinational signals
    wire [10:0] current_state_idx;
    wire [10:0] diff_value;
    wire [10:0] next_state_sum;
    wire [10:0] next_state_idx;
    wire [10:0] diff_avail_idx;
    wire diff_avail_bit;
    wire next_state_in_range;
    wire next_state_visited;
    wire queue_empty;
    wire queue_full;
    
    // Index calculation: state + OFFSET
    assign current_state_idx = current_state + OFFSET;
    
    // Get diff value from current index (signed)
    // diff_index 0 = -1000, 1 = -999, ..., 1000 = 0, ..., 2000 = 1000
    assign diff_value = ($signed(diff_index) - 10'd1000);
    
    // Check if diff is available
    assign diff_avail_idx = diff_index;
    assign diff_avail_bit = diff_avail[diff_avail_idx];
    
    // Calculate next state
    assign next_state_sum = current_state + diff_value;
    assign next_state_in_range = (next_state_sum >= MIN_STATE) && (next_state_sum <= MAX_STATE);
    assign next_state_idx = next_state_sum + OFFSET;
    assign next_state_visited = visited[next_state_idx];
    
    // Queue status
    assign queue_empty = (queue_count == 8'd0);
    assign queue_full = (queue_count == 8'd255);

    // State transition logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end

    // Main BFS logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all registers
            queue_head <= 8'd0;
            queue_tail <= 8'd0;
            queue_count <= 8'd0;
            visited <= 2048'd0;
            current_state <= 11'd0;
            current_dist <= 12'd0;
            diff_index <= 5'd0;
            found <= 1'b0;
            result_reg <= 12'd0;
            result <= 12'd0;
            done <= 1'b0;
            valid <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    valid <= 1'b0;
                    found <= 1'b0;
                    diff_index <= 5'd0;
                    
                    if (start) begin
                        // Initialize BFS from state 0
                        visited <= 2048'd0;
                        visited[OFFSET] <= 1'b1; // Mark state 0 as visited
                        queue_head <= 8'd0;
                        queue_tail <= 8'd0;
                        queue_count <= 8'd0;
                        // Push initial state (0, 0) to queue
                        queue[0] <= {11'd0, 12'd0};
                        queue_tail <= 8'd1;
                        queue_count <= 8'd1;
                    end
                end
                
                POP: begin
                    if (!queue_empty) begin
                        // Pop from queue
                        {current_state, current_dist} <= queue[queue_head];
                        queue_head <= queue_head + 8'd1;
                        queue_count <= queue_count - 8'd1;
                    end
                end
                
                EXPAND: begin
                    // Check if we found target (state 0, but not start)
                    if (current_state == 11'd0 && current_dist > 12'd0) begin
                        found <= 1'b1;
                        result_reg <= current_dist;
                    end else if (current_dist < MAX_DIST) begin
                        // Try to expand to next states
                        if (diff_index < MAX_DIFFS) begin
                            // Check if this diff is available
                            if (diff_avail_bit) begin
                                // Check if next state is valid and unvisited
                                if (next_state_in_range && !next_state_visited) begin
                                    // Mark visited
                                    visited[next_state_idx] <= 1'b1;
                                    
                                    // Push to queue
                                    if (!queue_full) begin
                                        queue[queue_tail] <= {next_state_sum, current_dist + 12'd1};
                                        queue_tail <= queue_tail + 8'd1;
                                        queue_count <= queue_count + 8'd1;
                                    end
                                end
                            end
                            diff_index <= diff_index + 5'd1;
                        end else begin
                            // Done checking all diffs for this state
                            diff_index <= 5'd0;
                        end
                    end
                end
                
                FINISHED: begin
                    if (found) begin
                        result <= result_reg;
                        valid <= 1'b1;
                    end else begin
                        result <= 12'd0;
                        valid <= 1'b0;
                    end
                    done <= 1'b1;
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

    // Next state logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start && !queue_empty) begin
                    next_state = POP;
                end else if (start) begin
                    next_state = POP; // Will immediately fail queue_empty check
                end else begin
                    next_state = IDLE;
                end
            end
            
            POP: begin
                if (queue_empty) begin
                    next_state = FINISHED;
                end else begin
                    next_state = EXPAND;
                end
            end
            
            EXPAND: begin
                // Check termination conditions
                if (found) begin
                    next_state = FINISHED;
                end else if (current_dist >= MAX_DIST) begin
                    next_state = POP; // Try next in queue
                end else if (diff_index >= MAX_DIFFS) begin
                    next_state = POP; // Next state in queue
                end else begin
                    next_state = EXPAND; // Continue checking diffs
                end
            end
            
            FINISHED: begin
                // Stay finished until next start
                if (start) begin
                    next_state = IDLE;
                end else begin
                    next_state = FINISHED;
                end
            end
            
            default: begin
                next_state = IDLE;
            end
        endcase
    end

endmodule