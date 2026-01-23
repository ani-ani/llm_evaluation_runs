module fibfib (
    input clk,
    input rst_n, // active-low reset
    input start,
    input [4:0] n,
    output reg [15:0] result,
    output reg done
);
reg [1:0] state_reg;
reg [4:0] n_reg;
reg [15:0] a_reg, b_reg, c_reg;
reg [3:0] iter_cnt;
reg [15:0] result_reg;
reg done_reg;

always @(posedge clk) begin
    reg [15:0] next_val;
    if (!rst_n) begin
        state_reg <= 2'b00; // IDLE
        n_reg <= 5'b0;
        a_reg <= 16'b0;
        b_reg <= 16'b0;
        c_reg <= 16'b0;
        iter_cnt <= 4'b0;
        result_reg <= 16'b0;
        done_reg <= 1'b0;
    end else begin
        case (state_reg)
            2'b00: // IDLE
                if (start) begin
                    n_reg <= n;
                    state_reg <= 2'b01; // INIT
                end
            endcase
            2'b01: // INIT
                if (n_reg < 3) begin
                    if (n_reg == 2) begin
                        result_reg <= 16'b1;
                    end else begin
                        result_reg <= 16'b0;
                    end
                    done_reg <= 1'b1;
                    state_reg <= 2'b11; // DONE
                end else begin
                    a_reg <= 16'b0;
                    b_reg <= 16'b0;
                    c_reg <= 16'b1;
                    iter_cnt <= n_reg - 2;
                    state_reg <= 2'b10; // COMPUTE
                end
            endcase
            2'b10: // COMPUTE
                next_val = a_reg + b_reg + c_reg;
                a_reg <= b_reg;
                b_reg <= c_reg;
                c_reg <= next_val;
                iter_cnt <= iter_cnt - 1;
                if (iter_cnt == 4'd0) begin
                    result_reg <= next_val;
                    done_reg <= 1'b1;
                    state_reg <= 2'b11; // DONE
                end else begin
                    state_reg <= 2'b10; // stay in COMPUTE
                end
            endcase
            2'b11: // DONE
                state_reg <= 2'b11;
            endcase
        endcase
    end

assign result = result_reg;
assign done = done_reg;
endmodule