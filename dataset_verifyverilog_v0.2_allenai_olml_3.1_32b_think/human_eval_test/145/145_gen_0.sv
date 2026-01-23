module order_by_points (input clk, input rst_n, input start, input [4:0] count, input signed [15:0] nums [0:7], output reg [4:0] done_count, output reg signed [15:0] result [0:7], output reg done);

// Internal registers
reg [15:0] arr [0:7];
reg [4:0] count_reg;
reg [2:0] state;
reg [3:0] pass_num;
reg [3:0] index;
reg swap_occurred;
reg [5:0] digit_sum_a, digit_sum_b;
reg [15:0] a, b, a_abs, b_abs;
reg start_pulsed;

// Combinational assignments for outputs
assign result = arr;
assign done_count = done ? count_reg : 0;

always @(posedge clk) begin
    if (!rst_n) begin
        arr <= 0;
        count_reg <= 0;
        state <= 0;
        pass_num <= 0;
        index <= 0;
        swap_occurred <= 0;
        digit_sum_a <= 0;
        digit_sum_b <= 0;
        a <= 0;
        b <= 0;
        a_abs <= 0;
        b_abs <= 0;
        start_pulsed <= 0;
        done <= 0;
    end else begin
        // Start pulse detection
        if (start) begin
            if (!start_pulsed) begin
                start_pulsed <= 1;
            end else begin
                start_pulsed <= 0;
            end
        end

        // Initialize a, b, a_abs, b_abs to 0 in all states except COMPARE
        a <= 0;
        b <= 0;
        a_abs <= 0;
        b_abs <= 0;

        if (state == 0) begin // IDLE
            if (start_pulsed) begin
                // Load nums into arr
                arr[0] <= nums[0];
                arr[1] <= nums[1];
                arr[2] <= nums[2];
                arr[3] <= nums[3];
                arr[4] <= nums[4];
                arr[5] <= nums[5];
                arr[6] <= nums[6];
                arr[7] <= nums[7];
                count_reg <= count;
                state <= 1; // INIT
            end
            // Initialize other variables to 0
            digit_sum_a <=0;
            digit_sum_b <=0;
            swap_occurred <=0;
            pass_num <=0;
            index <=0;
        end else if (state == 1) begin // INIT
            if (count_reg <= 1) begin
                state <= 7; // DONE
                done <= 1;
            end else begin
                pass_num <= 0;
                index <= 0;
                swap_occurred <= 1;
                state <= 2; // COMPARE
            end
            // Initialize other variables
            digit_sum_a <=0;
            digit_sum_b <=0;
            a <=0;
            b <=0;
            a_abs <=0;
            b_abs <=0;
        end else if (state == 2) begin // COMPARE
            // Load current elements
            a = arr[index];
            b = arr[index +1];
            a_abs = a;
            if (a < 0) a_abs = -a;
            b_abs = b;
            if (b < 0) b_abs = -b;
            // Compute digit sums (unrolled)
            digit_sum_a <= (a_abs%10) + (a_abs/10 %10) + (a_abs/100 %10) + (a_abs/1000 %10) + (a_abs/10000 %10);
            digit_sum_b <= (b_abs%10) + (b_abs/10 %10) + (b_abs/100 %10) + (b_abs/1000 %10) + (b_abs/10000 %10);
            state <= 3; // DECIDE
        end else if (state == 3) begin // DECIDE
            if (digit_sum_a > digit_sum_b) begin
                swap_occurred <= 1;
                state <= 4; // SWAP
            end else begin
                swap_occurred <= 0;
                state <= 5; // END_OF_COMPARE
            end
            // Initialize a, b, etc. but they are not used here
            a <=0;
            b <=0;
            a_abs <=0;
            b_abs <=0;
        end else if (state == 4) begin // SWAP
            // Swap the elements
            {arr[index], arr[index + 1]} <= {arr[index + 1], arr[index]};
            state <= 5; // END_OF_COMPARE
            // Initialize temps
            a <=0;
            b <=0;
            a_abs <=0;
            b_abs <=0;
        end else if (state == 5) begin // END_OF_COMPARE
            index <= index + 1;
            if (index < count_reg - 1) begin
                state <= 2; // COMPARE next
            end else begin
                state <= 6; // PASS_DONE
            end
            // Initialize temps
            a <=0;
            b <=0;
            a_abs <=0;
            b_abs <=0;
        end else if (state == 6) begin // PASS_DONE
            if (swap_occurred) begin
                pass_num <= pass_num + 1;
                index <= 0;
                swap_occurred <= 0;
                if (pass_num < count_reg) begin
                    state <= 2; // COMPARE
                end else begin
                    state <= 7; // DONE
                end
            end else begin
                state <= 7; // DONE
            end
            // Initialize temps
            a <=0;
            b <=0;
            a_abs <=0;
            b_abs <=0;
        end else if (state == 7) begin // DONE
            // No action
        end
    end
endmodule