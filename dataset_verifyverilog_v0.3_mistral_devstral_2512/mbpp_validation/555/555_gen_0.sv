module difference_calculator(
    input clk,
    input rst_n,
    input start,
    input [5:0] n,
    output reg [31:0] result,
    output reg done
);

    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;
    localparam [1:0] OUTPUT = 2'd2;

    reg [1:0] state;
    reg [1:0] next_state;

    wire [31:0] S;
    wire [31:0] S_minus_1;

    assign S = n * (n + 6'd1) / 6'd2;
    assign S_minus_1 = S - 32'd1;

    always @(*) begin
        case (state)
            IDLE: begin
                if (start)
                    next_state = COMPUTE;
                else
                    next_state = IDLE;
            end
            COMPUTE: next_state = OUTPUT;
            OUTPUT: next_state = IDLE;
            default: next_state = IDLE;
        endcase
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 32'd0;
            done <= 1'b0;
        end else begin
            state <= next_state;
            case (state)
                IDLE: begin
                    done <= 1'b0;
                end
                COMPUTE: begin
                    result <= S * S_minus_1;
                end
                OUTPUT: begin
                    done <= 1'b1;
                end
                default: begin
                    result <= 32'd0;
                    done <= 1'b0;
                end
            endcase
        end
    end

endmodule