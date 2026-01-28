module balance_checker(
    input clk,
    input rst_n,
    input start,
    input ops_valid,
    input signed [7:0] op,
    output reg below_zero,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] PROCESSING = 2'd1;
    localparam [1:0] DONE_STATE = 2'd2;

    // Internal signals
    reg [1:0] state, next_state;
    reg signed [15:0] accumulator;
    reg [3:0] op_count;
    localparam [3:0] MAX_OPS = 4'd16;

    // State register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            accumulator <= 16'd0;
            below_zero <= 1'b0;
            done <= 1'b0;
            op_count <= 4'd0;
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
                    next_state = PROCESSING;
                    accumulator = 16'd0;
                    below_zero = 1'b0;
                    op_count = 4'd0;
                end
            end
            PROCESSING: begin
                if (!ops_valid || op_count >= MAX_OPS) begin
                    next_state = DONE_STATE;
                end
            end
            DONE_STATE: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

    // Processing logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            accumulator <= 16'd0;
            op_count <= 4'd0;
        end else if (state == PROCESSING && ops_valid) begin
            accumulator <= accumulator + {{8{op[7]}}, op};
            op_count <= op_count + 4'd1;
            if (accumulator < 16'd0) begin
                below_zero <= 1'b1;
            end
        end
    end

    // Done signal generation
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            done <= 1'b0;
        end else begin
            done <= (state == DONE_STATE);
        end
    end

endmodule