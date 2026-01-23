module bell_number (input clk, input rst_n, input start, input [3:0] n, output reg [15:0] result, output reg done);
reg [15:0] bell [9][9];
reg [3:0] i, j;
reg [3:0] n_val;
reg [2:0] state;
reg [15:0] result_reg;
reg done_reg;
localparam IDLE = 3'b000;
localparam INIT = 3'b001;
localparam COMPUTE_ROW = 3'b010;
localparam COMPUTE_COL = 3'b011;
localparam UPDATE = 3'b100;
localparam DONE_STATE = 3'b101;
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        result_reg <= 0;
        done_reg <= 0;
        n_val <= 0;
        i <= 0;
        j <= 0;
    end else begin
        case (state)
            IDLE: begin
                if (start) begin
                    n_val <= n;
                    if (n_val == 0) begin
                        result_reg <= 1;
                        done_reg <= 1;
                        state <= DONE_STATE;
                    end else begin
                        state <= INIT;
                    end
                end
            end
            INIT: begin
                bell[0][0] <= 1;
                i <= 1;
                j <= 0;
                state <= COMPUTE_ROW;
            end
            COMPUTE_ROW: begin
                bell[i][0] <= bell[i-1][i-1];
                j <= 1;
                state <= COMPUTE_COL;
            end
            COMPUTE_COL: begin
                bell[i][j] <= bell[i-1][j-1] + bell[i][j-1];
                state <= UPDATE;
            end
            UPDATE: begin
                j <= j + 1;
                if (j <= i) begin
                    state <= COMPUTE_COL;
                end else begin
                    i <= i + 1;
                    if (i > n_val) begin
                        state <= DONE_STATE;
                    end else begin
                        state <= COMPUTE_ROW;
                    end
                end
            end
            DONE_STATE: begin
                if (n_val == 0) begin
                    result_reg <= 1;
                end else begin
                    result_reg <= bell[n_val][0];
                end
                done_reg <= 1;
                state <= IDLE;
            end
        endcase
    end
end
assign result = result_reg;
assign done = done_reg;
endmodule