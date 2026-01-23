module special_factorial (
    input clk,
    input rst_n,
    input start,
    input [3:0] n,
    output reg [31:0] result,
    output reg done
);

    parameter IDLE = 2'd0,
    CALCULATE = 2'd1,
    MULTIPLY = 2'd2,
    DONE_STATE = 3'd3;

    reg [1:0] state;
    reg [31:0] result_reg;
    reg [2:0] current_i;

    // Combinational temp_fact
    wire [31:0] temp_fact;
    assign temp_fact = case (current_i)
        1: 1;
        2: 2;
        3: 6;
        4: 24;
        default: 1;
    endcase

    always @(posedge clk) begin
        if (!rst_n) begin
            state <= IDLE;
            result_reg <= 32'd1;
            current_i <= 1;
            result <= 32'd1;
            done <= 0;
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        state <= CALCULATE;
                    end else begin
                        state <= IDLE;
                    end
                end
                CALCULATE: begin
                    state <= MULTIPLY;
                end
                MULTIPLY: begin
                    result_reg = result_reg * temp_fact;
                    result = result_reg;
                    if (current_i < n) begin
                        current_i <= current_i + 1;
                        state <= CALCULATE;
                    end else begin
                        state <= DONE_STATE;
                    end
                end
                DONE_STATE: begin
                    state <= DONE_STATE;
                    done <= 1;
                end
            endcase
        end
    end

    endmodule