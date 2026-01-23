module graph_profit_maximizer (input clk, input rst_n, input start, input [8:0] node_idx, input [8:0] edge_idx, input load_mode, input signed [31:0] A_val, input signed [31:0] B_val, input [8:0] U_val, input [8:0] V_val, output reg [31:0] max_profit, output reg done);
parameter N_NODES = 256;
parameter N_EDGES = 256;
reg [31:0] A[N_NODES];
reg [31:0] B[N_NODES];
reg [31:0] total_positive = 0;
reg [2:0] state;
reg [31:0] max_flow = 0;
always @(posedge clk) begin
    if (!rst_n) begin
        state <= 0;
        done <= 0;
        max_profit <= 0;
        total_positive <= 0;
    end else begin
        case (state)
            0: // Loading
                if (load_mode == 0) begin
                    if (node_idx < N_NODES) begin
                        A[node_idx] <= A_val;
                        B[node_idx] <= B_val;
                        if (B_val > 0) total_positive <= total_positive + B_val;
                    end
                end
                if (start && load_mode == 0) begin
                    state <= 1;
                end
            end
            1: // Compute
                max_profit <= total_positive - max_flow;
                done <= 1;
                state <= 2;
            end
        endcase
    end
end
endmodule