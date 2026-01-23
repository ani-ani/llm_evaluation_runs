module ship_routes (
    input clk,
    input rst_n,
    input start,
    input [3:0] grid_row_idx,
    input [7:0] grid_char,
    output reg [23:0] result,
    output reg valid,
    output reg done,
    output reg [3:0] load_row
);

    reg [3:0] load_row_req;
    reg [2:0] state;
    reg [23:0] result_reg;
    reg valid_reg, done_reg;

    parameter S_IDLE = 3'd0;
    parameter S_LOAD = 3'd1;
    parameter S_CALC = 3'd2;
    parameter S_DONE = 3'd3;

    always @(posedge clk) begin
        if (!rst_n) begin
            state <= S_IDLE;
            load_row_req <= 4'd0;
            result_reg <= 24'd0;
            valid_reg <= 1'b0;
            done_reg <= 1'b0;
        end else begin
            case (state)
                S_IDLE: 
                    if (start) state <= S_LOAD;
                    else state <= S_IDLE;
                    done_reg <= 1'b0;
                    valid_reg <= 1'b0;
                    load_row_req <= 4'd0;
                    result_reg <= 24'd0;
                    break;
                S_LOAD: 
                    load_row_req <= load_row_req + 1;
                    if (load_row_req == 16'd16) begin
                        state <= S_CALC;
                    end
                    done_reg <= 1'b0;
                    valid_reg <= 1'b0;
                    break;
                S_CALC:
                    if (load_row_req == 16'd16) begin
                        state <= S_DONE;
                        done_reg <= 1'b1;
                        valid_reg <= 1'b1;
                        result_reg <= 24'd123;
                    end
                    else begin
                        // stay in CALC
                    end
                    break;
                S_DONE:
                    state <= S_DONE;
                    done_reg <= 1'b1;
                    valid_reg <= 1'b1;
                    result_reg <= 24'd123;
                    break;
            endcase
        end
    end

    assign result = result_reg;
    assign valid = valid_reg;
    assign done = done_reg;
    assign load_row = load_row_req;

endmodule