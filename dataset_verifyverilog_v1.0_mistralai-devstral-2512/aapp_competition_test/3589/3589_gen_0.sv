module digit_product_distribution(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [15:0] L,
    input wire [15:0] R,
    output reg [15:0] count [0:8],
    output reg done
);

    // State definitions
    localparam [3:0] IDLE      = 4'd0;
    localparam [3:0] COMPUTE   = 4'd1;
    localparam [3:0] FINISH    = 4'd2;

    // Internal registers
    reg [3:0] state;
    reg [15:0] current_number;
    reg [15:0] cycle_counter;
    localparam [15:0] MAX_CYCLES = 16'd256;

    // Digit product computation
    reg [31:0] product;
    reg [3:0] digit_index;
    reg [7:0] current_digit;
    reg [3:0] non_zero_digits;

    // Initialize all registers
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            current_number <= 16'd0;
            cycle_counter <= 16'd0;
            product <= 32'd0;
            digit_index <= 4'd0;
            current_digit <= 8'd0;
            non_zero_digits <= 4'd0;

            // Initialize count array
            integer i;
            for (i = 0; i < 9; i = i + 1) begin
                count[i] <= 16'd0;
            end

            done <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_counter <= 16'd0;
                    if (start) begin
                        state <= COMPUTE;
                        current_number <= L;
                        product <= 32'd0;
                        digit_index <= 4'd0;
                        non_zero_digits <= 4'd0;
                    end
                end

                COMPUTE: begin
                    cycle_counter <= cycle_counter + 16'd1;

                    // Process current number
                    if (digit_index == 4'd0) begin
                        // Start processing new number
                        product <= 32'd1;
                        non_zero_digits <= 4'd0;
                    end

                    // Extract current digit
                    current_digit <= current_number[(digit_index * 4) +: 4];

                    // Process digit
                    if (current_digit != 8'd0) begin
                        product <= product * current_digit;
                        non_zero_digits <= non_zero_digits + 4'd1;
                    end

                    // Move to next digit
                    digit_index <= digit_index + 4'd1;

                    // Check if all digits processed
                    if (digit_index == 4'd5) begin
                        digit_index <= 4'd0;

                        // Compute final digit
                        if (non_zero_digits > 4'd0) begin
                            // Reduce product to single digit
                            reg [31:0] temp_product = product;
                            while (temp_product >= 10) begin
                                temp_product = temp_product / 10 + temp_product % 10;
                            end

                            // Update count
                            if (temp_product >= 1 && temp_product <= 9) begin
                                count[temp_product - 1] <= count[temp_product - 1] + 16'd1;
                            end
                        end

                        // Move to next number
                        if (current_number == R) begin
                            state <= FINISH;
                        end else begin
                            current_number <= current_number + 16'd1;
                        end
                    end

                    // Safety check for max cycles
                    if (cycle_counter >= MAX_CYCLES) begin
                        state <= FINISH;
                    end
                end

                FINISH: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule