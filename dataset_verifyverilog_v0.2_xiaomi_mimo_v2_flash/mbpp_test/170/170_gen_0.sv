module sum_range_list(
    input clk,
    input rst_n,
    input start,
    input [3:0] m,
    input [3:0] n,
    input [7:0] list1 [11:0],
    output reg [10:0] result,
    output reg done
);

    // State encoding
    localparam IDLE = 2'b00;
    localparam PROCESSING = 2'b01;
    localparam DONE = 2'b10;

    reg [1:0] state;
    reg [3:0] current_idx;
    reg [10:0] sum_acc;
    reg [3:0] target_n;
    reg processing_start; // Flag to control iteration

    // State transition and sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 11'b0;
            done <= 1'b0;
            current_idx <= 4'b0;
            sum_acc <= 11'b0;
            target_n <= 4'b0;
            processing_start <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= PROCESSING;
                        // Initialize iteration
                        current_idx <= m;
                        target_n <= n;
                        sum_acc <= 11'b0;
                        processing_start <= 1'b1;
                    end
                end

                PROCESSING: begin
                    // Latch start deassertion to return to idle after completion if needed
                    if (!start) begin
                        processing_start <= 1'b0;
                    end

                    // Logic to add value and increment index
                    // We assume list1 is accessed via index current_idx
                    // In Verilog arrays, we might need to ensure proper blocking/non-blocking usage.
                    // Here we add current element to accumulator.
                    sum_acc <= sum_acc + list1[current_idx];
                    
                    // Increment index
                    current_idx <= current_idx + 1;

                    // Check if we reached the end (inclusive)
                    // If current_idx was n, we just added it. Next cycle we should stop or go to DONE.
                    // Requirement: "After reaching n, store result and transition to DONE"
                    // Let's check if current_idx == target_n. If so, next cycle we transition.
                    // Wait, if we just incremented, current_idx becomes target_n + 1.
                    // Let's check before increment or handle logic carefully.
                    
                    // Revised Logic for inclusive range:
                    // We perform addition for index `current_idx`.
                    // If `current_idx` == `target_n`, we are done with the summation.
                    
                    if (current_idx == target_n) begin
                        // This is the last element to add (calculated in this cycle)
                        // We need to transition to DONE in the next cycle, or immediately?
                        // "Result valid 14 clock cycles after start asserted".
                        // "After reaching n, store result and transition to DONE".
                        // Let's schedule transition to DONE next cycle.
                        // However, the sum_acc update happens this cycle.
                        // To ensure result is valid for the full cycle, we might move to DONE next cycle.
                        state <= DONE;
                        result <= sum_acc + list1[current_idx]; // Store final result
                    end else if (current_idx > target_n) begin
                        // Should not happen with correct logic, but safety catch
                        state <= DONE;
                        result <= sum_acc; // Current accumulated sum
                    end else begin
                        // Continue processing
                        state <= PROCESSING;
                    end
                end

                DONE: begin
                    done <= 1'b1;
                    // Wait for start to deassert to return to IDLE
                    // Requirement: "When start is deasserted, return to IDLE"
                    if (!start) begin
                        state <= IDLE;
                        done <= 1'b0;
                    end
                end
            endcase
        end
    end

endmodule
}