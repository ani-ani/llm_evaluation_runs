module seq_match_finder(
    input clk,
    input rst_n,
    input start,
    input [3:0] n,
    input [3:0] m,
    input [3:0] p,
    input [3:0] a [0:15],
    input [3:0] b [0:15],
    output reg [3:0] result_count,
    output reg [3:0] result_positions [0:15],
    output reg done
);

    // State Encoding
    localparam IDLE = 3'b001;
    localparam INIT_HIST = 3'b010;
    localparam COMPARE = 3'b100;
    localparam UPDATE_WINDOW = 3'b011; // Also handles shifting queue and finalizing
    localparam DONE = 3'b110;

    // Registers
    reg [2:0] state;
    reg [3:0] q; // Current position (0-based)
    reg [3:0] count_idx; // General purpose index for loops
    reg [3:0] result_idx; // Index for storing results
    
    // Histogram Counters (Values 1-15, index 1-15, index 0 unused)
    reg [3:0] hist_a [0:15];
    reg [3:0] hist_b [0:15];
    
    // Queue for managing the sliding window elements to remove
    // Stores the indices of 'a' currently in the window in order of insertion
    reg [3:0] window_queue [0:15];
    reg [3:0] queue_head; // Points to next write location (also count of elements)
    
    // Logic Variables
    reg mismatch;
    reg [3:0] val;
    reg [3:0] idx_to_remove;
    reg [3:0] val_new;
    reg [3:0] val_old;
    integer i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result_count <= 4'd0;
            result_idx <= 4'd0;
            // Reset arrays (optional but good practice)
            for (i = 0; i < 16; i = i + 1) begin
                hist_a[i] <= 4'd0;
                hist_b[i] <= 4'd0;
                window_queue[i] <= 4'd0;
                result_positions[i] <= 4'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    result_count <= 4'd0;
                    result_idx <= 4'd0;
                    count_idx <= 4'd0;
                    queue_head <= 4'd0;
                    q <= 4'd0;
                    
                    if (start) begin
                        state <= INIT_HIST;
                        // Pre-calculate Hist B (static)
                        // We will do this in INIT_HIST to be cycle accurate
                    end
                end

                INIT_HIST: begin
                    // Initialize Hist A (first window) and Hist B
                    if (count_idx < m) begin
                        // 1. Build Hist B (one time, starts over if repeated, but simple logic)
                        val = b[count_idx];
                        if (val != 4'd0 && val < 4'd16)
                            hist_b[val] <= hist_b[val] + 1'b1;

                        // 2. Build Hist A (initial window at q=0)
                        // Check bounds: if count_idx < n
                        if (count_idx < n) begin
                            val_new = a[count_idx];
                            if (val_new != 4'd0 && val_new < 4'd16)
                                hist_a[val_new] <= hist_a[val_new] + 1'b1;
                            
                            // Fill Queue
                            window_queue[count_idx] <= count_idx; // Store index
                        end
                        
                        count_idx <= count_idx + 1'b1;
                    end else begin
                        // Done initializing
                        queue_head <= m; // Number of elements in queue (if n >= m)
                        // If n < m, this logic is flawed, but constraints imply m <= n usually for valid match
                        // We proceed to compare. 
                        // However, if n < m, no valid windows. Let's handle gracefully.
                        // If n < m, we can jump to DONE.
                        if (n < m) begin
                            state <= DONE;
                        end else begin
                            state <= COMPARE;
                        end
                        count_idx <= 4'd0; // Reset for compare loop
                    end
                end

                COMPARE: begin
                    // Compare hist_a and hist_b (indexes 1-15)
                    // We check one index per cycle for area efficiency vs full comparator
                    if (count_idx < 4'd15) begin
                        count_idx <= count_idx + 1'b1;
                        // Check index count_idx + 1
                        if (hist_a[count_idx + 1] != hist_b[count_idx + 1]) begin
                            mismatch <= 1'b1;
                        end
                    end else begin
                        // Finished checking all values
                        if (!mismatch && (queue_head == m)) begin
                            // Valid match
                            if (result_idx < 16) begin
                                result_positions[result_idx] <= q + 1'b1; // 1-based
                                result_count <= result_count + 1'b1;
                                result_idx <= result_idx + 1'b1;
                            end
                        end
                        
                        // Prepare for next state
                        mismatch <= 1'b0;
                        count_idx <= 4'd0;
                        
                        // Check if we need to update or finish
                        // Current position q covers indices [q, q + (m-1)*p]
                        // Next position q+1 covers [q+p, q+p + (m-1)*p]
                        // Bounds check: Is the last element of the NEXT window valid?
                        // Last element index = q_next + (m-1)*p = q + 1 + (m-1)*p
                        // Wait, the logic "increment by p" in prompt is confusing if q increments by 1.
                        // Prompt: "It starts at position 0 (q=0) and increments by p until the window exceeds bounds."
                        // Prompt also: "Outputs are q+1". 
                        // Usually q is the start index. "Increment by p" likely means stride.
                        // Let's assume q increments by 1, and we use stride p for the window indices.
                        // Wait, "Strude p" usually means indices are q, q+p, q+2p...
                        // Re-reading: "sliding window... with stride p". "increments by p".
                        // If q increments by p, and q is start index. 
                        // Next start index = q + p.
                        // Last index of current window = q + (m-1)*p.
                        // Next last index = q + p + (m-1)*p = q + m*p.
                        // Bounds check: q + (m-1)*p < n ? (Valid Current)
                        // Bounds check for NEXT: q + p + (m-1)*p < n ? 
                        // Wait, if q increments by p, logic differs.
                        // Let's re-read carefully: "starts at position 0 (q=0) and increments by p".
                        // "Sliding window... with stride p".
                        // This implies: Window 1: a[0], a[p], a[2p]...
                        // Window 2: a[1], a[1+p]...
                        // "increments by p" implies q goes 0, p, 2p...
                        // BUT output is sorted. If q goes 0, p, 2p, output is sorted.
                        // If q goes 0, 1, 2, output is sorted.
                        // Let's look at the "UPDATE_WINDOW" requirement. 
                        // Usually "sliding" implies q++. But "stride p" implies q+=p.
                        // Let's support general q incrementing by 1 for exhaustive search, 
                        // BUT the window elements are spaced by p.
                        // Wait, prompt says "increments by p until window exceeds bounds".
                        // If q=0, window is indices 0, p, 2p... (m elements).
                        // If q increments by p, next window is p, 2p, 3p...
                        // This is effectively a sub-sequence, not a sliding window in the traditional sense.
                        // However, the prompt mentions "Update Window" state.
                        // If q increments by 1, we have true sliding (remove 0, add p, etc).
                        // If q increments by p, we just shift.
                        // Let's assume the standard interpretation of "Sliding Window" where q increments by 1.
                        // BUT the prompt says "increments by p". 
                        // Let's check the "UPDATE_WINDOW" logic implied. 
                        // "Histogram matches check". 
                        // If q increments by 1: 
                        //   Remove a[q]
                        //   Add a[q + (m-1)p + 1] ? No.
                        //   If q=0: elements 0, p, 2p, ...
                        //   If q=1: elements 1, 1+p, 1+2p ...
                        //   This requires updating ALL elements? No.
                        //   Actually, the set of indices changes completely if p != 1.
                        //   EXCEPT: If we treat it as a FIFO of size m, where inputs are a[q], a[q+p]...
                        //   Wait, no. The set of elements for q=0 is {0, p, 2p...}.
                        //   For q=1, it is {1, 1+p, 1+2p...}.
                        //   The intersection is empty unless p=1.
                        //   So "Update Window" is expensive if p>1.
                        //   BUT, "increment by p" suggests q changes by p.
                        //   If q changes by p: q = p, indices {p, 2p, 3p...}.
                        //   This is just shifting the previous list (remove 0, add m*p).
                        //   This fits "increment by p" perfectly.
                        //   Let's re-read: "starts at 0, increments by p". 
                        //   Usually this means q = 0, p, 2p...
                        //   Let's verify with output "sorted". Yes.
                        //   Let's assume q increments by p.

                        // Determine next Q:
                        // If q + p is valid start? (i.e. last element q + p + (m-1)p = q + m*p < n)
                        // Wait, last element of current window (q=0) is (m-1)p.
                        // Check: (m-1)p < n.
                        // Next q: q = p.
                        // Last element: p + (m-1)p = m*p.
                        // Check: m*p < n.
                        // Loop condition: q + p + (m-1)p < n ? No.
                        // Loop condition: q + (m-1)p < n (Current valid) AND we can continue.
                        // Actually, we usually iterate q from 0 up to limit.
                        // Limit: q + (m-1)*p < n.
                        // If q increments by p, we need to check if (q + p) is valid.
                        // Valid: (q + p) + (m-1)*p < n => q + m*p < n.
                        
                        // Let's refine: 
                        // Iteration 0: q=0. Valid if (m-1)*p < n.
                        // Iteration 1: q=p. Valid if p + (m-1)*p = m*p < n.
                        // ...
                        // Iteration k: q=k*p. Valid if k*p + (m-1)*p < n.
                        // Let's go to UPDATE_WINDOW to handle the logic.
                        state <= UPDATE_WINDOW;
                    end
                end

                UPDATE_WINDOW: begin
                    // This state handles two main things depending on logic:
                    // 1. Remove element leaving the window.
                    // 2. Add new element entering the window.
                    // 3. Update q.
                    // 4. Check bounds.
                    // If q increments by p:
                    // Leaving: a[q] (current q)
                    // Entering: a[q + m*p] (last element of NEXT window)
                    
                    // 1. Remove a[q] (if q + (m-1)*p was valid, i.e., current window valid)
                    //    But we only decrement if the value is valid.
                    //    We already processed the compare for the current window.
                    //    So we prepare for the NEXT window.
                    
                    // Action: 
                    // Decrement hist[a[q]]
                    // Increment hist[a[q + m*p]]
                    // Update q <= q + p
                    
                    // Check Bounds for NEXT iteration:
                    // Next q = q + p.
                    // We need to ensure that the window starting at (q+p) is valid.
                    // Last element index: (q+p) + (m-1)*p = q + m*p.
                    // We check: Is (q + m*p) < n ?
                    
                    // But wait, we need to be careful. 
                    // We are currently at state COMPARE (processed q).
                    // We want to move to q_next = q + p.
                    // We need to check if q_next is valid.
                    // Validity of window at q_next: Last index < n.
                    // Last index = q_next + (m-1)*p.
                    // Check: (q + p) + (m-1)*p < n  => q + m*p < n.
                    
                    // If q + m*p < n, we update histogram and q.
                    // If not, we are done.

                    if (q + m*p < n) begin
                        // Valid next window exists
                        
                        // Remove element at 'q'
                        val_old = a[q];
                        if (val_old != 4'd0 && val_old < 4'd16) begin
                            // Ensure we don't underflow (though logically it should be there)
                            if (hist_a[val_old] > 0)
                                hist_a[val_old] <= hist_a[val_old] - 1'b1;
                        end
                        
                        // Add element at 'q + m*p'
                        val_new = a[q + m*p];
                        if (val_new != 4'd0 && val_new < 4'd16) begin
                            hist_a[val_new] <= hist_a[val_new] + 1'b1;
                        end
                        
                        // Update q
                        q <= q + p;
                        
                        // Reset flags and go back to compare
                        mismatch <= 1'b0;
                        count_idx <= 4'd0;
                        state <= COMPARE;
                        
                    end else begin
                        // No more valid windows
                        state <= DONE;
                    end
                end

                DONE: begin
                    done <= 1'b1;
                    if (!start) begin // Wait for start to go low to return to IDLE (optional handshake)
                        // state <= IDLE; // Or stay here until reset
                    end
                    // Stay in DONE until reset or explicit command (standard practice)
                end
            endcase
        end
    end

endmodule
