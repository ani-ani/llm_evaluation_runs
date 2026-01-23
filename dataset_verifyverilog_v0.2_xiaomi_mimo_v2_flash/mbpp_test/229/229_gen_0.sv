module array_partition (
    input clk,
    input rst_n,
    input start,
    input [2:0] n,
    input signed [7:0] arr [0:7],
    output reg signed [7:0] result [0:7],
    output reg done
);

    // State encoding
    localparam IDLE = 2'b00;
    localparam PROCESSING = 2'b01;
    localparam DONE = 2'b10;

    reg [1:0] state, next_state;
    reg signed [7:0] temp_arr [0:7]; // Internal array for processing
    reg [2:0] i; // Outer loop index
    reg [2:0] j; // Inner loop index
    reg processing_done; // Flag to indicate processing complete
    reg swap_needed; // Flag to check if swap is required

    // State register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end

    // Next state and output logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset outputs and internal signals
            done <= 1'b0;
            i <= 3'b0;
            j <= 3'b0;
            processing_done <= 1'b0;
            // Initialize result array (optional, but good practice)
            result[0] <= 8'sd0; result[1] <= 8'sd0; result[2] <= 8'sd0; result[3] <= 8'sd0;
            result[4] <= 8'sd0; result[5] <= 8'sd0; result[6] <= 8'sd0; result[7] <= 8'sd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    processing_done <= 1'b0;
                    if (start) begin
                        // Copy input array to internal register
                        temp_arr[0] <= arr[0];
                        temp_arr[1] <= arr[1];
                        temp_arr[2] <= arr[2];
                        temp_arr[3] <= arr[3];
                        temp_arr[4] <= arr[4];
                        temp_arr[5] <= arr[5];
                        temp_arr[6] <= arr[6];
                        temp_arr[7] <= arr[7];
                        i <= 3'b0;
                        j <= 3'b1;
                    end
                end

                PROCESSING: begin
                    // Bubble sort logic: Move negatives to front
                    // If current (temp_arr[i]) is positive AND future (temp_arr[j]) is negative, swap
                    // This preserves relative order of negatives (they bubble up one by one)
                    // and relative order of positives (they stay unless a negative passes them)
                    
                    if ((temp_arr[i] >= 0) && (temp_arr[j] < 0)) begin
                        // Swap elements
                        temp_arr[i] <= temp_arr[j];
                        temp_arr[j] <= temp_arr[i];
                    end

                    // Increment inner index
                    j <= j + 1;

                    // Check if inner loop reached end
                    if (j == n - 1) begin
                        // Reset inner index
                        j <= i + 2; // Start of next inner loop iteration (i+1 is next i, so i+2)
                        if (n > 1) j <= i + 2;
                        else j <= 3'b0; // Should not happen if n <= 1, but safety
                         
                        // Move to next outer iteration
                        i <= i + 1;
                        
                        // Check if outer loop reached end (i goes 0 to n-2)
                        // If i becomes n-1, processing is done
                        if (i == n - 2) begin
                            processing_done <= 1'b1;
                        end
                        
                        // Edge case: if n=1 or n=0, processing is instant
                        if (n < 2) begin
                            processing_done <= 1'b1;
                        end
                    end
                end

                DONE: begin
                    done <= 1'b1;
                    // Result was already written to 'result' register in transition logic below
                end
            endcase
        end
    end

    // Combinational logic for next state transition
    always @(*) begin
        case (state)
            IDLE: begin
                if (start) next_state = PROCESSING;
                else next_state = IDLE;
            end
            
            PROCESSING: begin
                // We need to detect when the loops are actually finished.
                // The sequential logic updates i and j.
                // We need to check the condition that signifies the end of the last swap check.
                // The last check happens when i is n-2 and j is n-1.
                // When processing_done is set (which happens in the sequential block when i hits n-2),
                // we transition to DONE.
                if (processing_done) next_state = DONE;
                else next_state = PROCESSING;
            end
            
            DONE: begin
                next_state = IDLE; // Return to IDLE automatically
            end
            
            default: next_state = IDLE;
        endcase
    end

    // Update result register only when moving to DONE state
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            result[0] <= 8'sd0; result[1] <= 8'sd0; result[2] <= 8'sd0; result[3] <= 8'sd0;
            result[4] <= 8'sd0; result[5] <= 8'sd0; result[6] <= 8'sd0; result[7] <= 8'sd0;
        end else begin
            if (state == PROCESSING && next_state == DONE) begin
                result <= temp_arr;
            end else if (state == DONE) begin
                // Keep result stable, done is high
            end
        end
    end

endmodule
