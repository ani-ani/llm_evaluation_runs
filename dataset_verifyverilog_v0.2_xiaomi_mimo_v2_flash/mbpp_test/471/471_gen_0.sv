module find_remainder (
    input clk,
    input rst_n,
    input start,
    input [7:0] n,
    input [2:0] arr_len,
    input [7:0] arr [0:7],
    output reg [7:0] result,
    output reg done
);

    // State encoding
    localparam IDLE = 2'b00;
    localparam PROCESSING = 2'b01;
    localparam DONE = 2'b10;

    // Internal registers
    reg [1:0] state;
    reg [1:0] next_state;
    reg [2:0] index;           // Current index into array
    reg [2:0] index_next;
    reg [7:0] accumulator;     // Current product modulo n
    reg [7:0] accumulator_next;
    reg [7:0] result_reg;
    reg [7:0] result_reg_next;
    reg done_reg;
    reg done_reg_next;

    // Combinational logic for the algorithm
    // Calculate temp = current_element % n
    // Since n is max 255, we can use simple modulo logic
    // For n=1, result is always 0
    wire [7:0] current_element;
    assign current_element = arr[index];

    reg [7:0] temp_mod;
    reg [15:0] product; // 16-bit to hold product of two 8-bit numbers
    reg [7:0] next_acc;

    always @(*) begin
        // Default assignments
        next_state = state;
        index_next = index;
        accumulator_next = accumulator;
        result_reg_next = result_reg;
        done_reg_next = 1'b0;

        // Modulo operation for current element: current_element % n
        // Since n <= 255, we can compute this by checking if n > current_element
        if (n == 8'd1) begin
            temp_mod = 8'd0;
        end else if (n > current_element) begin
            temp_mod = current_element;
        end else begin
            // Simple modulo for n <= 255. This works for n > current_element (handled above)
            // and handles the case where n <= current_element.
            // Using a simple subtraction loop logic or just modulo operator.
            // Since synthesizable, we use modulo operator or comparator logic.
            // To be safe and generic for n <= 255, let's use the modulo operator.
            // Synthesis tools will optimize this.
            temp_mod = current_element % n;
        end

        // Multiplication: accumulator * temp_mod
        // Result needs to be modulo n
        if (n == 8'd1) begin
            next_acc = 8'd0;
        end else begin
            product = accumulator * temp_mod;
            if (product < n) begin
                next_acc = product[7:0];
            end else begin
                next_acc = product % n;
            end
        end

        case (state)
            IDLE: begin
                if (start) begin
                    next_state = PROCESSING;
                    index_next = 3'b000;
                    // Initialize accumulator to 1 (identity for multiplication)
                    // If n==1, result is 0 immediately, but we follow flow for consistency or handle done.
                    accumulator_next = (n == 8'd1) ? 8'd0 : 8'd1;
                    done_reg_next = 1'b0;
                end
            end

            PROCESSING: begin
                if (index < arr_len) begin
                    // Perform one iteration
                    // Update accumulator
                    if (n == 8'd1) begin
                        accumulator_next = 8'd0;
                    end else begin
                        accumulator_next = next_acc;
                    end
                    index_next = index + 1'b1;
                end
                
                // Check if finished
                if (index >= arr_len || index == 3'b111) begin // Safety check for max 8 elements
                     // If arr_len is 0? Requirement says 1-8, but index < arr_len covers 0.
                     // If we just processed the last element (index == arr_len - 1),
                     // we increment index to arr_len, then transition to DONE.
                     if (index_next >= arr_len && arr_len != 0) begin
                         next_state = DONE;
                         result_reg_next = accumulator_next;
                         done_reg_next = 1'b1;
                     end else if (arr_len == 0) begin // Edge case: length 0? Not specified, but handle gracefully.
                         next_state = DONE;
                         result_reg_next = (n == 8'd1) ? 8'd0 : 8'd1;
                         done_reg_next = 1'b1;
                     end
                end
            end

            DONE: begin
                // Hold state until reset or new start (assuming start is handled in IDLE)
                done_reg_next = 1'b1;
                // If start is asserted again while in DONE, we might want to restart.
                // But usually, state machine waits for reset or explicit go.
                // Logic below handles transition to IDLE or restart.
                if (start) begin // Optional: allow restart from DONE if start held high? 
                    // Usually start is a pulse. Let's wait for reset or falling edge of start.
                    // But standard is IDLE waits for start. So if we are in DONE and start is high,
                    // we might stay here or go to IDLE? 
                    // The requirement is "Latency 25 clocks". 
                    // If user keeps start high, we shouldn't restart immediately.
                    // So we stay in DONE until start goes low.
                    done_reg_next = 1'b1;
                end else begin
                    next_state = IDLE;
                    done_reg_next = 1'b0;
                end
            end
            
            default: next_state = IDLE;
        endcase
    end

    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            index <= 3'b0;
            accumulator <= 8'b0;
            result <= 8'b0;
            done <= 1'b0;
        end else begin
            state <= next_state;
            index <= index_next;
            accumulator <= accumulator_next;
            result <= result_reg_next;
            done <= done_reg_next;
        end
    end

endmodule
