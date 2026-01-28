module digit_rotation_finder(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [15:0] x_in,
    input wire [15:0] start_num,
    output reg [31:0] found_num,
    output reg found_valid,
    output reg done,
    output reg [7:0] solution_count
);

    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] SEARCHING = 3'd1;
    localparam [2:0] CHECKING = 3'd2;
    localparam [2:0] OUTPUT = 3'd3;
    localparam [2:0] DONE_STATE = 3'd4;

    // Fixed-point constants
    localparam [15:0] EPSILON = 16'd2;  // 0.01 in Q8.8 (2/256)
    localparam [15:0] MAX_X = 16'd65536;  // 256.0 in Q8.8

    // Registers
    reg [2:0] state, next_state;
    reg [7:0] cycle_count;
    reg [31:0] current_num;
    reg [7:0] current_length;
    reg [31:0] rotated_num;
    reg [23:0] product_fixed;
    reg [31:0] result_buffer [0:7];
    reg [7:0] buffer_count;
    reg [7:0] output_index;
    reg [31:0] temp_num;
    reg [7:0] digit_pos;
    reg [31:0] power_10 [0:7];
    reg [31:0] first_digit;
    reg [31:0] remaining_digits;
    reg [31:0] temp_rotated;
    reg [23:0] temp_product;
    reg [23:0] diff;
    reg [7:0] i, j;

    // Initialize power_10 array
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            power_10[0] <= 32'd1;
            power_10[1] <= 32'd10;
            power_10[2] <= 32'd100;
            power_10[3] <= 32'd1000;
            power_10[4] <= 32'd10000;
            power_10[5] <= 32'd100000;
            power_10[6] <= 32'd1000000;
            power_10[7] <= 32'd10000000;
        end
    end

    // Main state machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            cycle_count <= 8'd0;
            current_num <= 32'd0;
            current_length <= 8'd0;
            rotated_num <= 32'd0;
            product_fixed <= 24'd0;
            buffer_count <= 8'd0;
            output_index <= 8'd0;
            temp_num <= 32'd0;
            digit_pos <= 8'd0;
            first_digit <= 32'd0;
            remaining_digits <= 32'd0;
            temp_rotated <= 32'd0;
            temp_product <= 24'd0;
            diff <= 24'd0;
            found_num <= 32'd0;
            found_valid <= 1'b0;
            done <= 1'b0;
            solution_count <= 8'd0;
        end else begin
            state <= next_state;
            cycle_count <= cycle_count + 8'd1;

            case (state)
                IDLE: begin
                    found_valid <= 1'b0;
                    done <= 1'b0;
                    solution_count <= 8'd0;
                    if (start) begin
                        next_state <= SEARCHING;
                        current_num <= {16'd0, start_num};
                        current_length <= 8'd1;
                        buffer_count <= 8'd0;
                        output_index <= 8'd0;
                        cycle_count <= 8'd0;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                SEARCHING: begin
                    if (current_length > 8'd8) begin
                        next_state <= OUTPUT;
                    end else begin
                        // Generate numbers for current length
                        if (current_num >= power_10[current_length]) begin
                            // Move to next length
                            current_length <= current_length + 8'd1;
                            current_num <= power_10[current_length - 8'd1];
                        end else begin
                            // Check if number has correct length
                            if (current_num >= power_10[current_length - 8'd1]) begin
                                next_state <= CHECKING;
                            end else begin
                                current_num <= current_num + 32'd1;
                            end
                        end
                    end
                end

                CHECKING: begin
                    // Extract first digit and remaining digits
                    first_digit <= current_num / power_10[current_length - 8'd1];
                    remaining_digits <= current_num % power_10[current_length - 8'd1];

                    // Compute rotated number
                    temp_rotated <= remaining_digits * 32'd10 + first_digit;

                    // Compute N * X in fixed-point (Q16.8)
                    temp_product <= current_num * x_in;

                    // Compare with rotated number (scaled to Q16.8)
                    diff <= (temp_product >> 8) - (temp_rotated << 8);

                    // Check if difference is within epsilon
                    if (diff < 24'd0) begin
                        diff <= -diff;
                    end

                    if (diff < EPSILON) begin
                        // Found a solution
                        if (buffer_count < 8'd8) begin
                            result_buffer[buffer_count] <= current_num;
                            buffer_count <= buffer_count + 8'd1;
                        end
                    end

                    // Move to next number
                    current_num <= current_num + 32'd1;
                    next_state <= SEARCHING;
                end

                OUTPUT: begin
                    if (output_index < buffer_count) begin
                        found_num <= result_buffer[output_index];
                        found_valid <= 1'b1;
                        output_index <= output_index + 8'd1;
                        solution_count <= buffer_count;
                    end else begin
                        found_valid <= 1'b0;
                        next_state <= DONE_STATE;
                    end
                end

                DONE_STATE: begin
                    done <= 1'b1;
                    next_state <= IDLE;
                end

                default: begin
                    next_state <= IDLE;
                end
            endcase

            // Timeout check (1000 cycles)
            if (cycle_count >= 8'd1000 && state != IDLE && state != DONE_STATE) begin
                next_state <= DONE_STATE;
            end
        end
    end

endmodule