module max_chessmen (
    input clk,
    input rst_n,
    input start,
    input [3:0] n,
    input [3:0] m,
    output reg [31:0] result,
    output reg done
);

wire eff_n, eff_m;
assign eff_n = (n > m) ? m : n;
assign eff_m = (n > m) ? n : m;

localparam IDLE = 2'b00;
localparam SWAP = 2'b01;
localparam CALCULATE = 2'b10;
localparam DONE = 2'b11;

reg [1:0] state_reg;
reg [31:0] result_reg;
reg done_reg;

always @(negedge rst_n) begin
    if (!rst_n) begin
        state_reg <= IDLE;
        result_reg <= 32'b0;
        done_reg <= 1'b0;
    end
end

always @(posedge clk) begin
    if (!rst_n) begin
        state_reg <= IDLE;
        result_reg <= 32'b0;
        done_reg <= 1'b0;
    end else begin
        case (state_reg)
            IDLE: begin
                if (start) begin
                    state_reg <= SWAP;
                end else begin
                    state_reg <= IDLE;
                end
            end
            SWAP: begin
                state_reg <= CALCULATE;
            end
            CALCULATE: begin
                reg [31:0] temp_result;
                reg [2:0] r;
                if (eff_n == 1) begin
                    r = eff_m % 6;
                    if (r == 0) begin
                        temp_result = eff_m;
                    end else if (r <= 3) begin
                        temp_result = eff_m - r;
                    end else begin
                        temp_result = eff_m - (6 - r);
                    end
                end else if (eff_n == 2) begin
                    if (eff_m == 2) begin
                        temp_result = 4'd0;
                    end else if (eff_m == 3) begin
                        temp_result = 4'd4;
                    end else if (eff_m == 7) begin
                        temp_result = 4'd12;
                    end else begin
                        temp_result = eff_n * eff_m;
                    end
                end else begin // n >=3
                    if ((eff_n * eff_m) % 2 == 0) begin
                        temp_result = eff_n * eff_m;
                    end else begin
                        temp_result = eff_n * eff_m - 1;
                    end
                end
                result_reg <= temp_result;
                state_reg <= DONE;
            end
            DONE: begin
                state_reg <= DONE;
                done_reg <= 1'b1;
            end
        endcase
    end
end

assign result = result_reg;
assign done = done_reg;

endmodule