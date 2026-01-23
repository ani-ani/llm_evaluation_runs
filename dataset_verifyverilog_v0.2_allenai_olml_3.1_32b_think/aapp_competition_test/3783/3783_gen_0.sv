module subset_cost_sum(input clk, input rst_n, input start, input [19:0] n, input [12:0] k, output reg [31:0] result, output reg done);

// Parameters
localparam integer M = 1000000007;
localparam integer MAX_K = 5000;

// State machine
reg [2:0] state;
localparam integer IDLE = 3'd0;
localparam integer CALC_STIRLING = 3'd1;
localparam integer CALC_FACT = 3'd2;
localparam integer CALC_RESULT = 3'd3;
localparam integer DONE = 3'd4;

reg [31:0] result_reg;
reg done_reg;
reg [12:0] k_reg;
reg [19:0] n_reg;

always @(posedge clk) begin
    if (!rst_n) begin
        state <= IDLE;
        result_reg <= 0;
        done_reg <= 0;
        k_reg <= 0;
        n_reg <= 0;
    end else begin
        if (start) begin
            k_reg <= k;
            n_reg <= n;
        end
        case (state)
            IDLE: if (k_reg > 0) state <= CALC_STIRLING; else state <= DONE;
            CALC_STIRLING: state <= CALC_FACT;
            CALC_FACT: state <= CALC_RESULT;
            CALC_RESULT: state <= DONE;
            DONE:;
        endcase
    end
end

assign result = result_reg;
assign done = done_reg;

endmodule