module maximum_k (
    input clk,
    input rst_n,
    input start,
    input [2:0] k,
    input [2:0] n,
    input signed [7:0] arr [0:6],
    output reg signed [7:0] result [0:6],
    output reg done
);

    // Internal state definitions
    reg [2:0] state;
    localparam IDLE = 3'b000;
    localparam CHECK_DONE = 3'b001;
    localparam SORT_PASS = 3'b010;
    localparam SELECT_TOP_K = 3'b011;
    localparam COMPLETE = 3'b100;

    // Internal buffer to hold array elements
    reg signed [7:0] buffer [0:6];
    
    // Sorting control variables
    reg [2:0] pass_count; // Counts number of passes (0 to n-1)
    reg [2:0] compare_idx; // Current index for comparison
    
    // Helper variable for copying/padding
    integer i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset logic
            done <= 1'b0;
            state <= IDLE;
            // Clear result array
            for (i = 0; i < 7; i = i + 1) begin
                result[i] <= 8'sd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        // Step 1: Copy first 'n' elements from arr to buffer
                        // Note: 'n' is 3-bit, valid range 1-7. 0 is treated as empty.
                        for (i = 0; i < 7; i = i + 1) begin
                            if (i < n) begin
                                buffer[i] <= arr[i];
                            end else begin
                                buffer[i] <= 8'sd0; // Initialize unused slots to 0 (optional)
                            end
                        end
                        
                        pass_count <= 3'b000;
                        compare_idx <= 3'b000;
                        
                        // Move to check logic
                        state <= CHECK_DONE;
                    end
                end

                CHECK_DONE: begin
                    // Check conditions to skip processing
                    if (k == 3'b000) begin
                        // If k=0, result is unused, done immediately
                        done <= 1'b1;
                        state <= COMPLETE;
                    end else if (n == 3'b000) begin
                        // If n=0, no data to sort, pad everything with 0 and done
                        // (Buffer already zeroed or irrelevant)
                        state <= SELECT_TOP_K;
                    end else begin
                        // Proceed to sorting
                        state <= SORT_PASS;
                    end
                end

                SORT_PASS: begin
                    // Bubble Sort Logic
                    // One pass processes indices 0 to (n - pass_count - 2)
                    // Logic: Perform swap if buffer[compare_idx] > buffer[compare_idx + 1]
                    
                    if (buffer[compare_idx] > buffer[compare_idx + 1]) begin
                        // Swap
                        buffer[compare_idx] <= buffer[compare_idx + 1];
                        buffer[compare_idx + 1] <= buffer[compare_idx];
                    end
                    
                    // Update index
                    compare_idx <= compare_idx + 1;
                    
                    // Check if pass is complete
                    // Pass is complete when compare_idx reaches the effective end of the array
                    // Effective end is (n - pass_count - 1). We stop comparing when we reach (n - pass_count - 2)
                    // So stop condition: compare_idx == n - pass_count - 2
                    // Note: If n - pass_count <= 1, the pass is effectively done immediately (but we might need to handle state transition)
                    
                    // If we are at the end of the pass
                    if (compare_idx == n - pass_count - 2) begin
                        pass_count <= pass_count + 1;
                        compare_idx <= 3'b000;
                        
                        // Check if sorting is fully complete
                        // Bubble sort for n elements takes n-1 passes.
                        // Since n is at most 7, pass_count goes 0, 1, ..., 5 (6 passes).
                        // When pass_count == n - 1, we are done.
                        if (pass_count == n - 2) begin // Just finished pass n-2 (which is the last pass needed)
                            state <= SELECT_TOP_K;
                        end else begin
                            state <= SORT_PASS; // Continue next pass
                        end
                    end else begin
                        state <= SORT_PASS; // Continue current pass
                    end
                end

                SELECT_TOP_K: begin
                    // After sorting, largest k elements are at indices (n-k) to (n-1)
                    // We need to put them into result[0] to result[k-1] in ascending order.
                    // Also pad result[k] to result[6] with zeros.
                    
                    for (i = 0; i < 7; i = i + 1) begin
                        if (i < k) begin
                            // Determine source index in buffer
                            // Source: n - k + i
                            // If n < k, we are selecting from indices that might be out of bounds (missing elements).
                            // In that case, fill with 0.
                            if (n >= k && (n - k + i) < n) begin
                                result[i] <= buffer[n - k + i];
                            end else begin
                                result[i] <= 8'sd0;
                            end
                        end else begin
                            // Padding
                            result[i] <= 8'sd0;
                        end
                    end
                    
                    done <= 1'b1;
                    state <= COMPLETE;
                end

                COMPLETE: begin
                    // Wait for start to go low to return to IDLE
                    if (!start) begin
                        done <= 1'b0;
                        state <= IDLE;
                    end
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule
