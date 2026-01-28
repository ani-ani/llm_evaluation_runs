module median_two_sorted_arrays (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] n,
    input wire [7:0] arr1 [0:15],
    input wire [7:0] arr2 [0:15],
    output reg [15:0] result,
    output reg done
);

    // State definitions
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] COMPARE = 2'd1;
    localparam [1:0] FINISH = 2'd2;

    // Internal registers
    reg [1:0] state;
    reg [3:0] i;          // Index for arr1
    reg [3:0] j;          // Index for arr2
    reg [3:0] count;      // Number of elements processed
    reg [7:0] m1;         // Last processed value
    reg [7:0] m2;         // Second to last processed value
    reg [7:0] temp_val;   // Temporary value for comparison
    
    // Combinational logic for comparison boundary check
    wire i_valid, j_valid;
    wire [7:0] val1, val2;
    
    assign i_valid = (i < n);
    assign j_valid = (j < n);
    assign val1 = arr1[i];
    assign val2 = arr2[j];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            i <= 4'd0;
            j <= 4'd0;
            count <= 4'd0;
            m1 <= 8'd0;
            m2 <= 8'd0;
            temp_val <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        // Initialize for new calculation
                        i <= 4'd0;
                        j <= 4'd0;
                        count <= 4'd0;
                        m1 <= 8'd0;
                        m2 <= 8'd0;
                        temp_val <= 8'd0;
                        state <= COMPARE;
                    end
                end

                COMPARE: begin
                    // Logic to select smaller valid element
                    // If i is out of bounds, pick arr2
                    // If j is out of bounds, pick arr1
                    // Otherwise pick min(arr1[i], arr2[j])
                    
                    if (!i_valid && !j_valid) begin
                        // Should not happen if n >= 1
                        state <= FINISH;
                    end else if (!i_valid) begin
                        // arr1 exhausted, take from arr2
                        temp_val <= val2;
                        j <= j + 4'd1;
                    end else if (!j_valid) begin
                        // arr2 exhausted, take from arr1
                        temp_val <= val1;
                        i <= i + 4'd1;
                    end else begin
                        // Both valid, compare
                        if (val1 <= val2) begin
                            temp_val <= val1;
                            i <= i + 4'd1;
                        end else begin
                            temp_val <= val2;
                            j <= j + 4'd1;
                        end
                    end

                    // Shift history: m2 gets old m1, m1 gets new temp_val
                    m2 <= m1;
                    m1 <= temp_val;

                    // Increment counter (we just processed 'temp_val')
                    count <= count + 4'd1;

                    // Check if we have processed n+1 elements
                    // count is incremented AFTER processing, so we check against n
                    // Initial state: count=0. 
                    // Step 1: Process 1st element. count=1. 
                    // ...
                    // Step n+1: Process (n+1)th element. count = n+1.
                    // We need to process n+1 elements. 
                    // Let's say 'count' tracks processed elements. 
                    // Initially 0. After first step, 1. 
                    // Target is n+1.
                    // Let's rename logic slightly to be clearer.
                    // Let 'elements_processed' register track it.
                    // If elements_processed == n, we need one more.
                    // If elements_processed == n+1, stop.
                    
                    // Correction: The register 'count' tracks how many elements we have APPLIED to m2/m1.
                    // At COMPARE entry (first cycle), 'count' is 0. We process first element.
                    // At end of cycle, 'count' becomes 1. 
                    // We want to stop after processing n+1 elements.
                    // So transition when count == n+1 (since count increments this cycle).
                    // Wait, if count starts at 0, and we want to stop after n+1 steps,
                    // we need to compare (count + 1) with target? No.
                    // Let's track 'steps_taken'. 
                    // If steps_taken == n+1, go to FINISH.
                    // The register 'count' is incremented. 
                    // Let's assume 'count' holds the number of elements processed *before* this cycle.
                    // Initial: count=0.
                    // Cycle 1: Process 1st. count becomes 1.
                    // Cycle k: Process k-th. count becomes k.
                    // We want to process n+1 elements.
                    // So if count == n+1, we are done.
                    // But count updates to n+1 in the last cycle.
                    // So transition condition is (count == n).
                    // Wait, let's trace:
                    // Start IDLE -> COMPARE. count=0.
                    // Loop 1: count=0. Process 1. count<=1. Check (count == n)? 0 == n? No (unless n=0).
                    // Loop k: count=k-1. Process k. count<=k. Check (k == n)? 
                    // We need to process n+1. 
                    // Check (count == n+1)? No, count updates to n+1 this cycle.
                    // Check (count == n)? Yes, then process the (n+1)th element.
                    // Actually, let's just use a counter logic that is clearer.
                    
                    if (count == n) begin
                        // We are about to process the (n+1)th element (0-indexed check logic)
                        // Wait. 
                        // If count is elements processed so far.
                        // We want to stop when elements processed == n + 1.
                        // So if count == n, we process the (n+1)th element.
                        // Then count becomes n+1. 
                        // If we transition on count == n, we miss the last update to m1/m2?
                        // No, we want to finish *after* m1/m2 hold the correct values.
                        // The last valid element processed is the (n+1)th.
                        // When count == n, we enter the block to process the (n+1)th element.
                        // We update m1/m2. 
                        // Then we should go to FINISH.
                        // So transition condition should be (count == n).
                        state <= FINISH;
                    end
                end

                FINISH: begin
                    // Compute average of m1 and m2
                    // Result is Q8.8: (m1 + m2) * 128
                    // (m1 + m2) is up to 510. Fits in 9 bits.
                    // << 7 is multiply by 128.
                    result <= {m1 + m2, 8'd0};
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule