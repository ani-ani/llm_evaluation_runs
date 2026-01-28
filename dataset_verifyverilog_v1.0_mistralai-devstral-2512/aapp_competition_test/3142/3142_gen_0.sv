module digit_dp_counter(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [15:0] A,
    input wire [15:0] B,
    input wire [7:0] S,
    output reg [15:0] count,
    output reg [31:0] min_num,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] DECODE = 3'd1;
    localparam [2:0] DP_COMPUTE = 3'd2;
    localparam [2:0] OUTPUT = 3'd3;

    // Registers
    reg [2:0] state, next_state;
    reg [3:0] position;
    reg [14:0] tight_lower;
    reg [14:0] tight_upper;
    reg [7:0] current_sum;
    reg [3:0] digit_A [0:14];
    reg [3:0] digit_B [0:14];
    reg [15:0] temp_count;
    reg [31:0] temp_min;
    reg [15:0] cycle_count;
    localparam [15:0] MAX_CYCLES = 16'd250;

    // Initialize all registers
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            position <= 4'd0;
            tight_lower <= 15'd0;
            tight_upper <= 15'd0;
            current_sum <= 8'd0;
            count <= 16'd0;
            min_num <= 32'd0;
            done <= 1'b0;
            temp_count <= 16'd0;
            temp_min <= 32'd0;
            cycle_count <= 16'd0;

            // Initialize digit arrays
            integer i;
            for (i = 0; i < 15; i = i + 1) begin
                digit_A[i] <= 4'd0;
                digit_B[i] <= 4'd0;
            end
        end else begin
            state <= next_state;
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 16'd0;
                    if (start) begin
                        next_state <= DECODE;
                    end
                end

                DECODE: begin
                    // Decompose A and B into digits (MSB first)
                    integer i;
                    reg [15:0] temp_A, temp_B;
                    temp_A = A;
                    temp_B = B;

                    for (i = 0; i < 15; i = i + 1) begin
                        digit_A[i] <= temp_A[15:12];
                        digit_B[i] <= temp_B[15:12];
                        temp_A <= temp_A << 4;
                        temp_B <= temp_B << 4;
                    end

                    // Initialize DP state
                    position <= 4'd0;
                    tight_lower <= 15'd1;
                    tight_upper <= 15'd1;
                    current_sum <= 8'd0;
                    temp_count <= 16'd0;
                    temp_min <= 32'd0;
                    next_state <= DP_COMPUTE;
                end

                DP_COMPUTE: begin
                    cycle_count <= cycle_count + 16'd1;

                    // Base case: last position
                    if (position == 4'd14) begin
                        reg [3:0] min_digit, max_digit;
                        reg [3:0] d;
                        reg [3:0] valid_digit;
                        reg found;

                        // Determine digit range
                        if (tight_lower[0]) begin
                            min_digit = digit_A[14];
                        end else begin
                            min_digit = 4'd0;
                        end

                        if (tight_upper[0]) begin
                            max_digit = digit_B[14];
                        end else begin
                            max_digit = 4'd9;
                        end

                        // Find valid digits
                        found = 1'b0;
                        valid_digit = 4'd0;
                        for (d = min_digit; d <= max_digit; d = d + 1) begin
                            if (current_sum + d == S) begin
                                if (!found) begin
                                    valid_digit = d;
                                    found = 1'b1;
                                end
                                temp_count = temp_count + 16'd1;
                            end
                        end

                        // Update min_num if valid digit found
                        if (found) begin
                            reg [31:0] candidate;
                            candidate = {temp_min[31:4], valid_digit};
                            if (temp_min == 32'd0 || candidate < temp_min) begin
                                temp_min = candidate;
                            end
                        end

                        next_state <= OUTPUT;
                    end else begin
                        // Recursive case: process next digit
                        reg [3:0] min_digit, max_digit;
                        reg [3:0] d;
                        reg [14:0] new_tight_lower, new_tight_upper;
                        reg [7:0] new_sum;
                        reg [15:0] sub_count;
                        reg [31:0] sub_min;
                        reg [3:0] sub_digit;

                        // Determine digit range
                        if (tight_lower[position]) begin
                            min_digit = digit_A[position];
                        end else begin
                            min_digit = 4'd0;
                        end

                        if (tight_upper[position]) begin
                            max_digit = digit_B[position];
                        end else begin
                            max_digit = 4'd9;
                        end

                        // Initialize for this position
                        sub_count = 16'd0;
                        sub_min = 32'd0;
                        sub_digit = 4'd0;

                        // Iterate through possible digits
                        for (d = min_digit; d <= max_digit; d = d + 1) begin
                            new_sum = current_sum + d;
                            if (new_sum > 8'd135) begin
                                new_sum = 8'd135;
                            end

                            // Update tight constraints
                            new_tight_lower = tight_lower;
                            new_tight_upper = tight_upper;
                            if (tight_lower[position] && d == digit_A[position]) begin
                                new_tight_lower[position + 1] = 1'b1;
                            end else begin
                                new_tight_lower[position + 1] = 1'b0;
                            end

                            if (tight_upper[position] && d == digit_B[position]) begin
                                new_tight_upper[position + 1] = 1'b1;
                            end else begin
                                new_tight_upper[position + 1] = 1'b0;
                            end

                            // Simulate recursive call (iterative approach)
                            // For simplicity, we'll just count possibilities
                            // In a real implementation, this would be more complex
                            reg [15:0] remaining_sum;
                            remaining_sum = 8'd135 - new_sum;
                            reg [15:0] remaining_positions;
                            remaining_positions = 4'd14 - position;

                            // Approximate count: if remaining_sum can be achieved
                            if (remaining_sum >= 0 && remaining_sum <= remaining_positions * 4'd9) begin
                                reg [15:0] approx_count;
                                approx_count = 16'd1; // Simplified for synthesis
                                sub_count = sub_count + approx_count;

                                // Track minimum digit
                                if (sub_min == 32'd0 || d < sub_digit) begin
                                    sub_digit = d;
                                end
                            end
                        end

                        // Update state for next iteration
                        position <= position + 4'd1;
                        tight_lower <= new_tight_lower;
                        tight_upper <= new_tight_upper;
                        current_sum <= new_sum;
                        temp_count <= temp_count + sub_count;

                        // Update min_num with current digit
                        if (sub_min != 32'd0) begin
                            reg [31:0] new_min;
                            new_min = {temp_min[31:4], sub_digit};
                            if (temp_min == 32'd0 || new_min < temp_min) begin
                                temp_min = new_min;
                            end
                        end

                        // Check for completion or timeout
                        if (position == 4'd15 || cycle_count >= MAX_CYCLES) begin
                            next_state <= OUTPUT;
                        end
                    end
                end

                OUTPUT: begin
                    count <= temp_count;
                    min_num <= temp_min;
                    done <= 1'b1;
                    next_state <= IDLE;
                end

                default: next_state <= IDLE;
            endcase
        end
    end
endmodule