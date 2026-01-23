module bidirectional_counter (
    input clk,
    input rst_n,
    input start,
    input [7:0] tuple_first [0:7],
    input [7:0] tuple_second [0:7],
    output reg [3:0] result,
    output reg done
);

    // State encoding
    localparam IDLE = 2'b00;
    localparam PROCESSING = 2'b01;
    localparam DONE = 2'b10;

    reg [1:0] state;
    reg [2:0] i; // Counter for first index (0-7)
    reg [2:0] j; // Counter for second index (0-7)
    
    // Next state logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            i <= 3'b0;
            j <= 3'b0;
            result <= 4'b0;
            done <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= PROCESSING;
                        i <= 3'b0;
                        j <= 3'b1; // Start j at 1 since i < j
                        result <= 4'b0;
                    end
                end

                PROCESSING: begin
                    // Check bidirectional pair condition
                    // A == D (tuple_first[i] == tuple_second[j])
                    // B == C (tuple_second[i] == tuple_first[j])
                    if (tuple_first[i] == tuple_second[j] && tuple_second[i] == tuple_first[j]) begin
                        result <= result + 1'b1;
                    end

                    // Update indices for next pair
                    if (j < 3'd7) begin
                        j <= j + 1'b1;
                    end else begin
                        // j reached max (7), reset to i + 1 and increment i
                        j <= i + 1'b1;
                        if (i < 3'd6) begin
                            i <= i + 1'b1;
                        end else begin
                            // i reached 6, next increment makes it 7. 
                            // When i becomes 7, j will be 8 (invalid), so we are done.
                            // Actually, we check transition after increment.
                            // Let's refine: 
                            // When i=6, j=7 is the last pair.
                            // After processing (i=6, j=7), j becomes 8 -> reset to 7, i becomes 7.
                            // Now i=7, j=8. We need to stop.
                            // Or simpler: When i=6, j=7 is processed.
                            // Increment j -> 8. Set j = i+1 = 7. Increment i -> 7.
                            // Next cycle: i=7, j=8 is invalid, so we check bounds.
                            // Actually, the loop ends when i reaches 7.
                            // Let's set i to 7 and transition.
                            i <= 3'd7; 
                            state <= DONE;
                        end
                    end
                    
                    // Edge case: if i is already 6 and j goes to 7, next step is done.
                    // If i is 6 and j goes to 8 -> reset to 7, i goes to 7.
                    // If i is 7, we are effectively done. 
                    // Let's handle the termination condition cleanly:
                    // If i == 6 && j == 7, process, then increment j to 8, 
                    // set j = 7, i = 7. Next cycle we enter PROCESSING with i=7, j=8.
                    // We should check done condition at top of PROCESSING or after index update.
                    
                    // Let's adjust the logic to stop exactly when all 28 pairs are processed.
                    // Total pairs = 28. 
                    // We can use a cycle counter or check indices.
                    // Checking indices: 
                    // The pair (6,7) is the 28th pair. 
                    // After processing (6,7), we should go to DONE.
                    // Let's change the flow:
                    // Check if (i,j) is valid. If so, process.
                    // Increment j. If j >= 8, set j = i+1, i++. If i >= 7, go to DONE.
                end

                DONE: begin
                    // Stay in DONE until reset
                    if (!rst_n) begin
                        state <= IDLE;
                    end else if (start) begin
                        // Optional: Restart on start
                        state <= PROCESSING;
                        i <= 3'b0;
                        j <= 3'b1;
                        result <= 4'b0;
                        done <= 1'b0;
                    end
                end
            endcase
        end
    end
    
    // Revised Logic for PROCESSING state to handle termination correctly
    // The logic above inside PROCESSING had a subtle flaw with timing.
    // Let's overwrite the PROCESSING block for clarity.
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            i <= 3'b0;
            j <= 3'b0;
            result <= 4'b0;
            done <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= PROCESSING;
                        i <= 3'b0;
                        j <= 3'b1;
                        result <= 4'b0;
                    end
                end

                PROCESSING: begin
                    // 1. Perform comparison on current (i, j)
                    // Since i starts at 0, j starts at 1, and we only enter here when i < 7 usually.
                    // But we need to ensure we don't process invalid states (i=7).
                    if (i < 3'd7) begin
                        if (tuple_first[i] == tuple_second[j] && tuple_second[i] == tuple_first[j]) begin
                            result <= result + 1'b1;
                        end
                    end

                    // 2. Update counters
                    if (j < 3'd7) begin
                        j <= j + 1'b1;
                    end else begin
                        // j reached 7, reset to i+1
                        j <= i + 1'b1;
                        // Increment i
                        if (i < 3'd6) begin
                            i <= i + 1'b1;
                        end else begin
                            // i was 6. After increment it becomes 7.
                            // The pair (6, 7) is the last one processed in this cycle.
                            // Next state should be DONE.
                            i <= i + 1'b1; // i becomes 7
                            state <= DONE;
                        end
                    end
                end

                DONE: begin
                    done <= 1'b1;
                    if (!rst_n) begin
                        state <= IDLE;
                        done <= 1'b0;
                    end else if (start) begin
                        // Restart capability
                        state <= PROCESSING;
                        i <= 3'b0;
                        j <= 3'b1;
                        result <= 4'b0;
                        done <= 1'b0;
                    end
                end
            endcase
        end
    end

endmodule