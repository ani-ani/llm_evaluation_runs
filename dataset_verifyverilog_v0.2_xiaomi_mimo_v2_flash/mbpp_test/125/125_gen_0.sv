module max_diff_substring(
    input clk,
    input rst_n,
    input start,
    input [7:0] binary_string,
    output reg [3:0] max_diff,
    output reg done
);

    // States
    localparam IDLE = 2'b00;
    localparam PROCESS = 2'b01;
    localparam DONE = 2'b10;

    reg [1:0] state, next_state;
    reg [3:0] index, next_index;      // Counter for 8 bits (0-7)
    reg signed [4:0] current_sum, next_current_sum; // Signed to handle negative values, range -8 to 8
    reg signed [4:0] max_sum, next_max_sum;         // Signed, max range 0 to 8
    reg [3:0] max_diff_reg, next_max_diff;          // Latched result
    reg done_reg, next_done;

    // State Register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            index <= 4'd0;
            current_sum <= 5'sd0;
            max_sum <= 5'sd0;
            max_diff_reg <= 4'd0;
            done_reg <= 1'b0;
        end else begin
            state <= next_state;
            index <= next_index;
            current_sum <= next_current_sum;
            max_sum <= next_max_sum;
            max_diff_reg <= next_max_diff;
            done_reg <= next_done;
        end
    end

    // Next State Logic
    always @(*) begin
        // Default assignments
        next_state = state;
        next_index = index;
        next_current_sum = current_sum;
        next_max_sum = max_sum;
        next_max_diff = max_diff_reg;
        next_done = done_reg;

        case (state)
            IDLE: begin
                if (start) begin
                    next_state = PROCESS;
                    next_index = 4'd0;
                    next_current_sum = 5'sd0;
                    next_max_sum = 5'sd0;
                    next_done = 1'b0;
                end else begin
                    next_state = IDLE;
                    next_index = 4'd0;
                    next_current_sum = 5'sd0;
                    next_max_sum = 5'sd0;
                    next_done = 1'b0;
                end
            end

            PROCESS: begin
                // Process bit at current index
                if (binary_string[index] == 1'b0) begin
                    // Bit is '0', increment
                    next_current_sum = current_sum + 1'sd1;
                end else begin
                    // Bit is '1', decrement
                    next_current_sum = current_sum - 1'sd1;
                end

                // If current_sum < 0, reset to 0
                if (next_current_sum < 0) begin
                    next_current_sum = 5'sd0;
                end

                // Update max_sum
                if (next_current_sum > max_sum) begin
                    next_max_sum = next_current_sum;
                end else begin
                    next_max_sum = max_sum;
                end

                // Increment index
                if (index < 4'd7) begin
                    next_index = index + 1'b1;
                    next_state = PROCESS;
                end else begin
                    // Last bit processed, move to DONE
                    next_index = index + 1'b1; // Optional: keep index at 8
                    next_state = DONE;
                    next_max_diff = max_sum[3:0]; // Latch the result
                    next_done = 1'b1;
                end
            end

            DONE: begin
                // Stay in DONE until reset or start goes low then high
                if (!start) begin
                    next_done = 1'b1; // Keep done high as long as in DONE state
                    next_state = DONE; // Wait for start to go high again? No, prompt says "until start goes low and high again"
                    // To allow re-trigger, we need to exit DONE when start goes low, wait for high.
                    // But typically, staying in DONE until reset or new start is fine.
                    // Let's implement: Stay in DONE. If start is low, we are ready to trigger next start?
                    // Actually, logic usually requires start to be low before a new pulse.
                    // So, we stay in DONE. When start goes low, we might transition to IDLE (or stay in DONE but waiting).
                    // Let's just stay in DONE. The check for "start goes low and high" is handled by the external edge detector or simply requiring start to be low before new run.
                    // To be precise to prompt: "Stay in DONE until start goes low and high again".
                    // This implies we must transition out of DONE if start is low.
                    next_state = DONE; // Default stay
                end else begin
                    // If start is high, we stay here (user must pull low first)
                    next_state = DONE;
                end
                
                // To implement "until start goes low and high", we need an intermediate state or logic.
                // Let's simply go to IDLE when start goes low. Then wait for high in IDLE.
                if (!start) begin
                    next_state = IDLE;
                    next_done = 1'b0; // Deassert done when resetting to IDLE
                end
            end

            default: next_state = IDLE;
        endcase
    end

    // Output Assignments
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            max_diff <= 4'd0;
            done <= 1'b0;
        end else begin
            // Latch outputs only when entering DONE or staying in DONE
            if (state == DONE) begin
                max_diff <= max_diff_reg;
                done <= 1'b1;
            end else begin
                done <= 1'b0;
            end
        end
    end

endmodule
