module roman_digits_solver (
    input clk,
    input rst_n,
    input start,
    input [29:0] n,
    output reg [59:0] result,
    output reg done
);

parameter IDLE = 3'b000;
parameter CHECK_RANGE = 3'b001;
parameter COMPUTE_SMALL = 3'b010;
parameter COMPUTE_LARGE = 3'b011;
parameter DONE_STATE = 3'b100;

reg [2:0] state;
reg [4:0] count;

always_ff @(posedge clk) begin
    if (!rst_n) begin
        state <= IDLE;
        count <= 0;
        result <= 0;
        done <= 0;
    end else begin
        case (state)
            IDLE: begin
                if (start) 
                    state <= CHECK_RANGE;
                else 
                    state <= IDLE;
                count <= 0;
                result <= 0;
                done <=0;
            end
            CHECK_RANGE: begin
                if (n <= 20) begin
                    state <= COMPUTE_SMALL;
                    count <= 17;
                end else begin
                    state <= COMPUTE_LARGE;
                    count <= 17;
                end
                result <=0;
                done <=0;
            end
            COMPUTE_SMALL: begin
                case (n)
                    12: result = 341;
                    13: result = 390;
                    14: result = 439;
                    15: result = 488;
                    16: result = 537;
                    17: result = 586;
                    18: result = 635;
                    19: result = 684;
                    20: result = 733;
                    default: result = 0;
                endcase
                if (count == 0) begin
                    state <= DONE_STATE;
                    done <= 1;
                end else begin
                    count <= count - 1;
                    state <= COMPUTE_SMALL;
                end
            end
            COMPUTE_LARGE: begin
                result = (n << 5) + (n << 4) + n - 247;
                if (count == 0) begin
                    state <= DONE_STATE;
                    done <= 1;
                end else begin
                    count <= count - 1;
                    state <= COMPUTE_LARGE;
                end
            end
            DONE_STATE: begin
                if (!start) begin
                    state <= IDLE;
                    count <= 0;
                    done <= 0;
                end else begin
                    state <= DONE_STATE;
                end
                result <= result;
                done <= 1;
            end
        endcase
    end
end
endmodule