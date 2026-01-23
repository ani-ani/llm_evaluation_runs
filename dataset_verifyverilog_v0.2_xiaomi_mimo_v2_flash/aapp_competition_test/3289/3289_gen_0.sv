module optimal_cluster(
    input clk,
    input rst_n,
    input start,
    input [7:0] a_i [0:7],
    input [7:0] b_i [0:7],
    input [7:0] c_i,
    output reg [7:0] cluster_size,
    output reg done
);

    // States
    localparam IDLE = 2'b00;
    localparam PROCESSING = 2'b01;
    localparam DONE_STATE = 2'b10;

    reg [1:0] state, next_state;
    reg [7:0] count; // counts 0 to 255 for orderings
    reg [7:0] min_cluster;

    // S, T values in Q8.8 (2 bits index -> 4 values)
    // S/T values: 1.0 (8'b00000001_00000000 -> 16'h0100), -1.0 (16'hFF00), 0.5 (16'h0080), -0.5 (16'hFF80)
    wire signed [15:0] s_vals [0:3];
    assign s_vals[0] = 16'h0100; // 1.0
    assign s_vals[1] = 16'hFF00; // -1.0
    assign s_vals[2] = 16'h0080; // 0.5
    assign s_vals[3] = 16'hFF80; // -0.5

    wire signed [15:0] t_vals [0:3];
    assign t_vals[0] = 16'h0100; // 1.0
    assign t_vals[1] = 16'hFF00; // -1.0
    assign t_vals[2] = 16'h0080; // 0.5
    assign t_vals[3] = 16'hFF80; // -0.5

    // Current S/T indices derived from count
    wire [1:0] s_idx, t_idx;
    assign s_idx = count[1:0];      // lower 2 bits
    assign t_idx = count[3:2];      // next 2 bits

    // Internal signals for datapath
    reg signed [15:0] current_s;
    reg signed [15:0] current_t;

    // Scores and Sort Indices
    reg signed [23:0] raw_score [0:7]; // multiplied sum
    reg signed [15:0] norm_score [0:7]; // normalized to Q8.8 (>> 8)
    reg [2:0] sort_idx [0:7];

    // Bubble Sort Step Registers
    reg signed [15:0] b_score [0:7];
    reg [2:0] b_idx [0:7];
    reg [2:0] stage; // 0 to 7 for bubble sort passes

    // C values access
    wire c_array [0:7];
    assign c_array[0] = c_i[0];
    assign c_array[1] = c_i[1];
    assign c_array[2] = c_i[2];
    assign c_array[3] = c_i[3];
    assign c_array[4] = c_i[4];
    assign c_array[5] = c_i[5];
    assign c_array[6] = c_i[6];
    assign c_array[7] = c_i[7];

    // Cluster calculation helper (combinational logic registered at end of cycle)
    reg [2:0] first_idx;
    reg [2:0] last_idx;
    reg [7:0] current_cluster_size;

    integer k, m;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            count <= 8'd0;
            min_cluster <= 8'd255;
            cluster_size <= 8'd0;
            done <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        state <= PROCESSING;
                        count <= 8'd0;
                        min_cluster <= 8'd255;
                        done <= 1'b0;
                    end
                end

                PROCESSING: begin
                    if (count < 8'd255) begin
                        // Process current ordering and move to next
                        count <= count + 1'b1;
                        if (current_cluster_size < min_cluster) begin
                            min_cluster <= current_cluster_size;
                        end
                    end else begin
                        // Final iteration
                        if (current_cluster_size < min_cluster) begin
                            min_cluster <= current_cluster_size;
                        end
                        state <= DONE_STATE;
                        done <= 1'b1;
                        cluster_size <= (current_cluster_size < min_cluster) ? current_cluster_size : min_cluster;
                    end
                end

                DONE_STATE: begin
                    // Stay here until reset
                end
            endcase
        end
    end

    // Datapath Logic (Combinational)
    always @(*) begin
        // 1. Select S and T values
        current_s = s_vals[s_idx];
        current_t = t_vals[t_idx];

        // 2. Compute Raw Scores (Q8.8 * Q8.8 = Q16.16 -> keep lower 24 bits for efficiency)
        for (k = 0; k < 8; k = k + 1) begin
            // a_i and b_i are 0-255 (0.0 - 1.0 approx in Q8.8? No, inputs are 8-bit ints)
            // Assume inputs a_i, b_i are plain integers. Q8.8 * Int requires shifting?
            // If S is Q8.8, and a_i is int 0-255, result is Q8.8 * 256.
            // Let's treat a_i, b_i as Q8.8 (i.e. 1.0 = 256). 
            // If inputs are 0-255, we shift them left by 8 to match Q8.8.
            raw_score[k] = ($signed({a_i[k], 8'b0}) * current_s) + ($signed({b_i[k], 8'b0}) * current_t);
        end

        // 3. Normalize: raw is Q16.16. We want Q8.8 for comparison/identity.
        // Divide by 2^8 (shift right 8). Take [15:0].
        for (m = 0; m < 8; m = m + 1) begin
            norm_score[m] = raw_score[m][23:8]; // Saturate or truncate higher bits
        end

        // 4. Sort initialization (if stage 0) or Bubble Sort Logic
        // We need to sort based on norm_score. Tie-breaking: worst case (spread out c=1s).
        // If scores equal, we assume the order that maximizes cluster size.
        // However, sorting network is fixed. If scores equal, specific order depends on swap logic.
        // If A == B, we can choose NOT to swap (preserving input order) or swap.
        // To spread out, we want to alternate. Let's try to detect equal scores and force a sort that spreads them.
        // Since we can't easily predict, we stick to a stable sort (don't swap if equal) and assume inputs are ordered such that this is worst case, or use a strict comparison.
        // Let's use strict comparison (<) so equal values keep their relative order (stable sort).
        // Note: Bubble sort usually swaps if A > B. We want ascending order.

        // Bubble sort network over 8 stages (cycles). 
        // Since we need result in 1 cycle, we can unroll the bubble sort or use comparators in tree.
        // Latency constraint is 256 cycles total for 256 orderings. 
        // This implies 1 cycle per ordering. 
        // Therefore, sorting must happen in 1 cycle.
        // For N=8, a sorting network (e.g., Batcher's bitonic) has depth log^2(N). 
        // But we need to implement it combinational within one clock cycle.
        // Let's implement a 1-cycle bubble sort "wave" or just flatten it.
        // Actually, with N=8, we can just use a large combinational block of comparators.
        // Let's define a generic sort using if-else chain or manual wire assignments.
        // Unrolled Bubble Sort for N=8 requires ~28 comparators.

        // Initialize sort arrays
        for (int i = 0; i < 8; i++) begin
            b_score[i] = norm_score[i];
            b_idx[i] = i;
        end

        // Pass 1
        bubble_sort_pass(b_score[0], b_idx[0], b_score[1], b_idx[1]);
        bubble_sort_pass(b_score[2], b_idx[2], b_score[3], b_idx[3]);
        bubble_sort_pass(b_score[4], b_idx[4], b_score[5], b_idx[5]);
        bubble_sort_pass(b_score[6], b_idx[6], b_score[7], b_idx[7]);
        // Pass 2
        bubble_sort_pass(b_score[1], b_idx[1], b_score[2], b_idx[2]);
        bubble_sort_pass(b_score[3], b_idx[3], b_score[4], b_idx[4]);
        bubble_sort_pass(b_score[5], b_idx[5], b_score[6], b_idx[6]);
        // Pass 3
        bubble_sort_pass(b_score[0], b_idx[0], b_score[1], b_idx[1]);
        bubble_sort_pass(b_score[2], b_idx[2], b_score[3], b_idx[3]);
        bubble_sort_pass(b_score[4], b_idx[4], b_score[5], b_idx[5]);
        bubble_sort_pass(b_score[6], b_idx[6], b_score[7], b_idx[7]);
        // Pass 4
        bubble_sort_pass(b_score[1], b_idx[1], b_score[2], b_idx[2]);
        bubble_sort_pass(b_score[3], b_idx[3], b_score[4], b_idx[4]);
        bubble_sort_pass(b_score[5], b_idx[5], b_score[6], b_idx[6]);
        // Pass 5
        bubble_sort_pass(b_score[0], b_idx[0], b_score[1], b_idx[1]);
        bubble_sort_pass(b_score[2], b_idx[2], b_score[3], b_idx[3]);
        bubble_sort_pass(b_score[4], b_idx[4], b_score[5], b_idx[5]);
        bubble_sort_pass(b_score[6], b_idx[6], b_score[7], b_idx[7]);
        // Pass 6
        bubble_sort_pass(b_score[1], b_idx[1], b_score[2], b_idx[2]);
        bubble_sort_pass(b_score[3], b_idx[3], b_score[4], b_idx[4]);
        bubble_sort_pass(b_score[5], b_idx[5], b_score[6], b_idx[6]);
        // Pass 7
        bubble_sort_pass(b_score[0], b_idx[0], b_score[1], b_idx[1]);
        bubble_sort_pass(b_score[2], b_idx[2], b_score[3], b_idx[3]);
        bubble_sort_pass(b_score[4], b_idx[4], b_score[5], b_idx[5]);
        bubble_sort_pass(b_score[6], b_idx[6], b_score[7], b_idx[7]);
        // Pass 8
        bubble_sort_pass(b_score[1], b_idx[1], b_score[2], b_idx[2]);
        bubble_sort_pass(b_score[3], b_idx[3], b_score[4], b_idx[4]);
        bubble_sort_pass(b_score[5], b_idx[5], b_score[6], b_idx[6]);
        // Pass 9
        bubble_sort_pass(b_score[0], b_idx[0], b_score[1], b_idx[1]);
        bubble_sort_pass(b_score[2], b_idx[2], b_score[3], b_idx[3]);
        bubble_sort_pass(b_score[4], b_idx[4], b_score[5], b_idx[5]);
        bubble_sort_pass(b_score[6], b_idx[6], b_score[7], b_idx[7]);
        // Pass 10
        bubble_sort_pass(b_score[1], b_idx[1], b_score[2], b_idx[2]);
        bubble_sort_pass(b_score[3], b_idx[3], b_score[4], b_idx[4]);
        bubble_sort_pass(b_score[5], b_idx[5], b_score[6], b_idx[6]);
        // Pass 11
        bubble_sort_pass(b_score[0], b_idx[0], b_score[1], b_idx[1]);
        bubble_sort_pass(b_score[2], b_idx[2], b_score[3], b_idx[3]);
        bubble_sort_pass(b_score[4], b_idx[4], b_score[5], b_idx[5]);
        bubble_sort_pass(b_score[6], b_idx[6], b_score[7], b_idx[7]);
        // Pass 12
        bubble_sort_pass(b_score[1], b_idx[1], b_score[2], b_idx[2]);
        bubble_sort_pass(b_score[3], b_idx[3], b_score[4], b_idx[4]);
        bubble_sort_pass(b_score[5], b_idx[5], b_score[6], b_idx[6]);
        // Pass 13
        bubble_sort_pass(b_score[0], b_idx[0], b_score[1], b_idx[1]);
        bubble_sort_pass(b_score[2], b_idx[2], b_score[3], b_idx[3]);
        bubble_sort_pass(b_score[4], b_idx[4], b_score[5], b_idx[5]);
        bubble_sort_pass(b_score[6], b_idx[6], b_score[7], b_idx[7]);
        // Pass 14
        bubble_sort_pass(b_score[1], b_idx[1], b_score[2], b_idx[2]);
        bubble_sort_pass(b_score[3], b_idx[3], b_score[4], b_idx[4]);
        bubble_sort_pass(b_score[5], b_idx[5], b_score[6], b_idx[6]);
        // Pass 15
        bubble_sort_pass(b_score[0], b_idx[0], b_score[1], b_idx[1]);
        bubble_sort_pass(b_score[2], b_idx[2], b_score[3], b_idx[3]);
        bubble_sort_pass(b_score[4], b_idx[4], b_score[5], b_idx[5]);
        bubble_sort_pass(b_score[6], b_idx[6], b_score[7], b_idx[7]);
        // Pass 16
        bubble_sort_pass(b_score[1], b_idx[1], b_score[2], b_idx[2]);
        bubble_sort_pass(b_score[3], b_idx[3], b_score[4], b_idx[4]);
        bubble_sort_pass(b_score[5], b_idx[5], b_score[6], b_idx[6]);
        // Pass 17
        bubble_sort_pass(b_score[0], b_idx[0], b_score[1], b_idx[1]);
        bubble_sort_pass(b_score[2], b_idx[2], b_score[3], b_idx[3]);
        bubble_sort_pass(b_score[4], b_idx[4], b_score[5], b_idx[5]);
        bubble_sort_pass(b_score[6], b_idx[6], b_score[7], b_idx[7]);
        // Pass 18
        bubble_sort_pass(b_score[1], b_idx[1], b_score[2], b_idx[2]);
        bubble_sort_pass(b_score[3], b_idx[3], b_score[4], b_idx[4]);
        bubble_sort_pass(b_score[5], b_idx[5], b_score[6], b_idx[6]);
        // Pass 19
        bubble_sort_pass(b_score[0], b_idx[0], b_score[1], b_idx[1]);
        bubble_sort_pass(b_score[2], b_idx[2], b_score[3], b_idx[3]);
        bubble_sort_pass(b_score[4], b_idx[4], b_score[5], b_idx[5]);
        bubble_sort_pass(b_score[6], b_idx[6], b_score[7], b_idx[7]);
        // Pass 20
        bubble_sort_pass(b_score[1], b_idx[1], b_score[2], b_idx[2]);
        bubble_sort_pass(b_score[3], b_idx[3], b_score[4], b_idx[4]);
        bubble_sort_pass(b_score[5], b_idx[5], b_score[6], b_idx[6]);
        // Pass 21
        bubble_sort_pass(b_score[0], b_idx[0], b_score[1], b_idx[1]);
        bubble_sort_pass(b_score[2], b_idx[2], b_score[3], b_idx[3]);
        bubble_sort_pass(b_score[4], b_idx[4], b_score[5], b_idx[5]);
        bubble_sort_pass(b_score[6], b_idx[6], b_score[7], b_idx[7]);
        // Pass 22
        bubble_sort_pass(b_score[1], b_idx[1], b_score[2], b_idx[2]);
        bubble_sort_pass(b_score[3], b_idx[3], b_score[4], b_idx[4]);
        bubble_sort_pass(b_score[5], b_idx[5], b_score[6], b_idx[6]);
        // Pass 23
        bubble_sort_pass(b_score[0], b_idx[0], b_score[1], b_idx[1]);
        bubble_sort_pass(b_score[2], b_idx[2], b_score[3], b_idx[3]);
        bubble_sort_pass(b_score[4], b_idx[4], b_score[5], b_idx[5]);
        bubble_sort_pass(b_score[6], b_idx[6], b_score[7], b_idx[7]);
        // Pass 24
        bubble_sort_pass(b_score[1], b_idx[1], b_score[2], b_idx[2]);
        bubble_sort_pass(b_score[3], b_idx[3], b_score[4], b_idx[4]);
        bubble_sort_pass(b_score[5], b_idx[5], b_score[6], b_idx[6]);
        // Pass 25
        bubble_sort_pass(b_score[0], b_idx[0], b_score[1], b_idx[1]);
        bubble_sort_pass(b_score[2], b_idx[2], b_score[3], b_idx[3]);
        bubble_sort_pass(b_score[4], b_idx[4], b_score[5], b_idx[5]);
        bubble_sort_pass(b_score[6], b_idx[6], b_score[7], b_idx[7]);
        // Pass 26
        bubble_sort_pass(b_score[1], b_idx[1], b_score[2], b_idx[2]);
        bubble_sort_pass(b_score[3], b_idx[3], b_score[4], b_idx[4]);
        bubble_sort_pass(b_score[5], b_idx[5], b_score[6], b_idx[6]);
        // Pass 27 (Max passes for N=8 bubble sort is N*(N-1)/2 = 28)
        bubble_sort_pass(b_score[0], b_idx[0], b_score[1], b_idx[1]);
        bubble_sort_pass(b_score[2], b_idx[2], b_score[3], b_idx[3]);
        bubble_sort_pass(b_score[4], b_idx[4], b_score[5], b_idx[5]);
        bubble_sort_pass(b_score[6], b_idx[6], b_score[7], b_idx[7]);
        // Pass 28
        bubble_sort_pass(b_score[1], b_idx[1], b_score[2], b_idx[2]);
        bubble_sort_pass(b_score[3], b_idx[3], b_score[4], b_idx[4]);
        bubble_sort_pass(b_score[5], b_idx[5], b_score[6], b_idx[6]);

        // Final sorted indices in b_idx

        // 5. Find First and Last c_i=1 in sorted order
        // Default to center if no c=1? 
        // We need to scan b_idx to find where c_i[b_idx[k]] == 1

        first_idx = 3'bxxx; // initialize
        last_idx = 3'b000;

        // Search for first
        if (c_array[b_idx[0]]) first_idx = 3'd0;
        else if (c_array[b_idx[1]]) first_idx = 3'd1;
        else if (c_array[b_idx[2]]) first_idx = 3'd2;
        else if (c_array[b_idx[3]]) first_idx = 3'd3;
        else if (c_array[b_idx[4]]) first_idx = 3'd4;
        else if (c_array[b_idx[5]]) first_idx = 3'd5;
        else if (c_array[b_idx[6]]) first_idx = 3'd6;
        else if (c_array[b_idx[7]]) first_idx = 3'd7;
        else first_idx = 3'd0; // No c=1, assume 0 to avoid latch, but cluster size should be 0? 
                               // If no 1s, first/last undefined. Let's check size.
                               // If no 1s, size is 0.

        // Search for last
        if (c_array[b_idx[7]]) last_idx = 3'd7;
        else if (c_array[b_idx[6]]) last_idx = 3'd6;
        else if (c_array[b_idx[5]]) last_idx = 3'd5;
        else if (c_array[b_idx[4]]) last_idx = 3'd4;
        else if (c_array[b_idx[3]]) last_idx = 3'd3;
        else if (c_array[b_idx[2]]) last_idx = 3'd2;
        else if (c_array[b_idx[1]]) last_idx = 3'd1;
        else if (c_array[b_idx[0]]) last_idx = 3'd0;
        else last_idx = 3'd0;

        // 6. Calculate Cluster Size
        if (first_idx === 3'bxxx) current_cluster_size = 0;
        else current_cluster_size = (last_idx - first_idx) + 1'b1;
    end

    // Helper task for bubble sort swap
    task bubble_sort_pass(
        inout signed [15:0] s1,
        inout [2:0] idx1,
        inout signed [15:0] s2,
        inout [2:0] idx2
    );
        reg signed [15:0] temp_s;
        reg [2:0] temp_idx;
        begin
            // Compare and swap if s1 > s2
            if (s1 > s2) begin
                temp_s = s1;
                s1 = s2;
                s2 = temp_s;

                temp_idx = idx1;
                idx1 = idx2;
                idx2 = temp_idx;
            end
            // Tie case: Worst case handling.
            // If equal, to spread out, we could swap based on index parity.
            // If we want to maximize distance, we want c=1s at ends.
            // However, standard bubble sort is stable (no swap on equal).
            // If inputs are sorted by c_i (e.g. all 1s at start), stable sort keeps them at start -> small cluster.
            // If inputs are random, stable sort is arbitrary.
            // To be "worst case", let's force swap on equal to scramble order.
            else if (s1 == s2) begin
                // Swap based on index to try to spread (heuristic)
                // If idx1 < idx2, swap? Or swap only if idx1 is even?
                // Let's swap to reverse natural order on ties.
                if (idx1 > idx2) begin // Reverse order on equal scores
                     temp_s = s1; s1 = s2; s2 = temp_s;
                     temp_idx = idx1; idx1 = idx2; idx2 = temp_idx;
                end
            end
        end
    endtask

endmodule

module TopModuleWrapper(
    input clk,
    input rst_n,
    input start,
    input [7:0] a_i [0:7],
    input [7:0] b_i [0:7],
    input [7:0] c_i,
    output [7:0] cluster_size,
    output done
);
    optimal_cluster u_opt (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .a_i(a_i),
        .b_i(b_i),
        .c_i(c_i),
        .cluster_size(cluster_size),
        .done(done)
    );
endmodule