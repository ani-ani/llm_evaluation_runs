module min_pair_distance (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] n,
    input wire signed [15:0] a [0:7],
    output reg [31:0] min_dist,
    output reg done
);

    // State encoding
    localparam IDLE = 3'b000;
    localparam CALC_PREFIX = 3'b001;
    localparam CALC_DIST = 3'b010;
    localparam DONE = 3'b011;

    reg [2:0] state;
    reg [2:0] next_state;

    // Index registers
    reg [3:0] i_idx; // Outer loop index
    reg [3:0] j_idx; // Inner loop index
    reg [3:0] p_idx; // Prefix sum index

    // Prefix sum storage (0 to 8)
    reg signed [31:0] prefix_reg [0:8];

    // Temp storage for current pair calculation
    reg signed [31:0] diff_i;
    reg signed [31:0] diff_j;
    reg [31:0] current_dist;
    reg [31:0] min_dist_next;

    // Logic for state transition and outputs
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            min_dist <= 32'hFFFFFFFF; // Max value
            done <= 1'b0;
            i_idx <= 4'd0;
            j_idx <= 4'd0;
            p_idx <= 4'd0;
        end else begin
            state <= next_state;
            
            // Output register updates
            if (state == IDLE && start) begin
                done <= 1'b0;
                min_dist <= 32'hFFFFFFFF;
            end else if (state == CALC_DIST) begin
                // Update min_dist if we found a smaller distance or if it's the first valid comparison
                // Note: On the very first pair (i=0, j=1), min_dist is still 0xFFFFFFFF, so any distance is smaller.
                if (current_dist < min_dist_next) begin
                    min_dist <= current_dist;
                end else if (min_dist_next == 32'hFFFFFFFF && j_idx == i_idx + 1) begin
                     // Handle first assignment specifically if comparison logic requires it
                     // But current_dist < 0xFFFFFFFF always holds true unless dist is negative (impossible) or max int
                     // Just to be safe if dist somehow equals max int
                     min_dist <= current_dist;
                end else if (current_dist < min_dist) begin
                     min_dist <= current_dist;
                end
            end else if (state == DONE) begin
                done <= 1'b1;
            end
        end
    end

    // Next state logic and datapath combinational logic
    always @(*) begin
        // Default next state
        next_state = state;
        
        // Default index updates (sticky unless reset)
        // We handle index increments inside the case statements
        
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = CALC_PREFIX;
                end else begin
                    next_state = IDLE;
                end
            end

            CALC_PREFIX: begin
                if (p_idx < n) begin
                    // Calculate prefix sum using a[0]...a[p_idx-1].
                    // Wait, definition: prefix[i] = sum(a[0] to a[i-1]).
                    // So prefix[0] = 0.
                    // prefix[1] = a[0].
                    // We iterate p_idx from 0 to n.
                    // If p_idx == 0, prefix[0] = 0.
                    // If p_idx > 0, prefix[p_idx] = prefix[p_idx-1] + a[p_idx-1].
                    // This logic happens in the comb block for assignment, or next state logic.
                    // We need to keep p_idx counting.
                    // It takes n+1 cycles to fill 0..n? Or just n cycles?
                    // The spec says "Compute prefix sums in 8 cycles". 
                    // Let's assume we use the 'prefix' array logic in the comb block or sequential block.
                    // To keep it simple and sequential:
                    // We increment p_idx. When p_idx wraps around to 0 or reaches limit?
                    // Let's increment p_idx until it hits n.
                    if (p_idx < n) begin
                         // Actually, to fill prefix[0..n], we need n+1 writes? 
                         // prefix[0] is always 0. 
                         // prefix[1] = a[0]. ... prefix[n] = sum a[0..n-1].
                         // Total n items (1..n) + 0. Let's do 0 to n.
                         // Let's just increment p_idx until p_idx == n. 
                         // That gives us cycles 0 to n-1.
                         // Cycle 0: calc prefix[1] (if we treat p_idx as the index of prefix being calc).
                         // Let's just count p_idx from 0 to n.
                    end
                    
                    if (p_idx == n) begin
                        next_state = CALC_DIST;
                    end else begin
                        next_state = CALC_PREFIX;
                    end
                end else begin
                     if (p_idx == n) begin
                        next_state = CALC_DIST;
                    end else begin
                        next_state = CALC_PREFIX;
                    end
                end
            end

            CALC_DIST: begin
                if (i_idx < n - 1) begin
                    if (j_idx < n - 1) begin
                        next_state = CALC_DIST;
                    end else begin
                        // j reached end, increment i
                        next_state = CALC_DIST;
                    end
                end else begin
                    // i reached end-1 (since j starts at i+1), we are done
                    next_state = DONE;
                end
            end

            DONE: begin
                if (!start) begin
                    next_state = IDLE;
                end else begin
                    next_state = DONE;
                end
            end

            default: next_state = IDLE;
        endcase
    end

    // Datapath logic (combinational) to calculate intermediate values
    // We place this here to update diffs and current_dist immediately based on state/indexes
    reg [31:0] min_dist_comb; // For use inside CALC_DIST block
    
    always @(*) begin
        // Defaults
        diff_i = 0;
        diff_j = 0;
        current_dist = 0;
        min_dist_comb = min_dist; // Initialize with current value
        
        // Logic for prefix calculation assignment
        // We need to handle the prefix_reg updates. Since it's a combinational block logic 
        // feeding the sequential block, or we can do sequential assignment.
        // Let's do a sequential assignment for prefix_reg in a separate always block or combined.
        // To keep it clean, let's calculate current_dist for CALC_DIST state.
        
        if (state == CALC_DIST) begin
            // i and j are valid indices 0..n-1
            // diff_i = i - j. Here i is i_idx, j is j_idx.
            // diff_j = prefix[i+1] - prefix[j+1].
            
            diff_i = { {28{i_idx[3]}}, i_idx } - { {28{j_idx[3]}}, j_idx }; // Sign extend 4-bit to 32-bit signed
            
            // Access prefix_reg. Note: indices are 0..n. Max index 8. 
            // i_idx max 6 (n=8). i+1 max 7. Valid.
            diff_j = prefix_reg[i_idx + 1] - prefix_reg[j_idx + 1];
            
            // Calculate Squared Distance
            // Use 32-bit arithmetic. Max value < 2^32.
            current_dist = (diff_i * diff_i) + (diff_j * diff_j);
        end
    end

    // Sequential Logic for Index Incrementation and Prefix Register Write
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            i_idx <= 0;
            j_idx <= 0;
            p_idx <= 0;
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        // Initialize for prefix calc
                        p_idx <= 0;
                        i_idx <= 0;
                        j_idx <= 0;
                        // Explicitly set prefix[0] = 0
                        prefix_reg[0] <= 0;
                    end
                end

                CALC_PREFIX: begin
                    // We need to calculate prefix[p_idx+1] = prefix[p_idx] + a[p_idx]
                    // But p_idx starts at 0. 
                    // Cycle 0 (p_idx=0): calc prefix[1] = prefix[0] + a[0].
                    // Cycle 1 (p_idx=1): calc prefix[2] = prefix[1] + a[1].
                    // Stop when p_idx == n? 
                    // If p_idx = n-1, calc prefix[n].
                    // So count p_idx from 0 to n-1.
                    
                    if (p_idx < n) begin
                        prefix_reg[p_idx + 1] <= prefix_reg[p_idx] + a[p_idx];
                        p_idx <= p_idx + 1;
                    end
                end

                CALC_DIST: begin
                    // Loop structure: 
                    // If j < n-1, j++.
                    // If j == n-1, j = i+2, i++.
                    // Wait, j starts at i+1. 
                    // If j < n-1? 
                    // i goes 0 to n-2. j goes i+1 to n-1.
                    
                    if (j_idx < n - 1) begin
                        j_idx <= j_idx + 1;
                    end else begin
                        // j is at max. Reset j to i+2, increment i.
                        j_idx <= i_idx + 2;
                        i_idx <= i_idx + 1;
                    end
                end

                DONE: begin
                    // Hold indices
                end
            endcase
        end
    end

endmodule
