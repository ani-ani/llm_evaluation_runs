module tribonacci(
    input clk,
    input rst_n,
    input start,
    input [4:0] n_in,
    output reg [31:0] result,
    output reg valid,
    output reg done
);

    // State declarations
    localparam [3:0] IDLE       = 4'd0;
    localparam [3:0] OUT_0      = 4'd1;
    localparam [3:0] OUT_1      = 4'd2;
    localparam [3:0] LOOP_START = 4'd3;
    localparam [3:0] OUT_EVEN   = 4'd4;
    localparam [3:0] CALC_ODD    = 4'd5;
    localparam [3:0] OUT_ODD     = 4'd6;
    localparam [3:0] NEXT_ITER   = 4'd7;
    localparam [3:0] DONE_STATE  = 4'd8;

    reg [3:0] state, next_state;
    reg [4:0] current_index;
    reg [4:0] target_n;
    reg [4:0] k;
    reg [31:0] prev_odd;
    reg [31:0] calculated_odd;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 32'd0;
            valid <= 1'b0;
            done <= 1'b0;
            current_index <= 5'd0;
            target_n <= 5'd0;
            k <= 5'd0;
            prev_odd <= 32'd0;
            calculated_odd <= 32'd0;
        end else begin
            state <= next_state;
        end
    end

    always @(*) begin
        case (state)
            IDLE: begin
                valid = 1'b0;
                done = 1'b0;
                if (start) begin
                    next_state = OUT_0;
                    target_n = n_in;
                    current_index = 5'd0;
                end else begin
                    next_state = IDLE;
                end
            end

            OUT_0: begin
                result = 32'd1;
                valid = 1'b1;
                done = 1'b0;
                current_index = 5'd0;
                if (target_n == 5'd0) begin
                    next_state = DONE_STATE;
                end else begin
                    next_state = OUT_1;
                end
            end

            OUT_1: begin
                result = 32'd3;
                valid = 1'b1;
                done = 1'b0;
                current_index = 5'd1;
                if (target_n == 5'd1) begin
                    next_state = DONE_STATE;
                end else begin
                    next_state = LOOP_START;
                end
            end

            LOOP_START: begin
                valid = 1'b0;
                done = 1'b0;
                k = 5'd1;
                prev_odd = 32'd3;
                next_state = OUT_EVEN;
            end

            OUT_EVEN: begin
                result = 32'd1 + k;
                valid = 1'b1;
                done = 1'b0;
                current_index = 5'd2 + k;
                if (current_index == target_n) begin
                    next_state = DONE_STATE;
                end else begin
                    next_state = CALC_ODD;
                end
            end

            CALC_ODD: begin
                valid = 1'b0;
                done = 1'b0;
                calculated_odd = 32'd3 + (32'd2 * k) + prev_odd;
                next_state = OUT_ODD;
            end

            OUT_ODD: begin
                result = calculated_odd;
                valid = 1'b1;
                done = 1'b0;
                current_index = 5'd3 + k;
                if (current_index == target_n) begin
                    next_state = DONE_STATE;
                end else begin
                    next_state = NEXT_ITER;
                end
            end

            NEXT_ITER: begin
                valid = 1'b0;
                done = 1'b0;
                k = k + 5'd1;
                prev_odd = calculated_odd;
                next_state = OUT_EVEN;
            end

            DONE_STATE: begin
                valid = 1'b0;
                done = 1'b1;
                next_state = IDLE;
            end

            default: begin
                valid = 1'b0;
                done = 1'b0;
                next_state = IDLE;
            end
        endcase
    end

endmodule