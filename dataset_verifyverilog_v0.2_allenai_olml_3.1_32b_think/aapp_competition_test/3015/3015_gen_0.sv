module hamster_game (
input clk,
input rst_n,
input start,
input [1:0] s,
input [1:0] t,
input [7:0] valid_edges,
input [1:0] edge_from [7:0],
input [1:0] edge_to [7:0],
input [15:0] edge_weight [7:0],
output reg [15:0] result,
output reg done,
output reg infinity
);

reg signed [15:0] dp_L [3:0];
reg signed [15:0] dp_R [3:0];
reg signed [15:0] new_dp_L [3:0];
reg signed [15:0] new_dp_R [3:0];
reg [3:0] state;

initial begin
    state <= 0;
done <= 0;
infinity <= 0;
result <= 0;
dp_L <= -1's;
dp_R <= -1's;
new_dp_L <= -1's;
new_dp_R <= -1's;
end

always @(posedge clk) begin
    if (!rst_n) begin
        state <= 0;
done <= 0;
infinity <= 0;
result <= 0;
dp_L <= -1's;
dp_R <= -1's;
new_dp_L <= -1's;
new_dp_R <= -1's;
    end else begin
        case (state)
            0: // IDLE
                if (start) state <= 1;
done <= 0;
infinity <= 0;
result <= 0;
            end
            1: // INIT
                dp_L[t] <= 0;
dp_R[t] <= 0;
state <= 2;
done <= 0;
infinity <= 0;
result <= 0;
            end
            2: // ITER1
                for (int u=0; u<4; u++) begin
                    new_dp_L[u] = -1;
                    for (int i=0; i<8; i++) begin
                        if (valid_edges[i] && (edge_from[i] == u)) begin
                            int dest = edge_to[i];
                            if (dp_R[dest] != -1) begin
                                int candidate = edge_weight[i] + dp_R[dest];
                                if (candidate > new_dp_L[u]) begin
                                    new_dp_L[u] = candidate;
                                end
                            end
                        end
                    end
                end
                for (int u=0; u<4; u++) begin
                    new_dp_R[u] = 32767;
                    for (int i=0; i<8; i++) begin
                        if (valid_edges[i] && (edge_from[i] == u)) begin
                            int dest = edge_to[i];
                            if (dp_L[dest] != -1) begin
                                int candidate = edge_weight[i] + dp_L[dest];
                                if (candidate < new_dp_R[u]) begin
                                    new_dp_R[u] = candidate;
                                end
                            end
                        end
                    end
                end
                dp_L <= new_dp_L;
dp_R <= new_dp_R;
state <= 3;
done <= 0;
infinity <= 0;
result <= 0;
            end
            3: state <= 4;
            4: state <= 5;
            5: state <= 6;
            6: // CHECK
                if (dp_L[s] == -1) begin
                    infinity <= 1;
result <= 0;
                end else begin
                    infinity <= 0;
result <= dp_L[s];
                end
done <= 1;
state <= 7;
            end
            7: // DONE
done <= 1;
state <= 7;
            endcase
        end
    end
end

endmodule