module arrange_solver (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] perm_in [3:0], // Input permutation (values 1-4)
    input wire [3:0] swap_a,        // Swap index 1
    input wire [3:0] swap_b,        // Swap index 2
    output reg [3:0] min_swaps,
    output reg done,
    output reg valid
);

    // State Encoding
    localparam S_IDLE      = 4'd0;
    localparam S_INIT      = 4'd1;
    localparam S_CHECK     = 4'd2;
    localparam S_SWAP      = 4'd3;
    localparam S_RANK      = 4'd4;
    localparam S_VISIT     = 4'd5;
    localparam S_ENQUEUE   = 4'd6;
    localparam S_UPDATE    = 4'd7;
    localparam S_DEQUEUE   = 4'd8;
    localparam S_CLR_Q     = 4'd9;
    localparam S_DONE      = 4'd10;
    localparam S_FAIL      = 4'd11;

    reg [3:0] state, next_state;

    // Queue Parameters (Max 24 states)
    localparam Q_DEPTH = 24;
    localparam Q_BITS = 5; // 2^5 = 32 > 24

    // Registers
    reg [3:0] current_perm [3:0];     // Current permutation being processed
    reg [3:0] current_dist;           // Distance (swap count) of current_perm
    reg [3:0] temp_perm [3:0];        // Temporary storage for swap result
    reg [3:0] swap_op_a, swap_op_b;   // Registered swap indices
    
    // Visited Array (24 bits)
    reg visited [23:0];
    reg [4:0] visited_idx;            // Index for clearing visited

    // BFS Queue Arrays
    reg [3:0] queue_perm [Q_DEPTH-1:0][3:0]; // Queue storage
    reg [3:0] queue_dist [Q_DEPTH-1:0];      // Distance storage
    reg [Q_BITS-1:0] head;                   // Read pointer
    reg [Q_BITS-1:0] tail;                   // Write pointer
    reg [Q_BITS-1:0] new_tail;               // Next write pointer
    reg [Q_BITS-1:0] temp_idx;               // General purpose index
    reg [Q_BITS-1:0] copy_cnt;               // Counter for copying/initialization

    // Rank Calculation Variables
    // Factorial lookup: 3! = 6, 2! = 2, 1! = 1
    reg [3:0] rank_val;                     // Accumulated rank
    reg [3:0] factor [3:0];                 // Factors: 6, 2, 1, 1
    reg [1:0] smaller_cnt;                  // Count of smaller unused numbers
    reg [3:0] f_perm [3:0];                 // Perm copy for rank calc
    reg [3:0] chk_val;                      // Value being checked for 'smaller'
    integer k, m;                           // Loop variables

    // Combinational Logic for Rank Calculation
    // Calculates index (0-23) for a 4-element permutation
    // P = [p0, p1, p2, p3]
    // Rank = sum_{i=0}^{3} (count(P[i] < P[j] for j>i) * (3-i)!)
    always @(*) begin
        // Factorial constants: 3! = 6, 2! = 2, 1! = 1
        factor[0] = 4'd6; // 3!
        factor[1] = 4'd2; // 2!
        factor[2] = 4'd1; // 1!
        factor[3] = 4'd0; // 0!

        rank_val = 4'd0;
        for (k = 0; k < 3; k = k + 1) begin
            smaller_cnt = 0;
            chk_val = current_perm[k];
            for (m = k + 1; m < 4; m = m + 1) begin
                if (current_perm[m] < chk_val) begin
                    smaller_cnt = smaller_cnt + 1;
                end
            end
            rank_val = rank_val + (smaller_cnt * factor[k]);
        end
    end

    // Sequential Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_IDLE;
            done <= 0;
            valid <= 0;
            min_swaps <= 4'hF;
            head <= 0;
            tail <= 0;
            // Reset visited in S_IDLE to avoid combinational loops in reset
        end else begin
            case (state)
                S_IDLE: begin
                    done <= 0;
                    valid <= 0;
                    if (start) begin
                        // Register inputs
                        current_perm[0] <= perm_in[0];
                        current_perm[1] <= perm_in[1];
                        current_perm[2] <= perm_in[2];
                        current_perm[3] <= perm_in[3];
                        swap_op_a <= swap_a;
                        swap_op_b <= swap_b;
                        current_dist <= 0;
                        visited_idx <= 0;
                        state <= S_CLR_Q;
                    end
                end

                // Clear Queue and Visited Array
                S_CLR_Q: begin
                    if (visited_idx < 24) begin
                        visited[visited_idx] <= 0;
                        visited_idx <= visited_idx + 1;
                    end else if (copy_cnt < Q_DEPTH) begin
                        // Clear queue dist to avoid garbage
                        queue_dist[copy_cnt] <= 4'hF;
                        copy_cnt <= copy_cnt + 1;
                    end else begin
                        copy_cnt <= 0;
                        state <= S_INIT;
                    end
                end

                // Initialize BFS: Check start, enqueue
                S_INIT: begin
                    // Check if already sorted (1,2,3,4)
                    if (current_perm[0]==1 && current_perm[1]==2 && current_perm[2]==3 && current_perm[3]==4) begin
                        min_swaps <= 0;
                        done <= 1;
                        valid <= 1;
                        state <= S_DONE;
                    end else begin
                        state <= S_RANK;
                        current_dist <= 0;
                    end
                end

                // Calculate Rank and Mark Visited
                S_RANK: begin
                    // Use comb logic output
                    temp_idx <= rank_val;
                    if (!visited[rank_val]) begin
                        visited[rank_val] <= 1; // Mark visited
                        // If dist is 0 (start node), enqueue directly
                        if (current_dist == 0) state <= S_ENQUEUE;
                        else state <= S_UPDATE; // For new neighbors
                    end else begin
                        // Already visited, skip
                        state <= S_UPDATE;
                    end
                end

                // Enqueue current_perm
                S_ENQUEUE: begin
                    if (tail < Q_DEPTH) begin
                        // Deep copy permutation to queue
                        queue_perm[tail][0] <= current_perm[0];
                        queue_perm[tail][1] <= current_perm[1];
                        queue_perm[tail][2] <= current_perm[2];
                        queue_perm[tail][3] <= current_perm[3];
                        queue_dist[tail] <= current_dist;
                        tail <= tail + 1;
                        state <= S_UPDATE;
                    end else begin
                        // Should not happen if logic is correct
                        state <= S_FAIL;
                    end
                end

                // Update Loop: Check if we need to process more swaps or dequeue next
                S_UPDATE: begin
                    // If we just processed the start node (dist 0), go to dequeue
                    if (current_dist == 0) begin
                        state <= S_DEQUEUE;
                    end else begin
                        // We were processing neighbors (S_CHECK/S_SWAP from previous cycle)
                        // Check if we have more swaps to try (only 1 pair provided, so just done)
                        // Since only 1 swap pair is allowed per inputs, we are done with neighbors
                        state <= S_DEQUEUE;
                    end
                end

                // Dequeue
                S_DEQUEUE: begin
                    if (head < tail) begin
                        // Load new state
                        current_perm[0] <= queue_perm[head][0];
                        current_perm[1] <= queue_perm[head][1];
                        current_perm[2] <= queue_perm[head][2];
                        current_perm[3] <= queue_perm[head][3];
                        current_dist <= queue_dist[head] + 1; // Increment depth
                        head <= head + 1;
                        state <= S_CHECK;
                    end else begin
                        // Queue empty: Failure
                        min_swaps <= 4'hF; // Indicate max value (15)
                        done <= 1;
                        valid <= 0;
                        state <= S_FAIL;
                    end
                end

                // Check if dequeued state is Goal
                S_CHECK: begin
                    if (current_perm[0]==1 && current_perm[1]==2 && current_perm[2]==3 && current_perm[3]==4) begin
                        min_swaps <= current_dist;
                        done <= 1;
                        valid <= 1;
                        state <= S_DONE;
                    end else begin
                        // Generate Neighbors: Apply Swap
                        // Apply swap to temp_perm
                        temp_perm[0] <= current_perm[0];
                        temp_perm[1] <= current_perm[1];
                        temp_perm[2] <= current_perm[2];
                        temp_perm[3] <= current_perm[3];
                        state <= S_SWAP;
                    end
                end

                // Perform Swap
                S_SWAP: begin
                    // Apply swap_op_a and swap_op_b to temp_perm
                    // Use intermediate update to avoid needing to read from temp_perm in same cycle
                    if (swap_op_a < 4 && swap_op_b < 4 && swap_op_a != swap_op_b) begin
                        if (swap_op_a == 0) temp_perm[0] <= current_perm[swap_op_b];
                        else if (swap_op_a == 1) temp_perm[1] <= current_perm[swap_op_b];
                        else if (swap_op_a == 2) temp_perm[2] <= current_perm[swap_op_b];
                        else if (swap_op_a == 3) temp_perm[3] <= current_perm[swap_op_b];

                        if (swap_op_b == 0) temp_perm[0] <= current_perm[swap_op_a];
                        else if (swap_op_b == 1) temp_perm[1] <= current_perm[swap_op_a];
                        else if (swap_op_b == 2) temp_perm[2] <= current_perm[swap_op_a];
                        else if (swap_op_b == 3) temp_perm[3] <= current_perm[swap_op_a];
                    end
                    state <= S_RANK;
                    // Load temp_perm into current_perm for Rank Calc
                    current_perm <= temp_perm; // Note: This creates a latch-like behavior if not careful, 
                                               // but in seq logic it updates next cycle. 
                                               // We need Rank to use the SWAPPED values.
                    // Correction: In S_SWAP, we modify temp_perm. 
                    // We need to move temp_perm to current_perm to be processed by S_RANK.
                    current_perm[0] <= (swap_op_a == 0) ? current_perm[swap_op_b] : (swap_op_b == 0) ? current_perm[swap_op_a] : current_perm[0];
                    current_perm[1] <= (swap_op_a == 1) ? current_perm[swap_op_b] : (swap_op_b == 1) ? current_perm[swap_op_a] : current_perm[1];
                    current_perm[2] <= (swap_op_a == 2) ? current_perm[swap_op_b] : (swap_op_b == 2) ? current_perm[swap_op_a] : current_perm[2];
                    current_perm[3] <= (swap_op_a == 3) ? current_perm[swap_op_b] : (swap_op_b == 3) ? current_perm[swap_op_a] : current_perm[3];
                    // The 'temp_perm' register above was redundant, we update current_perm directly.
                end

                S_DONE: begin
                    // Hold state
                    if (!start) state <= S_IDLE;
                end
                
                S_FAIL: begin
                    // Hold state
                    if (!start) state <= S_IDLE;
                end
            endcase
        end
    end

endmodule