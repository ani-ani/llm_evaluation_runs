module ArmstrongNumberChecker(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [15:0] number,
    output reg result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] COUNT_DIGITS = 3'd1;
    localparam [2:0] CALCULATE_SUM = 3'd2;
    localparam [2:0] DONE_STATE = 3'd3;

    // Internal registers
    reg [2:0] state, next_state;
    reg [3:0] digit_count;
    reg [15:0] temp_number;
    reg [31:0] sum;
    reg [3:0] current_digit;
    reg [3:0] exponent_counter;
    reg [3:0] digit_counter;
    reg [31:0] power_result;
    reg [3:0] cycle_count;
    localparam [3:0] MAX_CYCLES = 4'd40;

    // State transition logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            digit_count <= 4'd0;
            temp_number <= 16'd0;
            sum <= 32'd0;
            current_digit <= 4'd0;
            exponent_counter <= 4'd0;
            digit_counter <= 4'd0;
            power_result <= 32'd0;
            cycle_count <= 4'd0;
            result <= 1'b0;
            done <= 1'b0;
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
                    next_state = COUNT_DIGITS;
                end
            end

            COUNT_DIGITS: begin
                if (digit_counter == digit_count || digit_counter == 4'd5) begin
                    next_state = CALCULATE_SUM;
                end
            end

            CALCULATE_SUM: begin
                if (digit_counter == digit_count || digit_counter == 4'd5) begin
                    next_state = DONE_STATE;
                end
            end

            DONE_STATE: begin
                next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
    end

    // Digit counting phase
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            digit_count <= 4'd0;
            temp_number <= 16'd0;
            digit_counter <= 4'd0;
        end else if (state == COUNT_DIGITS) begin
            if (digit_counter == 4'd0) begin
                temp_number <= number;
                digit_count <= 4'd0;
            end

            if (temp_number != 16'd0) begin
                digit_count <= digit_count + 4'd1;
                temp_number <= temp_number / 16'd10;
            end

            digit_counter <= digit_counter + 4'd1;
        end
    end

    // Sum calculation phase
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sum <= 32'd0;
            temp_number <= 16'd0;
            current_digit <= 4'd0;
            exponent_counter <= 4'd0;
            digit_counter <= 4'd0;
            power_result <= 32'd0;
        end else if (state == CALCULATE_SUM) begin
            if (digit_counter == 4'd0) begin
                temp_number <= number;
                sum <= 32'd0;
            end

            // Extract current digit
            if (exponent_counter == 4'd0) begin
                current_digit <= temp_number % 16'd10;
                temp_number <= temp_number / 16'd10;
                power_result <= 32'd1;
            end

            // Calculate power: current_digit ^ digit_count
            if (exponent_counter < digit_count) begin
                power_result <= power_result * current_digit;
                exponent_counter <= exponent_counter + 4'd1;
            end else begin
                sum <= sum + power_result;
                exponent_counter <= 4'd0;
                digit_counter <= digit_counter + 4'd1;
            end
        end
    end

    // Done and result logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            done <= 1'b0;
            result <= 1'b0;
            cycle_count <= 4'd0;
        end else begin
            done <= 1'b0;
            if (state == DONE_STATE) begin
                done <= 1'b1;
                if (sum == number) begin
                    result <= 1'b1;
                end else begin
                    result <= 1'b0;
                end
            end

            // Cycle counter for safety
            if (state != IDLE) begin
                cycle_count <= cycle_count + 4'd1;
                if (cycle_count >= MAX_CYCLES) begin
                    next_state = IDLE;
                    cycle_count <= 4'd0;
                end
            end
        end
    end

endmodule