module longest_interval_chain (
    input clk,
    input rst_n,
    input start,
    input [2:0] num_intervals,
    input [7:0] interval_a [0:7],
    input [7:0] interval_b [0:7],
    output reg [2:0] result_length,
    output reg [7:0] result_a [0:7],
    output reg [7:0] result_b [0:7],
    output reg done
);

    // States
    localparam IDLE = 3'b000;
    localparam SORTING = 3'b001;
    localparam FINDING_LENGTH = 3'b010;
    localparam RECONSTRUCTING = 3'b011;
    localparam DONE = 3'b100;

    reg [2:0] state;
    
    // Internal arrays for sorting and DP
    reg [7:0] sorted_a [0:7];
    reg [7:0] sorted_b [0:7];
    reg [2:0] L [0:7]; // Length of LIS ending at i
    reg [2:0] prev [0:7]; // Previous index for reconstruction
    
    // Counters and indices
    reg [2:0] i, j, k;
    reg [2:0] max_len;
    reg [2:0] max_idx;
    
    // Temp variables for reconstruction
    reg [2:0] chain_idx;
    reg [2:0] curr_idx;
    
    // Comparator flag for sorting
    reg swap_needed;
    
    integer loop_idx;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 0;
            result_length <= 0;
            // Initialize result arrays to 0
            for (loop_idx = 0; loop_idx < 8; loop_idx = loop_idx + 1) begin
                result_a[loop_idx] <= 8'b0;
                result_b[loop_idx] <= 8'b0;
            end
            // Initialize internal arrays (optional but good practice)
            for (loop_idx = 0; loop_idx < 8; loop_idx = loop_idx + 1) begin
                sorted_a[loop_idx] <= 8'b0;
                sorted_b[loop_idx] <= 8'b0;
                L[loop_idx] <= 3'b0;
                prev[loop_idx] <= 3'b0;
            end
            i <= 0;
            j <= 0;
            k <= 0;
            max_len <= 0;
            max_idx <= 0;
            chain_idx <= 0;
            curr_idx <= 0;
            swap_needed <= 0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 0;
                    if (start) begin
                        // Load inputs into sorted arrays
                        for (loop_idx = 0; loop_idx < 8; loop_idx = loop_idx + 1) begin
                            if (loop_idx < num_intervals) begin
                                sorted_a[loop_idx] <= interval_a[loop_idx];
                                sorted_b[loop_idx] <= interval_b[loop_idx];
                            end else begin
                                sorted_a[loop_idx] <= 8'hFF; // Max value for unused slots
                                sorted_b[loop_idx] <= 8'hFF;
                            end
                        end
                        i <= 0;
                        j <= 0;
                        state <= SORTING;
                    end
                end

                SORTING: begin
                    // Bubble sort: A ascending, then B descending
                    // Outer loop variable i goes from 0 to num_intervals-2
                    if (i < num_intervals - 1) begin
                        // Inner loop variable j goes from 0 to num_intervals-i-2
                        if (j < num_intervals - 1 - i) begin
                            // Compare A values
                            if (sorted_a[j] > sorted_a[j+1]) begin
                                swap_needed <= 1;
                            end else if (sorted_a[j] == sorted_a[j+1]) begin
                                // A equal, check B (descending)
                                if (sorted_b[j] < sorted_b[j+1]) begin
                                    swap_needed <= 1;
                                end else begin
                                    swap_needed <= 0;
                                end
                            end else begin
                                swap_needed <= 0;
                            end
                            
                            // State to perform swap if needed
                            // We can do it in the same cycle or next. Let's use next cycle logic implicitly
                            // by checking flag. But to keep it 1-cycle per compare, we update here.
                            // Actually, let's just swap directly inside the condition block to save states.
                            // Wait, Verilog blocking vs non-blocking. We are in always @ posedge.
                            // We need to update j inside the block.
                            
                            if (sorted_a[j] > sorted_a[j+1]) begin
                                sorted_a[j] <= sorted_a[j+1];
                                sorted_a[j+1] <= sorted_a[j];
                                sorted_b[j] <= sorted_b[j+1];
                                sorted_b[j+1] <= sorted_b[j];
                            end else if (sorted_a[j] == sorted_a[j+1] && sorted_b[j] < sorted_b[j+1]) begin
                                sorted_a[j] <= sorted_a[j+1];
                                sorted_a[j+1] <= sorted_a[j];
                                sorted_b[j] <= sorted_b[j+1];
                                sorted_b[j+1] <= sorted_b[j];
                            end
                            
                            j <= j + 1;
                        end else begin
                            j <= 0;
                            i <= i + 1;
                        end
                    end else begin
                        // Sorting complete
                        i <= 0;
                        j <= 0;
                        k <= 0;
                        max_len <= 0;
                        max_idx <= 0;
                        // Initialize L array for DP
                        for (loop_idx = 0; loop_idx < 8; loop_idx = loop_idx + 1) begin
                            L[loop_idx] <= 3'b0;
                            prev[loop_idx] <= 3'b0;
                        end
                        state <= FINDING_LENGTH;
                    end
                end

                FINDING_LENGTH: begin
                    // Standard O(N^2) LIS on B (strictly decreasing)
                    // Input: sorted intervals 0 to num_intervals-1
                    // L[i] stores length of chain ending at i.
                    // We want decreasing B.
                    
                    // Outer loop i from 0 to N-1
                    if (i < num_intervals) begin
                        // Initialize L[i]
                        if (L[i] == 0) L[i] <= 1; // Initialize if not done yet (cycle 1 of i)
                        
                        // Inner loop j from 0 to i-1
                        if (j < i) begin
                            // If interval j contains interval i (B_j > B_i) and length increases
                            // Note: A is sorted ascending, so A_j <= A_i is guaranteed. We only need B check.
                            // Strictly decreasing B required for nesting inside.
                            // Logic: if B[j] > B[i] and L[j] + 1 > L[i]
                            // We need to read current L[i] which updates. But L[i] is updated based on previous j.
                            // To be safe with non-blocking, we can use a temporary variable, 
                            // or rely on the fact that we are iterating j.
                            // A common way: if (sorted_b[j] > sorted_b[i] && L[j] >= L[i])
                            // Let's use a comparator logic.
                            
                            if (sorted_b[j] > sorted_b[i]) begin
                                if (L[j] + 1 > L[i]) begin
                                    L[i] <= L[j] + 1;
                                    prev[i] <= j;
                                end
                            end
                            j <= j + 1;
                        end else begin
                            // Check if this is the max found so far
                            if (L[i] > max_len) begin
                                max_len <= L[i];
                                max_idx <= i;
                            end
                            // Reset j for next i
                            j <= 0;
                            i <= i + 1;
                        end
                    end else begin
                        // Done finding length
                        result_length <= max_len;
                        
                        // If chain length is 0 or 1 (input size 0 handled, but here N>=1)
                        // Handle max_len=1 case: prev not set, curr_idx is max_idx
                        
                        chain_idx <= max_len;
                        curr_idx <= max_idx;
                        i <= 0;
                        state <= RECONSTRUCTING;
                    end
                end

                RECONSTRUCTING: begin
                    if (chain_idx > 0) begin
                        // Output current index to result arrays
                        // Mapping: result_a[chain_idx-1] = sorted_a[curr_idx]... wait, result is from largest to smallest.
                        // The LIS ends at max_idx, so that is the smallest interval (last in chain).
                        // We are backtracking: curr_idx -> prev[curr_idx].
                        // So we fill result arrays from 0 upwards? Or downwards?
                        // Requirements: "sequence of intervals (largest to smallest)"
                        // Largest interval is first in chain, Smallest is last.
                        // Backtracking gives us Smallest -> ... -> Largest.
                        // If we store at index (chain_idx - 1), we are filling [0] with smallest? No.
                        // If chain_len = K:
                        // Step 1: curr = last (smallest). Store at result_a[K-1]?
                        // Step 2: curr = second last. Store at result_a[K-2]?
                        // ...
                        // Step K: curr = first (largest). Store at result_a[0]?
                        // Yes, that works.
                        
                        result_a[chain_idx - 1] <= sorted_a[curr_idx];
                        result_b[chain_idx - 1] <= sorted_b[curr_idx];
                        
                        // Move to previous
                        if (chain_idx > 1) begin
                            curr_idx <= prev[curr_idx];
                        end
                        chain_idx <= chain_idx - 1;
                    end else begin
                        state <= DONE;
                        done <= 1;
                    end
                end

                DONE: begin
                    done <= 0;
                    // Wait for start to go low if needed, or stay here
                    if (!start) begin
                        state <= IDLE;
                    end else begin
                        // Optional: stay in DONE until start goes low
                        // Or we can automatically go to IDLE on next cycle after start goes low.
                        // Let's go to IDLE immediately, assuming start is a pulse.
                        // If start stays high, we might restart. Let's assume pulse.
                        state <= IDLE;
                    end
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule
