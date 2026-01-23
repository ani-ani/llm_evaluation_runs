module bank_account_checker (
    input clk,
    input rst_n,
    input start,
    input valid_in,
    input signed [15:0] operation,
    output reg balance_below_zero,
    output reg done
);

    // State encoding
    localparam IDLE = 2'b00;
    localparam PROCESSING = 2'b01;
    localparam DONE = 2'b10;

    reg [1:0] current_state, next_state;
    reg signed [15:0] balance, next_balance;
    reg next_balance_below_zero;
    reg next_done;

    // State register and sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            balance <= 16'sd0;
            balance_below_zero <= 1'b0;
            done <= 1'b0;
        end else begin
            current_state <= next_state;
            balance <= next_balance;
            balance_below_zero <= next_balance_below_zero;
            done <= next_done;
        end
    end

    // Next state logic
    always @(*) begin
        // Default assignments
        next_state = current_state;
        next_balance = balance;
        next_balance_below_zero = balance_below_zero;
        next_done = done;

        case (current_state)
            IDLE: begin
                next_balance = 16'sd0;
                next_balance_below_zero = 1'b0;
                next_done = 1'b0;
                if (start) begin
                    next_state = PROCESSING;
                end
            end

            PROCESSING: begin
                if (valid_in) begin
                    next_balance = balance + operation;
                    if (next_balance < 0) begin
                        next_balance_below_zero = 1'b1;
                    end
                end else begin
                    next_state = DONE;
                    next_done = 1'b1;
                end
            end

            DONE: begin
                // Wait in DONE state until start is asserted
                if (start) begin
                    next_state = PROCESSING;
                    next_balance = 16'sd0;
                    next_balance_below_zero = 1'b0;
                    next_done = 1'b0;
                end
            end

            default: begin
                next_state = IDLE;
                next_balance = 16'sd0;
                next_balance_below_zero = 1'b0;
                next_done = 1'b0;
            end
        endcase
    end

endmodule