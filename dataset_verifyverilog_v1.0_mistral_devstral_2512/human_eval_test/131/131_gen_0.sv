module digits_product(
    input clk,
    input rst_n,
    input start,
    input [23:0] n,
    output reg [15:0] result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] PROCESS = 3'd1;
    localparam [2:0] CHECK = 3'd2;
    localparam [2:0] MULTIPLY = 3'd3;
    localparam [2:0] SUBTRACT = 3'd4;
    localparam [2:0] DONE = 3'd5;

    reg [2:0] state, next_state;
    reg [23:0] temp_n;
    reg [3:0] digit;
    reg [3:0] stored_digit;
    reg any_odd;
    reg [23:0] subtract_count;
    reg [23:0] subtract_temp;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            temp_n <= 24'd0;
            digit <= 4'd0;
            stored_digit <= 4'd0;
            any_odd <= 1'b0;
            subtract_count <= 24'd0;
            subtract_temp <= 24'd0;
        end else begin
            state <= next_state;
        end
    end

    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                done = 1'b0;
                if (start) begin
                    temp_n = n;
                    result = 16'd1;
                    any_odd = 1'b0;
                    next_state = PROCESS;
                end
            end

            PROCESS: begin
                if (temp_n > 24'd0) begin
                    digit = temp_n % 10;
                    subtract_temp = temp_n;
                    subtract_count = 24'd0;
                    next_state = SUBTRACT;
                end else begin
                    next_state = DONE;
                end
            end

            SUBTRACT: begin
                if (subtract_temp >= 24'd10) begin
                    subtract_temp = subtract_temp - 24'd10;
                    subtract_count = subtract_count + 24'd1;
                end else begin
                    temp_n = subtract_count;
                    next_state = CHECK;
                end
            end

            CHECK: begin
                if (digit[0] == 1'b1) begin
                    stored_digit = digit;
                    next_state = MULTIPLY;
                end else begin
                    next_state = PROCESS;
                end
            end

            MULTIPLY: begin
                result = result * stored_digit;
                any_odd = 1'b1;
                next_state = PROCESS;
            end

            DONE: begin
                if (!any_odd) begin
                    result = 16'd0;
                end
                done = 1'b1;
                next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
    end

endmodule