module OptimalCacheMissCalculator(
    input clk,
    input rst_n,
    input start,
    input [3:0] cache_size,
    input [4:0] num_objects,
    input [4:0] num_accesses,
    input [4:0] access_seq [0:15],
    output reg [4:0] result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE    = 2'd0;
    localparam [1:0] LOAD    = 2'd1;
    localparam [1:0] COMPUTE = 2'd2;
    localparam [1:0] DONE_STATE = 2'd3;

    reg [1:0] state, next_state;

    // Cache representation (4 entries, 5-bit object IDs)
    reg [4:0] cache [0:3];

    // Tracking variables
    reg [4:0] miss_count;
    reg [4:0] current_access_idx;
    reg [4:0] next_use_pos [0:15];  // For each object, next use position
    reg [4:0] farthest_pos;
    reg [4:0] evict_idx;
    reg [4:0] current_obj;
    reg [4:0] i, j, k;
    reg [4:0] temp_pos;
    reg [4:0] max_future_pos;
    reg cache_hit;
    reg [4:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd1000;

    // Initialize all registers
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            result <= 5'd0;
            done <= 1'b0;
            miss_count <= 5'd0;
            current_access_idx <= 5'd0;
            cycle_count <= 8'd0;

            // Initialize cache
            for (i = 0; i < 4; i = i + 1) begin
                cache[i] <= 5'd0;
            end

            // Initialize next_use_pos array
            for (i = 0; i < 16; i = i + 1) begin
                next_use_pos[i] <= 5'd0;
            end

            farthest_pos <= 5'd0;
            evict_idx <= 5'd0;
            current_obj <= 5'd0;
            temp_pos <= 5'd0;
            max_future_pos <= 5'd0;
            cache_hit <= 1'b0;
        end else begin
            state <= next_state;
        end
    end

    // State machine logic
    always @(posedge clk) begin
        if (rst_n) begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        next_state <= LOAD;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                LOAD: begin
                    // Precompute next use positions for all objects
                    // Initialize next_use_pos to 31 (beyond last access)
                    for (i = 0; i < 16; i = i + 1) begin
                        next_use_pos[i] <= 5'd31;
                    end

                    // For each access position, update next use for that object
                    for (i = 0; i < num_accesses; i = i + 1) begin
                        current_obj <= access_seq[i];
                        // Find next occurrence of current_obj after position i
                        temp_pos <= 5'd31;
                        for (j = i + 1; j < num_accesses; j = j + 1) begin
                            if (access_seq[j] == current_obj) begin
                                temp_pos <= j;
                                j <= num_accesses;  // Break equivalent
                            end
                        end
                        next_use_pos[current_obj] <= temp_pos;
                    end

                    // Initialize cache to invalid state
                    for (i = 0; i < 4; i = i + 1) begin
                        cache[i] <= 5'd31;  // Invalid marker
                    end

                    miss_count <= 5'd0;
                    current_access_idx <= 5'd0;
                    next_state <= COMPUTE;
                end

                COMPUTE: begin
                    cycle_count <= cycle_count + 8'd1;

                    // Process current access
                    current_obj <= access_seq[current_access_idx];

                    // Check if object is in cache
                    cache_hit <= 1'b0;
                    for (i = 0; i < cache_size; i = i + 1) begin
                        if (cache[i] == current_obj) begin
                            cache_hit <= 1'b1;
                            i <= cache_size;  // Break equivalent
                        end
                    end

                    if (!cache_hit) begin
                        // Cache miss - increment counter
                        miss_count <= miss_count + 5'd1;

                        // Find which cache entry to evict
                        // If cache not full, find first empty slot
                        evict_idx <= 5'd0;
                        for (i = 0; i < cache_size; i = i + 1) begin
                            if (cache[i] == 5'd31) begin
                                evict_idx <= i;
                                i <= cache_size;  // Break equivalent
                            end
                        end

                        // If cache is full, find object with farthest next use
                        if (cache[evict_idx] != 5'd31) begin
                            farthest_pos <= 5'd0;
                            max_future_pos <= 5'd0;
                            evict_idx <= 5'd0;

                            for (i = 0; i < cache_size; i = i + 1) begin
                                temp_pos <= next_use_pos[cache[i]];
                                if (temp_pos > max_future_pos) begin
                                    max_future_pos <= temp_pos;
                                    evict_idx <= i;
                                end
                            end
                        end

                        // Replace the evicted entry with current object
                        cache[evict_idx] <= current_obj;
                    end

                    // Move to next access
                    if (current_access_idx == num_accesses - 1) begin
                        next_state <= DONE_STATE;
                    end else begin
                        current_access_idx <= current_access_idx + 5'd1;
                        next_state <= COMPUTE;
                    end
                end

                DONE_STATE: begin
                    result <= miss_count;
                    done <= 1'b1;
                    next_state <= IDLE;
                end

                default: next_state <= IDLE;
            endcase
        end
    end
endmodule