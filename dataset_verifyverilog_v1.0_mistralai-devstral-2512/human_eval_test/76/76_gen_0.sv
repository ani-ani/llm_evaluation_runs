module power_checker(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [15:0] x_i,
    input wire [15:0] n_i,
    output reg result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] CHECK_EDGE = 2'd1;
    localparam [1:0] COMPUTE = 2'd2;
    localparam [1:0] DONE_STATE = 2'd3;

    // Internal registers
    reg [1:0] state, next_state;
    reg [15:0] x_reg, n_reg;
    reg [15:0] quotient, remainder;
    reg [3:0] iter_count;
    reg [15:0] temp_x;

    // State transition logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 1'b0;
            done <= 1'b0;
            x_reg <= 16'd0;
            n_reg <= 16'd0;
            quotient <= 16'd0;
            remainder <= 16'd0;
            iter_count <= 4'd0;
            temp_x <= 16'd0;
        end else begin
            state <= next_state;
        end
    end

    // Next state and output logic
    always @(*) begin
        next_state = state;
        result = 1'b0;
        done = 1'b0;

        case (state)
            IDLE: begin
                if (start) begin
                    next_state = CHECK_EDGE;
                    x_reg = x_i;
                    n_reg = n_i;
                end
            end

            CHECK_EDGE: begin
                // Handle edge cases
                if (n_reg == 16'd0) begin
                    // n=0 case: only true if x=1
                    result = (x_reg == 16'd1);
                    next_state = DONE_STATE;
                end else if (x_reg == 16'd1) begin
                    // x=1 is always true
                    result = 1'b1;
                    next_state = DONE_STATE;
                end else if (x_reg == 16'd0) begin
                    // x=0 is false (except n=0 handled above)
                    result = 1'b0;
                    next_state = DONE_STATE;
                end else begin
                    // Normal case: initialize for computation
                    temp_x = x_reg;
                    iter_count = 4'd0;
                    next_state = COMPUTE;
                end
            end

            COMPUTE: begin
                // Perform division
                if (temp_x >= n_reg) begin
                    quotient = temp_x / n_reg;
                    remainder = temp_x % n_reg;
                end else begin
                    quotient = 16'd0;
                    remainder = temp_x;
                end

                // Check remainder
                if (remainder != 16'd0) begin
                    result = 1'b0;
                    next_state = DONE_STATE;
                end else if (quotient == 16'd1) begin
                    result = 1'b1;
                    next_state = DONE_STATE;
                end else if (iter_count == 4'd15) begin
                    // Max iterations reached
                    result = 1'b0;
                    next_state = DONE_STATE;
                end else begin
                    // Continue computation
                    temp_x = quotient;
                    iter_count = iter_count + 4'd1;
                end
            end

            DONE_STATE: begin
                done = 1'b1;
                next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
    end

endmodule