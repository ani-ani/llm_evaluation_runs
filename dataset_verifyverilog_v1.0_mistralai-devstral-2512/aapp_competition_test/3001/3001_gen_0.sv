module PalindromeCounter(
    input clk,
    input rst_n,
    input start,
    input [3:0] digits_in [0:15],
    output reg [15:0] result,
    output reg done
);

    // State definitions
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;
    localparam [1:0] DONE_STATE = 2'd2;

    // Internal registers
    reg [1:0] state, next_state;
    reg [15:0] cycle_count;
    reg [15:0] min_steps;
    reg [15:0] current_val;
    reg [15:0] palindrome_val;
    reg [15:0] steps;
    reg [3:0] digits [0:15];
    reg [3:0] temp_digits [0:15];
    reg [3:0] k;
    reg [3:0] i, j;
    reg [3:0] half_len;
    reg [3:0] mid;
    reg carry;
    reg [15:0] pow10 [0:15];
    reg [15:0] temp_val;
    reg [15:0] temp_pal;
    reg [15:0] temp_steps;
    reg [15:0] temp_min;
    reg [15:0] max_cycles;

    // Initialize pow10 array
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pow10[0] <= 16'd1;
            for (i = 1; i < 16; i = i + 1) begin
                pow10[i] <= pow10[i-1] * 16'd10;
            end
        end
    end

    // Main state machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            cycle_count <= 16'd0;
            min_steps <= 16'd65535;
            current_val <= 16'd0;
            palindrome_val <= 16'd0;
            steps <= 16'd0;
            k <= 4'd0;
            i <= 4'd0;
            j <= 4'd0;
            half_len <= 4'd0;
            mid <= 4'd0;
            carry <= 1'b0;
            temp_val <= 16'd0;
            temp_pal <= 16'd0;
            temp_steps <= 16'd0;
            temp_min <= 16'd0;
            max_cycles <= 16'd1000;
            for (i = 0; i < 16; i = i + 1) begin
                digits[i] <= 4'd0;
                temp_digits[i] <= 4'd0;
            end
        end else begin
            state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = COMPUTE;
                end
            end
            COMPUTE: begin
                if (cycle_count >= max_cycles) begin
                    next_state = DONE_STATE;
                end
            end
            DONE_STATE: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

    // Compute current value
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_val <= 16'd0;
        end else if (state == COMPUTE && cycle_count == 16'd0) begin
            current_val <= 16'd0;
            for (i = 0; i < 16; i = i + 1) begin
                digits[i] <= digits_in[i];
            end
            for (i = 0; i < 16; i = i + 1) begin
                if (digits_in[i] != 4'd0) begin
                    k <= i + 4'd1;
                end
            end
            if (k == 4'd0) begin
                k <= 4'd1;
            end
            for (i = 0; i < k; i = i + 1) begin
                current_val <= current_val + (digits_in[i] * pow10[k - 1 - i]);
            end
        end
    end

    // Generate palindrome and compute steps
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            palindrome_val <= 16'd0;
            steps <= 16'd0;
        end else if (state == COMPUTE) begin
            if (cycle_count == 16'd0) begin
                min_steps <= 16'd65535;
            end
            if (cycle_count < max_cycles) begin
                // Generate next palindrome
                half_len <= (k + 4'd1) / 2;
                mid <= k / 2;
                for (i = 0; i < half_len; i = i + 1) begin
                    temp_digits[i] <= digits[i];
                end
                for (i = half_len; i < k; i = i + 1) begin
                    temp_digits[i] <= temp_digits[k - 1 - i];
                end
                temp_pal <= 16'd0;
                for (i = 0; i < k; i = i + 1) begin
                    temp_pal <= temp_pal + (temp_digits[i] * pow10[k - 1 - i]);
                end
                if (temp_pal < current_val) begin
                    // Increment the middle digit
                    carry <= 1'b1;
                    for (i = mid; i >= 0 && carry; i = i - 1) begin
                        if (temp_digits[i] == 4'd9) begin
                            temp_digits[i] <= 4'd0;
                            carry <= 1'b1;
                        end else begin
                            temp_digits[i] <= temp_digits[i] + 4'd1;
                            carry <= 1'b0;
                        end
                    end
                    // Mirror again
                    for (i = half_len; i < k; i = i + 1) begin
                        temp_digits[i] <= temp_digits[k - 1 - i];
                    end
                    temp_pal <= 16'd0;
                    for (i = 0; i < k; i = i + 1) begin
                        temp_pal <= temp_pal + (temp_digits[i] * pow10[k - 1 - i]);
                    end
                end
                // Compute steps
                if (temp_pal >= current_val) begin
                    temp_steps <= temp_pal - current_val;
                end else begin
                    temp_steps <= temp_pal + (pow10[k] - current_val);
                end
                // Update min_steps
                if (temp_steps < min_steps) begin
                    min_steps <= temp_steps;
                end
                // Increment cycle count
                cycle_count <= cycle_count + 16'd1;
            end
        end
    end

    // Output result and done
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            result <= 16'd0;
            done <= 1'b0;
        end else if (state == DONE_STATE) begin
            result <= min_steps;
            done <= 1'b1;
        end else begin
            done <= 1'b0;
        end
    end

endmodule