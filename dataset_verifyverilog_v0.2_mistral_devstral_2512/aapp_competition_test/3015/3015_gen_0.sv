module hamster_game (
    input clk,
    input rst_n,
    input start,
    input [1:0] s,
    input [1:0] t,
    input [7:0] valid_edges,
    input [1:0] edge_from [0:7],
    input [1:0] edge_to [0:7],
    input [15:0] edge_weight [0:7],
    output reg [15:0] result,
    output reg done,
    output reg infinity
);

    // State definitions
    typedef enum logic [2:0] {
        IDLE,
        INIT,
        UPDATE_L,
        UPDATE_R,
        CHECK,
        DONE
    } state_t;

    state_t state;
    reg [15:0] DP_L [0:3];
    reg [15:0] DP_R [0:3];
    reg [3:0] iter;

    // Initialize DP tables
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 0;
            infinity <= 0;
            result <= 0;
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        state <= INIT;
                        done <= 0;
                        infinity <= 0;
                    end
                end
                INIT: begin
                    // Initialize DP tables
                    DP_L[t] <= 0;
                    DP_R[t] <= 0;
                    for (int i = 0; i < 4; i++) begin
                        if (i != t) begin
                            DP_L[i] <= -1;
                            DP_R[i] <= -1;
                        end
                    end
                    iter <= 0;
                    state <= UPDATE_L;
                end
                UPDATE_L: begin
                    // Update DP_L for all nodes
                    for (int i = 0; i < 4; i++) begin
                        if (i != t) begin
                            reg [15:0] max_val = -1;
                            for (int j = 0; j < 8; j++) begin
                                if (valid_edges[j] && edge_from[j] == i) begin
                                    reg [15:0] candidate = edge_weight[j] + DP_R[edge_to[j]];
                                    if (candidate > max_val) begin
                                        max_val = candidate;
                                    end
                                end
                            end
                            DP_L[i] <= max_val;
                        end
                    end
                    state <= UPDATE_R;
                end
                UPDATE_R: begin
                    // Update DP_R for all nodes
                    for (int i = 0; i < 4; i++) begin
                        if (i != t) begin
                            reg [15:0] min_val = 16'hFFFF;
                            for (int j = 0; j < 8; j++) begin
                                if (valid_edges[j] && edge_from[j] == i) begin
                                    reg [15:0] candidate = edge_weight[j] + DP_L[edge_to[j]];
                                    if (candidate < min_val) begin
                                        min_val = candidate;
                                    end
                                end
                            end
                            DP_R[i] <= min_val;
                        end
                    end
                    iter <= iter + 1;
                    if (iter == 4) begin
                        state <= CHECK;
                    end else begin
                        state <= UPDATE_L;
                    end
                end
                CHECK: begin
                    // Check for cycles or infinite loops
                    reg [15:0] threshold = 16'h3A98; // 15000
                    if (DP_L[s] > threshold) begin
                        infinity <= 1;
                        result <= 0;
                    end else begin
                        infinity <= 0;
                        result <= DP_L[s];
                    end
                    state <= DONE;
                end
                DONE: begin
                    done <= 1;
                end
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule