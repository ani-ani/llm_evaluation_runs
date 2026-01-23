module divisor_counter (
    input clk,
    input rst_n,
    input start,
    input [7:0] n,
    output reg [7:0] divisor_count,
    output reg done
);

    // State Encodings
    localparam IDLE = 2'b00;
    localparam PROCESSING = 2'b01;
    localparam DONE = 2'b10;

    reg [1:0] current_state;
    reg [1:0] next_state;
    reg [7:0] counter;
    reg [7:0] counter_next;
    reg [7:0] divisor_count_next;
    reg done_next;

    // Modulo operation logic signals
    reg [7:0] dividend;
    reg [7:0] divisor;
    wire [7:0] remainder;
    reg modulo_ready;
    reg modulo_start;
    reg [7:0] sub_cnt;
    reg [7:0] sub_cnt_next;
    reg [7:0] diff;
    wire condition_met;

    // Combinational logic for modulo operation
    // We use repeated subtraction to find n % counter
    // If counter is 0, we treat remainder as 0 to avoid division by zero errors
    // In this design, counter starts at 1, so divisor is never 0.
    always @(*) begin
        if (counter == 8'd0) begin
            diff = 8'd0;
            condition_met = 1'b1; // Treat as 0 remainder if divisor 0 (edge case safety)
        end else if (sub_cnt < n) begin
            diff = sub_cnt + counter;
            if (diff > n) begin
                 // If adding counter exceeds n, the previous value was the largest multiple
                 // The remainder is n - sub_cnt
                 // We can assert ready here if we want strictly combinational path,
                 // but let's do one cycle calculation.
                 condition_met = 1'b1;
            end else if (diff == n) begin
                 // Exact division
                 condition_met = 1'b1;
            end else begin
                 // Still subtracting
                 condition_met = 1'b0;
            end
        end else begin
            // sub_cnt >= n and diff wasn't > n in previous check logic implies exact match not found yet
            // Actually, let's simplify. We calculate remainder.
            // Let's use a simple combinational divider for 8-bit.
            // Since 8-bit is small, we can compute remainder in one cycle or few.
            // Requirement says: "The modulo operation should be implemented using repeated subtraction or a dedicated divider logic".
            // Let's use combinational subtraction logic to find remainder in one cycle for speed.
            // However, to be strictly "sequential" if implied by "Iterate", we can do one subtraction per cycle.
            // But "Result valid 256 clock cycles maximum" implies we have 256 cycles total.
            // Doing 1 subtraction per cycle (for 1 to 255) is too slow (255*255 cycles). 
            // So we must do modulo in one cycle or few cycles per iteration.
            // Let's implement a combinational remainder check.
            
            // Simple combinational remainder logic for small width:
            // remainder = n - (counter * floor(n/counter))
            // floor(n/counter) is simply (n / counter) integer division.
            // Verilog has division operator for synthesis (usually maps to logic).
            // Let's use the built-in modulo operator for clarity and synthesis optimization.
            // Or, to be explicit about the "repeated subtraction" or custom logic:
            // We will use the standard % operator as it synthesizes to efficient logic for 8-bit.
        end
    end

    // Since 8-bit is small, we can just use the % operator directly in the FSM logic
    // to check divisibility. This is synthesizable and efficient.
    // If strictly "repeated subtraction" was required algorithmically per clock, the latency would exceed 256 cycles.
    // So we assume the modulo check itself can be combinational or pipelined.
    // Let's assume combinational check to fit the "max 256 cycles" requirement for 1 to 255 iteration.
    
    // State Register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            counter <= 8'd0;
            divisor_count <= 8'd0;
            done <= 1'b0;
        end else begin
            current_state <= next_state;
            counter <= counter_next;
            divisor_count <= divisor_count_next;
            done <= done_next;
        end
    end

    // Next State Logic
    always @(*) begin
        next_state = current_state;
        counter_next = counter;
        divisor_count_next = divisor_count;
        done_next = done;

        case (current_state)
            IDLE: begin
                done_next = 1'b0;
                if (start) begin
                    if (n == 8'd0 || n == 8'd1) begin
                        // Handle edge cases immediately to save cycles
                        next_state = DONE;
                        counter_next = 8'd1; // Placeholder
                        if (n == 8'd1) divisor_count_next = 8'd1;
                        else divisor_count_next = 8'd0; // 0 has no positive divisors (or undefined, let's say 0)
                    end else begin
                        next_state = PROCESSING;
                        counter_next = 8'd1;
                        divisor_count_next = 8'd0; // Start counting (n=1 always divides, but we check loop)
                    end
                end
            end

            PROCESSING: begin
                // Check if counter divides n
                // If n % counter == 0, increment count
                if (n % counter == 0) begin
                    divisor_count_next = divisor_count + 1;
                end

                if (counter == n) begin
                    next_state = DONE;
                    done_next = 1'b1;
                    // Keep counter value as is (n)
                end else begin
                    counter_next = counter + 1;
                end
            end

            DONE: begin
                // Hold state until reset or start low? 
                // Usually done stays high until reset or new start.
                // If start is still high, we might restart. 
                // Let's wait for start to go low to prevent immediate restart if start is held high.
                if (!start) begin
                    next_state = IDLE;
                    done_next = 1'b0;
                end
            end
        endcase
    end

endmodule
