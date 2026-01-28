module digit_sum_counter(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire signed [7:0] arr [0:15],
    input wire [3:0] len,
    output reg [4:0] result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE    = 3'd0;
    localparam [2:0] LOAD    = 3'd1;
    localparam [2:0] CALC    = 3'd2;
    localparam [2:0] CHECK   = 3'd3;
    localparam [2:0] DONE_STATE = 3'd4;

    // Internal registers
    reg [2:0] state, next_state;
    reg [3:0] index;
    reg signed [7:0] current_num;
    reg [7:0] abs_num;
    reg signed [7:0] digit_sum;
    reg [7:0] temp_num;
    reg [3:0] digit_count;
    reg [7:0] abs_digit_sum;
    reg [7:0] first_digit;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd1000;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 5'd0;
            done <= 1'b0;
            index <= 4'd0;
            current_num <= 8'd0;
            abs_num <= 8'd0;
            digit_sum <= 8'd0;
            temp_num <= 8'd0;
            digit_count <= 4'd0;
            abs_digit_sum <= 8'd0;
            first_digit <= 8'd0;
            cycle_count <= 8'd0;
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
                    next_state = LOAD;
                end
            end

            LOAD: begin
                next_state = CALC;
            end

            CALC: begin
                if (digit_count == 4'd0) begin
                    next_state = CHECK;
                end
            end

            CHECK: begin
                next_state = LOAD;
                if (index == len - 1'b1) begin
                    next_state = DONE_STATE;
                end
            end

            DONE_STATE: begin
                next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
    end

    // Load current number
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_num <= 8'd0;
            abs_num <= 8'd0;
            temp_num <= 8'd0;
            digit_count <= 4'd0;
            abs_digit_sum <= 8'd0;
            first_digit <= 8'd0;
        end else begin
            if (state == LOAD) begin
                current_num <= arr[index];
                abs_num <= (current_num[7] == 1'b1) ? -current_num : current_num;
                temp_num <= abs_num;
                digit_count <= 4'd0;
                abs_digit_sum <= 8'd0;
                first_digit <= 8'd0;
            end
        end
    end

    // Calculate digit sum
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            digit_sum <= 8'd0;
        end else begin
            if (state == CALC) begin
                if (digit_count == 4'd0) begin
                    first_digit <= temp_num % 10;
                    abs_digit_sum <= first_digit;
                    temp_num <= temp_num / 10;
                    digit_count <= digit_count + 1'b1;
                end else if (digit_count < 4'd3) begin
                    abs_digit_sum <= abs_digit_sum + (temp_num % 10);
                    temp_num <= temp_num / 10;
                    digit_count <= digit_count + 1'b1;
                end else begin
                    if (current_num[7] == 1'b1) begin
                        digit_sum <= $signed(abs_digit_sum) - $signed(first_digit * 2);
                    end else begin
                        digit_sum <= $signed(abs_digit_sum);
                    end
                end
            end
        end
    end

    // Check and update result
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            index <= 4'd0;
        end else begin
            if (state == CHECK) begin
                if (digit_sum > 8'd0) begin
                    result <= result + 1'b1;
                end
                index <= index + 1'b1;
            end
        end
    end

    // Done signal
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            done <= 1'b0;
        end else begin
            if (state == DONE_STATE) begin
                done <= 1'b1;
            end else begin
                done <= 1'b0;
            end
        end
    end

    // Cycle counter for safety
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cycle_count <= 8'd0;
        end else begin
            if (state != IDLE) begin
                cycle_count <= cycle_count + 1'b1;
                if (cycle_count >= MAX_CYCLES) begin
                    next_state = IDLE;
                    done <= 1'b1;
                end
            end
        end
    end

endmodule