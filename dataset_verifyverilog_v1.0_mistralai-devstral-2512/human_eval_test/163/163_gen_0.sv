module digit_generator(
    input clk,
    input rst_n,
    input start,
    input [7:0] a,
    input [7:0] b,
    output reg [7:0] digits_out [0:4],
    output reg [3:0] count,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE    = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;
    localparam [1:0] FINISH  = 2'd2;

    reg [1:0] state, next_state;
    reg [7:0] a_reg, b_reg;
    reg [7:0] low, high;
    reg [3:0] digit_counter;
    reg [3:0] valid_count;
    reg [7:0] current_digit;
    reg [7:0] temp_digits [0:4];
    reg [3:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd25;

    // State register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            count <= 4'd0;
            done <= 1'b0;
            digit_counter <= 4'd0;
            valid_count <= 4'd0;
            current_digit <= 8'd0;
            cycle_count <= 8'd0;
            a_reg <= 8'd0;
            b_reg <= 8'd0;
            low <= 8'd0;
            high <= 8'd0;
            // Initialize output array
            integer i;
            for (i = 0; i < 5; i = i + 1) begin
                digits_out[i] <= 8'd0;
                temp_digits[i] <= 8'd0;
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
                if (digit_counter == 4'd10 || cycle_count >= MAX_CYCLES) begin
                    next_state = FINISH;
                end
            end
            FINISH: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

    // Data processing
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Already handled in state register
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        a_reg <= a;
                        b_reg <= b;
                        low <= (a_reg < b_reg) ? a_reg : b_reg;
                        high <= (a_reg > b_reg) ? a_reg : b_reg;
                        digit_counter <= 4'd0;
                        valid_count <= 4'd0;
                        current_digit <= 8'd0;
                        // Reset temp array
                        integer i;
                        for (i = 0; i < 5; i = i + 1) begin
                            temp_digits[i] <= 8'd0;
                        end
                    end
                end
                COMPUTE: begin
                    cycle_count <= cycle_count + 8'd1;
                    current_digit <= digit_counter;
                    if (current_digit[0] == 1'b0 && current_digit <= high && current_digit >= low) begin
                        if (valid_count < 5) begin
                            temp_digits[valid_count] <= current_digit;
                            valid_count <= valid_count + 4'd1;
                        end
                    end
                    digit_counter <= digit_counter + 4'd1;
                end
                FINISH: begin
                    done <= 1'b1;
                    count <= valid_count;
                    // Copy temp_digits to output
                    integer i;
                    for (i = 0; i < 5; i = i + 1) begin
                        digits_out[i] <= temp_digits[i];
                    end
                end
                default: begin
                    done <= 1'b0;
                    count <= 4'd0;
                end
            endcase
        end
    end

endmodule