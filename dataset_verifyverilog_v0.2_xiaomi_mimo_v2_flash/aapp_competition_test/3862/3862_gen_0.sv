module coke_mix(
    input clk,
    input rst_n,
    input start,
    input [9:0] n,
    input [3:0] k,
    input [15:0] types_data,
    output reg [9:0] result,
    output reg done
);

    // Parameters
    parameter OFFSET = 10'd1000;
    parameter MAX_NODES = 11'd2001; // -1000 to 1000
    parameter MAX_DIST = 10'd1023;

    // State encoding
    localparam IDLE = 3'b000;
    localparam INIT = 3'b001;
    localparam PROCESSING = 3'b010;
    localparam CALCULATE = 3'b011;
    localparam DONE_S = 3'b100;

    // Registers
    reg [2:0] state;
    reg [2:0] next_state;
    reg [9:0] dist_addr;
    reg dist_wr;
    reg [9:0] dist_wr_data;
    wire [9:0] dist_rd_data;
    reg [9:0] visited_addr;
    reg visited_wr;
    reg visited_wr_data;
    wire visited_rd_data;
    reg [10:0] i; // Generic counter
    reg [3:0] type_idx;
    reg [9:0] current_pos;
    reg [9:0] new_pos;
    reg [9:0] diff_val;
    reg [9:0] temp_sum;
    reg [3:0] q_head;
    reg [3:0] q_tail;
    reg [9:0] queue [0:15];
    reg queue_wr;
    reg queue_rd;
    reg [9:0] types [0:3]; // Unpacked types
    reg [9:0] diff_types [0:3]; // Differences
    reg [4:0] scan_count; // Counter for scanning neighbors
    reg target_reached;
    
    // Dual-port RAM for distance (1024x10) and visited (1024x1)
    // We need 2048 entries, so we use two instances or logic
    // To save resources, we use behavioral description and let synthesis infer RAM
    // However, for simplicity and explicit control, we will use registers/luts
    // since 2048*10 bits is small enough for LUTs or distributed RAM.
    
    reg [9:0] dist_ram [0:2047];
    reg visited_ram [0:2047];

    // LFSR for random selection (optional, but if queue is full, we might need to drop)
    // But requirement says queue size 16. 
    // To handle BFS correctly with a small queue, we must process faster or use a different structure.
    // The spec says "Queue size 16 (max depth)". This implies BFS level by level might be limited.
    // We will implement a standard queue with head/tail pointers.

    integer j;

    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result <= 10'd0;
            q_head <= 4'b0;
            q_tail <= 4'b0;
            // Initialize RAM (optional, handled in INIT state usually)
        end else begin
            state <= next_state;
            
            // State transitions and operations
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        // Prepare data
                        // Unpack types_data
                        types[0] <= {6'b0, types_data[3:0]};
                        types[1] <= {6'b0, types_data[7:4]};
                        types[2] <= {6'b0, types_data[11:8]};
                        types[3] <= {6'b0, types_data[15:12]};
                        // Calculate differences relative to n
                        // diff = a_i - n. Range -1000 to 1000. Shifted by 1000.
                    end
                end
                INIT: begin
                    // Initialize RAM and Queue
                    if (i < 2048) begin
                        dist_ram[i] <= 10'h3FF; // Inf
                        visited_ram[i] <= 1'b0;
                        i <= i + 1'b1;
                    end else begin
                        i <= 11'd0;
                        // Set start node: sum=0 corresponds to offset 1000
                        // Actually, the logic is: 
                        // At start, we have 0 liters. Sum is 0. Relative sum is 0.
                        // Target is 0 relative sum.
                        // So we start at node 1000 (offset 0).
                        dist_ram[OFFSET] <= 10'd0;
                        visited_ram[OFFSET] <= 1'b1;
                        q_head <= 4'b0;
                        q_tail <= 4'b1;
                        queue[0] <= OFFSET;
                        
                        // Precompute diffs
                        for (j = 0; j < 4; j = j + 1) begin
                            if (j < k) 
                                // Check overflow/underflow for subtraction
                                // a_i (0-1000) - n (0-1000) -> -1000 to 1000
                                diff_types[j] <= types[j] - n;
                            else
                                diff_types[j] <= 10'd0;
                        end
                    end
                end
                PROCESSING: begin
                    // BFS Step
                    // We need to process the current node in queue head
                    // The queue holds absolute positions (offset + value)
                    if (q_head != q_tail) begin
                        // Dequeue
                        current_pos <= queue[q_head];
                        q_head <= q_head + 1'b1;
                        scan_count <= 5'd0; // Reset neighbor scan
                    end else begin
                        // Queue empty, go to done/calculate
                        // Actually, if queue empty and target not reached, impossible
                        if (!target_reached) begin
                            result <= MAX_DIST;
                            done <= 1'b1;
                            next_state <= IDLE;
                        end else begin
                            next_state <= CALCULATE;
                        end
                    end
                    
                    // Neighbor logic happens in next cycle to keep timing clean
                    // We will process neighbors in a loop-like state or combinational
                    // Since we want minimal latency, let's do sequential neighbor processing
                end
                CALCULATE: begin
                    // We have reached the target (sum = 0) at some point.
                    // We need to find the distance to target.
                    // But BFS guarantees shortest path.
                    // When we find a neighbor that is the target (OFFSET), we record distance.
                    // However, in BFS, we might have found it earlier.
                    // The problem asks to output minimal liters.
                    // So if we reached target, result is dist_ram[OFFSET].
                    if (dist_ram[OFFSET] != 10'h3FF) begin
                        result <= dist_ram[OFFSET];
                    end else begin
                        result <= MAX_DIST;
                    end
                    done <= 1'b1;
                    next_state <= IDLE;
                end
            endcase

            // Logic for PROCESSING state (Neighbor Expansion)
            // We execute this inside PROCESSING or split into sub-states.
            // To be efficient, we can do: 
            // While in PROCESSING, if scan_count < 4*k (or just 4 types), check neighbors.
            if (state == PROCESSING && q_head != q_tail && scan_count < 4) begin
                // Check type scan_count (assuming 4 types max)
                if (scan_count < k) begin
                    // Calculate new position
                    // current_pos is the absolute offset position (e.g. 1000)
                    // diff is relative. 
                    // new_pos = current_pos + diff_types[scan_count]
                    temp_sum = current_pos + diff_types[scan_count];
                    
                    // Check bounds (0 to 2000)
                    if (temp_sum >= 0 && temp_sum < 2048 && !visited_ram[temp_sum]) begin
                        // Valid neighbor
                        visited_ram[temp_sum] <= 1'b1;
                        dist_ram[temp_sum] <= dist_ram[current_pos] + 1'b1;
                        
                        // Check if target (OFFSET)
                        if (temp_sum == OFFSET) begin
                            target_reached <= 1'b1;
                        end
                        
                        // Enqueue
                        // Check if queue full
                        if ((q_tail + 1'b1) != q_head) begin
                            queue[q_tail] <= temp_sum;
                            q_tail <= q_tail + 1'b1;
                        end
                    end
                end
                scan_count <= scan_count + 1'b1;
            end else if (state == PROCESSING && scan_count >= k) begin
                // Finished neighbors for current node, loop back to extract next
                // The main PROCESSING block checks queue empty condition
            end
        end
    end

    // Combinational Next State Logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: if (start) next_state = INIT;
            INIT: if (i == 2048) next_state = PROCESSING;
            PROCESSING: begin
                if (q_head == q_tail && !target_reached) next_state = IDLE; // Impossible handled in sequential
                else if (scan_count >= k && q_head != q_tail) next_state = PROCESSING; // Wait for scan to finish current node
                else if (q_head == q_tail && target_reached) next_state = CALCULATE;
                else if (scan_count >= k && q_head == q_tail) next_state = CALCULATE; // Just finished last node
                else next_state = PROCESSING;
            end
            CALCULATE: next_state = IDLE;
            default: next_state = IDLE;
        endcase
        
        // Override for sequential flow control
        if (state == PROCESSING && q_head != q_tail && scan_count < k) next_state = PROCESSING; // Stay to process neighbors
        if (state == PROCESSING && q_head == q_tail) next_state = CALCULATE;
        // Fix: The scan logic must block state transition while scanning
        // If we are in PROCESSING, we need to stay there until we finish the current node's neighbors.
        // But the queue might get new items.
        // Simplest: Stay in PROCESSING as long as queue is not empty or we are scanning.
    end

endmodule
