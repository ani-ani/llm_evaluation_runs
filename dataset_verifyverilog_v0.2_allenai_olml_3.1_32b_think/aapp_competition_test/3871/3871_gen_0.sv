module reality_show (
    input clk,
    input rst_n,
    input start,
    input [2:0] n,
    input [2:0] l_i,
    input [12:0] s_i,
    input [12:0] c_v,
    input valid_i,
    input done_i,
    output reg [15:0] max_profit,
    output reg done
);

localparam IDLE = 3'b000;
localparam COLLECT = 3'b001;
localparam PROCESS = 3'b010;
localparam DONE = 3'b100;

reg [2:0] n_reg;
reg [2:0] levels [0:7];
reg [12:0] costs [0:7];
reg [12:0] profits [0:7];
reg [2:0] candidate_count;
reg [3:0] state;
reg [7:0] subset_counter;
reg [15:0] max_profit_int;
reg [15:0] tc, tr;

always @(posedge clk) begin
    if (!rst_n) begin
        n_reg <= 3'b000;
        candidate_count <= 0;
        state <= IDLE;
        subset_counter <= 0;
        max_profit_int <= 0;
        done <=0;
    end else begin
        case (state)
            IDLE: begin
                if (start) begin
                    n_reg <= n;
                    candidate_count <=0;
                    state <= COLLECT;
                end
            end
            COLLECT: begin
                if (valid_i) begin
                    if (candidate_count < n_reg) begin
                        levels[candidate_count] <= l_i;
                        costs[candidate_count] <= s_i;
                        profits[candidate_count] <= c_v;
                        candidate_count <= candidate_count +1;
                    end
                end
                if (done_i && candidate_count == n_reg) begin
                    state <= PROCESS;
                end
            end
            PROCESS: begin
                if (subset_counter < 256) begin
                    tc =0; tr=0;
                    if (subset_counter & 1) begin tc += costs[0]; tr += profits[0]; end
                    if (subset_counter & 2) begin tc += costs[1]; tr += profits[1]; end
                    if (subset_counter & 4) begin tc += costs[2]; tr += profits[2]; end
                    if (subset_counter & 8) begin tc += costs[3]; tr += profits[3]; end
                    if (subset_counter & 16) begin tc += costs[4]; tr += profits[4]; end
                    if (subset_counter & 32) begin tc += costs[5]; tr += profits[5]; end
                    if (subset_counter & 64) begin tc += costs[6]; tr += profits[6]; end
                    if (subset_counter & 128) begin tc += costs[7]; tr += profits[7]; end
                    if (tr > tc) begin
                        if (tr - tc > max_profit_int) begin
                            max_profit_int <= tr - tc;
                        end
                    end
                    subset_counter <= subset_counter +1;
                end else begin
                    state <= DONE;
                    max_profit <= max_profit_int;
                    done <=1;
                end
            end
            DONE: begin
                // No action needed
            end
            default: state <= IDLE;
        endcase
    end
endmodule