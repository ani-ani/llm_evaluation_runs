module min_transmission_cost (input clk, input rst_n, input start, input [7:0] tree_a_nodes, input [7:0] tree_b_nodes, input [7:0] tree_a_adj [0:7], input [7:0] tree_b_adj [0:7], output reg [31:0] min_cost, output reg done);
parameter IDLE = 3'b000;
parameter COMPUTE_DIST_A = 3'b001;
parameter COMPUTE_DIST_B = 3'b010;
parameter FIND_CENTER_A = 3'b011;
parameter FIND_CENTER_B = 3'b100;
parameter CALCULATE_COST = 3'b101;
parameter DONE_STATE = 3'b110;

reg [2:0] state;
reg [31:0] min_cost_reg;
reg done_reg;
reg [7:0] N_a_reg, N_b_reg;
reg [2:0] distance_a [0:7][0:7];
reg [2:0] distance_b [0:7][0:7];
reg [31:0] sum_sq_a, sum_sq_b;
reg [7:0] total_dist_a [0:7], total_dist_b [0:7];
reg [2:0] center_a, center_b;
reg [31:0] cost_terms;

always @(posedge clk) begin
    if (!rst_n) begin
        state <= IDLE;
        min_cost_reg <= 32'd0;
        done_reg <= 1'b0;
        N_a_reg <= 8'd0;
        N_b_reg <= 8'd0;
        for (int i=0; i<8; i++) for (int j=0; j<8; j++) begin
            distance_a[i][j] <= 3'd0;
            distance_b[i][j] <= 3'd0;
        end
        sum_sq_a <= 32'd0;
        sum_sq_b <= 32'd0;
        for (int i=0; i<8; i++) begin
            total_dist_a[i] <= 8'd0;
            total_dist_b[i] <= 8'd0;
        end
        center_a <= 3'd0;
        center_b <= 3'd0;
        cost_terms <= 32'd0;
        done_reg <= 1'b0;
    end else begin
        case (state)
            IDLE: begin
                if (start) begin
                    state <= COMPUTE_DIST_A;
                    N_a_reg <= tree_a_nodes;
                    N_b_reg <= tree_b_nodes;
                end
            end
            COMPUTE_DIST_A: begin
                for (int i=0; i < N_a_reg; i++) begin
                    for (int j=0; j < N_a_reg; j++) begin
                        if (i == j) begin
                            distance_a[i][j] <= 3'd0;
                        end else begin
                            if (tree_a_adj[i] & (1 << j)) begin
                                distance_a[i][j] <= 3'd1;
                            end else begin
                                distance_a[i][j] <= 3'd8;
                            end
                        end
                    end
                end
                state <= COMPUTE_DIST_B;
            end
            COMPUTE_DIST_B: begin
                for (int i=0; i < N_b_reg; i++) begin
                    for (int j=0; j < N_b_reg; j++) begin
                        if (i == j) begin
                            distance_b[i][j] <= 3'd0;
                        end else begin
                            if (tree_b_adj[i] & (1 << j)) begin
                                distance_b[i][j] <= 3'd1;
                            end else begin
                                distance_b[i][j] <= 3'd8;
                            end
                        end
                    end
                end
                state <= FIND_CENTER_A;
            end
            FIND_CENTER_A: begin
                for (int i=0; i < N_a_reg; i++) begin
                    total_dist_a[i] <= 8'd0;
                    for (int j=0; j < N_a_reg; j++) begin
                        total_dist_a[i] <= total_dist_a[i] + distance_a[i][j];
                    end
                end
                center_a <= 3'd0;
                total_dist_a[center_a] <= 32'd0;
                for (int i=1; i < N_a_reg; i++) begin
                    if (total_dist_a[i] < total_dist_a[center_a]) begin
                        center_a <= i;
                        total_dist_a[center_a] <= total_dist_a[i];
                    end
                end
                state <= FIND_CENTER_B;
            end
            FIND_CENTER_B: begin
                for (int i=0; i < N_b_reg; i++) begin
                    total_dist_b[i] <= 8'd0;
                    for (int j=0; j < N_b_reg; j++) begin
                        total_dist_b[i] <= total_dist_b[i] + distance_b[i][j];
                    end
                end
                center_b <= 3'd0;
                total_dist_b[center_b] <= 32'd0;
                for (int i=1; i < N_b_reg; i++) begin
                    if (total_dist_b[i] < total_dist_b[center_b]) begin
                        center_b <= i;
                        total_dist_b[center_b] <= total_dist_b[i];
                    end
                end
                state <= CALCULATE_COST;
            end
            CALCULATE_COST: begin
                sum_sq_a <= 32'd0;
                sum_sq_b <= 32'd0;
                for (int i=0; i < N_a_reg; i++) begin
                    for (int j=i+1; j < N_a_reg; j++) begin
                        sum_sq_a <= sum_sq_a + (distance_a[i][j] * distance_a[i][j]);
                    end
                end
                for (int i=0; i < N_b_reg; i++) begin
                    for (int j=i+1; j < N_b_reg; j++) begin
                        sum_sq_b <= sum_sq_b + (distance_b[i][j] * distance_b[i][j]);
                    end
                end
                cost_terms <= sum_sq_a + sum_sq_b;
                cost_terms <= cost_terms + (N_a_reg * N_b_reg);
                cost_terms <= cost_terms + (N_a_reg * N_b_reg) * (total_dist_a[center_a] * total_dist_a[center_a] + total_dist_b[center_b] * total_dist_b[center_b] + 2 * total_dist_a[center_a] * total_dist_b[center_b]);
                min_cost_reg <= cost_terms;
                state <= DONE_STATE;
            end
            DONE_STATE: begin
                done_reg <= 1'b1;
            end
        endcase
    end
end

assign min_cost = min_cost_reg;
assign done = done_reg;

endmodule