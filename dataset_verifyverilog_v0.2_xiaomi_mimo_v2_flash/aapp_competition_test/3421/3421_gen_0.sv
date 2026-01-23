module best_subsequence (
    input [7:0] k,
    input [63:0] data,
    input [5:0] n,
    output reg [5:0] start_index,
    output reg [5:0] length
);

    integer i, j;
    integer current_popcount;
    integer best_popcount;
    integer len_A, len_B;
    logic [63:0] mask;
    logic [63:0] segment_data;
    logic [63:0] masked_data;
    logic [7:0] sum_A;
    logic [7:0] sum_B;
    logic [15:0] prod_A, prod_B;
    logic better;

    always @(*) begin
        // Default outputs to avoid latches
        start_index = 6'b0;
        length = 6'b0;
        
        // Initialize best_popcount to 0 for comparison
        best_popcount = -1; // Using -1 to indicate no valid subsequence found yet
        
        if (n >= k && k >= 1 && k <= 8'd64 && n <= 6'd64) begin
            // Outer loop: Start index
            for (i = 0; i < n; i = i + 1) begin
                // Optimization: Only proceed if remaining length is at least k
                if (n - i >= k) begin
                    current_popcount = 0;
                    
                    // Inner loop: End index
                    // We iterate j from i+k to n. 
                    // We update the popcount incrementally to avoid O(n^3) popcount logic.
                    // However, pure combinational loops in synthesis are tricky.
                    // To ensure synthesis compatibility, we will use a generate-like unrolled structure
                    // or a single cycle calculation if n is small. 
                    // Given n <= 64, unrolling completely might be huge (64*64 = 4096 segments).
                    // The prompt asks to "specify the logic", implying we can describe the algorithm.
                    // We will implement the nested loop using standard procedural code.
                    // Synthesis tools generally unroll such loops if bounds are known.
                    
                    // To properly handle the incremental popcount for a fixed start i:
                    // We need to calculate sum for j = i+k-1 (first valid length)
                    // Then add data[j] for subsequent j's.
                    
                    // Calculating popcount for the first window [i, i+k)
                    // We use bit manipulation for popcount to ensure it maps to LUTs efficiently.
                    // But since we need to synthesize generic logic, let's stick to the description strategy.
                    
                    // NOTE: In a strict combinational block, nested loops are fully unrolled by synthesis tools.
                    // For n=64, worst case is ~2000 iterations. This is large but possible for modern FPGAs/ASICs.
                    
                    // We will perform a manual incremental update approach inside the inner loop.
                    // However, Verilog `for` loops inside `always` are treated as generate blocks effectively.
                    // Let's rely on the outer loops.

                    // Re-evaluating the strategy: 
                    // Calculating popcount every time is O(64). Doing it inside loops is O(n^3). 
                    // We need to be O(n^2) or better.
                    // Since we are writing combinational code without a clock, we cannot use state to accumulate.
                    // We must calculate popcounts for every subsegment.
                    
                    // Let's use a direct lookup approach if we had a table, but we don't.
                    // Let's write the explicit logic for the inner window calculation.
                end
            end
            
            // --- Implementing the actual logic ---
            // We must loop. We will assume the synthesis tool is capable of unrolling.
            // To make it actually synthesizable without blowing up the code:
            // We will use a generate block style or just explicit loops as they are valid in some contexts,
            // but for robust generic code, we might need to be careful.
            
            // Let's try the straightforward implementation first as requested.
            
            // Reset best flag
            // We use a flag to indicate if we have a valid candidate
            bit valid_found;
            valid_found = 0;
            
            for (i = 0; i < 64; i++) begin
                if (i >= n) break; // Stop if i exceeds string length
                
                // Optimization: Calculate popcount incrementally inside the inner loop for this i
                // We need a separate accumulator for the inner loop
                integer current_sum;
                current_sum = 0;
                
                // Calculate initial window popcount [i, i+k)
                // This part is O(k) which is fine.
                for (int p = 0; p < k; p++) begin
                    if (data[i + p]) current_sum = current_sum + 1;
                end
                
                // Now iterate j starting from i + k
                for (j = i + k; j <= n; j = j + 1) begin
                    // Current segment is [i, j) with length (j-i) and sum current_sum
                    // Check if this segment is better than best
                    
                    if (!valid_found) begin
                        // First valid segment found
                        valid_found = 1;
                        start_index = i;
                        length = j - i;
                        best_popcount = current_sum;
                    end else begin
                        // Compare current_sum / (j-i) with best_popcount / length
                        // (current_sum * length) vs (best_popcount * (j-i))
                        // Note: prefer higher rate, tie on rate -> smaller start, tie on start -> longest.
                        
                        len_A = j - i;
                        len_B = length;
                        sum_A = current_sum;
                        sum_B = best_popcount;
                        
                        prod_A = sum_A * len_B;
                        prod_B = sum_B * len_A;
                        
                        better = 0;
                        
                        if (prod_A > prod_B) begin
                            better = 1;
                        end else if (prod_A == prod_B) begin
                            // Tie on rate
                            if (i < start_index) begin
                                better = 1;
                            end else if (i == start_index) begin
                                if (len_A > len_B) begin // Longest
                                    better = 1;
                                end
                            end
                        end
                        
                        if (better) begin
                            start_index = i;
                            length = len_A;
                            best_popcount = sum_A;
                        end
                    end
                    
                    // Prepare for next j (if j < n): Add data[j] to sum
                    // Because next window is [i, j+1), we add data[j] (the new bit entering)
                    // Wait, the loop condition checks [i, j). 
                    // If j is currently n, we are done for this i.
                    // If j < n, we need to update for next iteration.
                    // The next iteration j becomes j+1, so we need sum for [i, j+1).
                    // Current sum is for [i, j). Next sum = current_sum + data[j].
                    if (j < n) begin
                        if (data[j]) current_sum = current_sum + 1;
                    end
                end
            end
        end
    end

endmodule
