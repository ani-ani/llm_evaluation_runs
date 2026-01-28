module ExplodingWorms(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire signed [15:0] cans_x [0:15],
    input wire [15:0] cans_r [0:15],
    output reg [3:0] results [0:15],
    output reg done
);

    // State declarations
    localparam [3:0] IDLE = 4'd0;
    localparam [3:0] SORT = 4'd1;
    localparam [3:0] CALC_START = 4'd2;
    localparam [3:0] CALC_BFS_LOOP = 4'd3;
    localparam [3:0] CALC_CHECK = 4'd4;
    localparam [3:0] CALC_COUNT = 4'd5;
    localparam [3:0] OUTPUT = 4'd6;
    localparam [3:0] DONE_STATE = 4'd7;

    reg [3:0] state, next_state;

    // Internal registers for sorted data
    reg signed [15:0] sorted_x [0:15];
    reg [15:0] sorted_r [0:15];

    // BFS registers
    reg [15:0] visited_mask;
    reg [15:0] current_cans;
    reg [3:0] queue_head;
    reg [3:0] queue_tail;
    reg [3:0] queue_count;
    reg [15:0] queue_buffer [0:15];

    // Calculation loop registers
    reg [3:0] current_target;
    reg [3:0] explosion_count;

    // Sorting registers
    reg [3:0] sort_pass;
    reg [3:0] sort_i;

    // Cycle counter for safety
    reg [10:0] cycle_count;
    localparam [10:0] MAX_CYCLES = 11'd1900;

    // FSM state transitions
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            cycle_count <= 11'd0;
            
            // Initialize all registers
            for (integer i = 0; i < 16; i = i + 1) begin
                results[i] <= 4'd0;
                sorted_x[i] <= 16'd0;
                sorted_r[i] <= 16'd0;
                queue_buffer[i] <= 16'd0;
            end
            
            visited_mask <= 16'd0;
            current_cans <= 16'd0;
            queue_head <= 4'd0;
            queue_tail <= 4'd0;
            queue_count <= 4'd0;
            current_target <= 4'd0;
            explosion_count <= 4'd0;
            sort_pass <= 4'd0;
            sort_i <= 4'd0;
        end else begin
            state <= next_state;
            cycle_count <= cycle_count + 11'd1;
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = SORT;
                end
            end
            
            SORT: begin
                if (sort_pass == 4'd15 && sort_i == 4'd15) begin
                    next_state = CALC_START;
                end
            end
            
            CALC_START: begin
                next_state = CALC_BFS_LOOP;
            end
            
            CALC_BFS_LOOP: begin
                if (queue_count == 4'd0) begin
                    next_state = CALC_COUNT;
                end
            end
            
            CALC_COUNT: begin
                next_state = OUTPUT;
            end
            
            OUTPUT: begin
                if (current_target == 4'd15) begin
                    next_state = DONE_STATE;
                end else begin
                    next_state = CALC_START;
                end
            end
            
            DONE_STATE: begin
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
        
        // Safety: timeout after MAX_CYCLES
        if (cycle_count >= MAX_CYCLES) begin
            next_state = IDLE;
        end
    end

    // Sorting logic (bubble sort)
    always @(posedge clk) begin
        if (state == SORT) begin
            if (sort_pass < 4'd15) begin
                if (sort_i < 4'd15) begin
                    // Compare and swap
                    if (sorted_x[sort_i] > sorted_x[sort_i + 4'd1]) begin
                        // Swap x
                        reg signed [15:0] temp_x;
                        temp_x = sorted_x[sort_i];
                        sorted_x[sort_i] = sorted_x[sort_i + 4'd1];
                        sorted_x[sort_i + 4'd1] = temp_x;
                        
                        // Swap r
                        reg [15:0] temp_r;
                        temp_r = sorted_r[sort_i];
                        sorted_r[sort_i] = sorted_r[sort_i + 4'd1];
                        sorted_r[sort_i + 4'd1] = temp_r;
                    end
                    sort_i <= sort_i + 4'd1;
                end else begin
                    sort_i <= 4'd0;
                    sort_pass <= sort_pass + 4'd1;
                end
            end else begin
                // Sorting complete
                sort_pass <= 4'd0;
                sort_i <= 4'd0;
            end
        end
    end

    // BFS initialization
    always @(posedge clk) begin
        if (state == CALC_START) begin
            // Initialize for new target
            visited_mask <= 16'd0;
            current_cans <= 16'd0;
            queue_head <= 4'd0;
            queue_tail <= 4'd0;
            queue_count <= 4'd0;
            
            // Add current target to queue
            queue_buffer[queue_tail] <= current_target;
            queue_tail <= (queue_tail + 4'd1) % 4'd16;
            queue_count <= queue_count + 4'd1;
            
            // Mark current target as visited
            visited_mask <= visited_mask | (16'd1 << current_target);
            
            // Set current_cans to process this target
            current_cans <= 16'd1 << current_target;
        end
    end

    // BFS processing
    always @(posedge clk) begin
        if (state == CALC_BFS_LOOP && queue_count > 4'd0) begin
            // Process one can from queue
            reg [3:0] current_index;
            current_index = queue_head;
            
            // Remove from queue
            queue_head <= (queue_head + 4'd1) % 4'd16;
            queue_count <= queue_count - 4'd1;
            
            // Get current can position and radius
            reg signed [15:0] current_x;
            reg [15:0] current_r;
            current_x = sorted_x[current_index];
            current_r = sorted_r[current_index];
            
            // Check all other cans
            for (integer k = 0; k < 16; k = k + 1) begin
                if ((visited_mask & (16'd1 << k)) == 16'd0) begin
                    // Not visited yet
                    reg signed [15:0] distance;
                    distance = current_x - sorted_x[k];
                    
                    // Absolute value
                    reg signed [16:0] abs_distance;
                    abs_distance = (distance < 16'd0) ? -distance : distance;
                    
                    // Check if within radius
                    if (abs_distance <= current_r) begin
                        // Add to queue
                        queue_buffer[queue_tail] <= k;
                        queue_tail <= (queue_tail + 4'd1) % 4'd16;
                        queue_count <= queue_count + 4'd1;
                        
                        // Mark as visited
                        visited_mask <= visited_mask | (16'd1 << k);
                    end
                end
            end
        end
    end

    // Count visited cans
    always @(posedge clk) begin
        if (state == CALC_COUNT) begin
            // Population count using iterative approach
            reg [15:0] temp_mask;
            reg [3:0] count;
            
            temp_mask = visited_mask;
            count = 4'd0;
            
            for (integer i = 0; i < 16; i = i + 1) begin
                if (temp_mask[i]) begin
                    count = count + 4'd1;
                end
            end
            
            explosion_count <= count;
        end
    end

    // Store results
    always @(posedge clk) begin
        if (state == OUTPUT) begin
            results[current_target] <= explosion_count;
            
            // Move to next target
            if (current_target < 4'd15) begin
                current_target <= current_target + 4'd1;
            end else begin
                current_target <= 4'd0;
            end
        end
    end

    // Done signal
    always @(posedge clk) begin
        if (state == DONE_STATE) begin
            done <= 1'b1;
        end else begin
            done <= 1'b0;
        end
    end

    // Initialize sorted arrays on start
    always @(posedge clk) begin
        if (state == SORT && sort_pass == 4'd0 && sort_i == 4'd0) begin
            // Copy input to sorted arrays
            for (integer i = 0; i < 16; i = i + 1) begin
                sorted_x[i] <= cans_x[i];
                sorted_r[i] <= cans_r[i];
            end
        end
    end

endmodule