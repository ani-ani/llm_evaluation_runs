module CountDigits (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire signed [15:0] nums [0:15],
    output reg [7:0] count,
    output reg done
);

    // State definitions
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] PROCESSING = 2'd1;
    localparam [1:0] DONE_STATE = 2'd2;

    reg [1:0] state, next_state;
    reg [3:0] index;          // 0 to 15
    reg [7:0] next_count;
    reg signed [15:0] abs_val;
    reg [3:0] first_digit;
    reg [3:0] last_digit;
    reg is_odd_first;
    reg is_odd_last;
    reg is_gt_10;
    reg valid_element;
    reg next_done;
    reg start_dly;

    // Edge detection for start pulse
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            start_dly <= 1'b0;
        end else begin
            start_dly <= start;
        end
    end

    // Combinational logic for digit extraction and checking
    always @(*) begin
        // Default values
        abs_val = 16'sd0;
        first_digit = 4'd0;
        last_digit = 4'd0;
        is_odd_first = 1'b0;
        is_odd_last = 1'b0;
        is_gt_10 = 1'b0;
        valid_element = 1'b0;

        // Absolute value computation with overflow handling for -32768
        if (state == PROCESSING) begin
            if (nums[index][15] == 1'b1 && nums[index] == 16'sh8000) begin
                // Special case: -32768 -> clamp to 32767
                abs_val = 16'sd32767;
            end else if (nums[index][15] == 1'b1) begin
                abs_val = -nums[index];
            end else begin
                abs_val = nums[index];
            end

            // Check num > 10 (signed comparison)
            if (nums[index] > 16'sd10) begin
                is_gt_10 = 1'b1;

                // Extract digits only if |num| > 9
                // last digit = abs_val % 10
                // first digit = abs_val / 10 % 10
                first_digit = (abs_val / 10) % 10;
                last_digit = abs_val % 10;

                // Check oddness (LSB == 1)
                is_odd_first = first_digit[0];
                is_odd_last = last_digit[0];

                // Both digits must be odd
                if (is_odd_first && is_odd_last) begin
                    valid_element = 1'b1;
                end
            end
        end
    end

    // State transition logic
    always @(*) begin
        next_state = state;
        next_count = count;
        next_done = 1'b0;

        case (state)
            IDLE: begin
                // Wait for start pulse
                if (start && !start_dly) begin
                    next_state = PROCESSING;
                    next_count = 8'd0;
                    next_done = 1'b0;
                end
            end

            PROCESSING: begin
                // Process element at current index
                if (valid_element) begin
                    next_count = count + 8'd1;
                end

                // Check if we've processed all 16 elements (0-15)
                if (index == 4'd15) begin
                    next_state = DONE_STATE;
                    next_done = 1'b1;
                end
            end

            DONE_STATE: begin
                // Done pulse is asserted, return to IDLE
                next_state = IDLE;
                next_done = 1'b0;
            end

            default: begin
                next_state = IDLE;
                next_count = 8'd0;
                next_done = 1'b0;
            end
        endcase
    end

    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset takes 2 cycles
            // First cycle: set internal registers
            state <= IDLE;
            index <= 4'd0;
            count <= 8'd0;
            done <= 1'b0;
        end else begin
            state <= next_state;
            count <= next_count;
            done <= next_done;

            // Index counter logic
            if (state == IDLE && start && !start_dly) begin
                index <= 4'd0;
            end else if (state == PROCESSING) begin
                if (index < 4'd15) begin
                    index <= index + 4'd1;
                end
            end else if (state == DONE_STATE) begin
                index <= 4'd0;
            end
        end
    end

endmodule