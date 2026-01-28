module ShippingOptimizer(
    input clk,
    input rst_n,
    input start,
    input [3:0] n, m, s, t,
    input [3:0] a, b,
    input [3:0] emp_loc_0, emp_loc_1, emp_loc_2, emp_loc_3,
    input [3:0] cli_loc_0, cli_loc_1, cli_loc_2, cli_loc_3,
    input [3:0] edge_u_0, edge_v_0, edge_u_1, edge_v_1, edge_u_2, edge_v_2, edge_u_3, edge_v_3, edge_u_4, edge_v_4, edge_u_5, edge_v_5,
    input [31:0] edge_d_0, edge_d_1, edge_d_2, edge_d_3, edge_d_4, edge_d_5,
    output reg [31:0] total_distance,
    output reg done
);

    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] FLOYD = 2'd1;
    localparam [1:0] COST = 2'd2;
    localparam [1:0] DP = 2'd3;
    localparam [1:0] OUTPUT = 2'd4;

    reg [1:0] state;
    reg [9:0] cycle_count;
    localparam [9:0] MAX_CYCLES = 10'd1000;

    reg [31:0] dist [0:3][0:3];
    reg [31:0] cost [0:3][0:3];
    reg [31:0] dp [0:4][0:15];

    reg [3:0] k, i, j;
    reg [3:0] emp, cli;
    reg [3:0] mask;
    reg [3:0] min_mask;
    reg [31:0] min_val;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            total_distance <= 32'd0;
            done <= 1'b0;
            cycle_count <= 10'd0;
            k <= 4'd0;
            i <= 4'd0;
            j <= 4'd0;
            emp <= 4'd0;
            cli <= 4'd0;
            mask <= 4'd0;
            min_mask <= 4'd0;
            min_val <= 32'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 10'd0;
                    if (start) begin
                        state <= FLOYD;
                    end
                end

                FLOYD: begin
                    cycle_count <= cycle_count + 10'd1;
                    if (cycle_count == 10'd1) begin
                        for (i = 0; i < 4; i = i + 1) begin
                            for (j = 0; j < 4; j = j + 1) begin
                                if (i == j) begin
                                    dist[i][j] <= 32'd0;
                                end else begin
                                    dist[i][j] <= 32'h7FFFFFFF;
                                end
                            end
                        end
                    end else if (cycle_count == 10'd2) begin
                        if (edge_u_0 < n && edge_v_0 < n) begin
                            dist[edge_u_0][edge_v_0] <= edge_d_0;
                            dist[edge_v_0][edge_u_0] <= edge_d_0;
                        end
                        if (edge_u_1 < n && edge_v_1 < n) begin
                            dist[edge_u_1][edge_v_1] <= edge_d_1;
                            dist[edge_v_1][edge_u_1] <= edge_d_1;
                        end
                        if (edge_u_2 < n && edge_v_2 < n) begin
                            dist[edge_u_2][edge_v_2] <= edge_d_2;
                            dist[edge_v_2][edge_u_2] <= edge_d_2;
                        end
                        if (edge_u_3 < n && edge_v_3 < n) begin
                            dist[edge_u_3][edge_v_3] <= edge_d_3;
                            dist[edge_v_3][edge_u_3] <= edge_d_3;
                        end
                        if (edge_u_4 < n && edge_v_4 < n) begin
                            dist[edge_u_4][edge_v_4] <= edge_d_4;
                            dist[edge_v_4][edge_u_4] <= edge_d_4;
                        end
                        if (edge_u_5 < n && edge_v_5 < n) begin
                            dist[edge_u_5][edge_v_5] <= edge_d_5;
                            dist[edge_v_5][edge_u_5] <= edge_d_5;
                        end
                    end else if (cycle_count > 10'd2 && cycle_count < 10'd100) begin
                        k <= (cycle_count - 10'd3) / 10'd16;
                        i <= ((cycle_count - 10'd3) % 10'd16) / 10'd4;
                        j <= (cycle_count - 10'd3) % 10'd4;
                        if (k < n && i < n && j < n) begin
                            if (dist[i][k] + dist[k][j] < dist[i][j]) begin
                                dist[i][j] <= dist[i][k] + dist[k][j];
                            end
                        end
                        if (cycle_count == 10'd99) begin
                            state <= COST;
                            cycle_count <= 10'd0;
                        end
                    end
                end

                COST: begin
                    cycle_count <= cycle_count + 10'd1;
                    if (cycle_count == 10'd1) begin
                        emp <= 4'd0;
                        cli <= 4'd0;
                    end else if (cycle_count > 10'd1 && cycle_count < 10'd100) begin
                        emp <= (cycle_count - 10'd2) / 10'd4;
                        cli <= (cycle_count - 10'd2) % 10'd4;
                        if (emp < s && cli < t) begin
                            if (dist[a-1][emp_loc_0-1] + dist[a-1][cli_loc_0-1] < dist[b-1][emp_loc_0-1] + dist[b-1][cli_loc_0-1]) begin
                                cost[emp][cli] <= dist[a-1][emp_loc_0-1] + dist[a-1][cli_loc_0-1];
                            end else begin
                                cost[emp][cli] <= dist[b-1][emp_loc_0-1] + dist[b-1][cli_loc_0-1];
                            end
                        end
                        if (cycle_count == 10'd99) begin
                            state <= DP;
                            cycle_count <= 10'd0;
                        end
                    end
                end

                DP: begin
                    cycle_count <= cycle_count + 10'd1;
                    if (cycle_count == 10'd1) begin
                        for (mask = 0; mask < 15; mask = mask + 1) begin
                            dp[0][mask] <= 32'h7FFFFFFF;
                        end
                        dp[0][0] <= 32'd0;
                    end else if (cycle_count > 10'd1 && cycle_count < 10'd1000) begin
                        cli <= (cycle_count - 10'd2) / 10'd16;
                        mask <= ((cycle_count - 10'd2) % 10'd16) / 10'd4;
                        emp <= (cycle_count - 10'd2) % 10'd4;
                        if (cli < t && mask < 15 && emp < s) begin
                            if (dp[cli][mask] != 32'h7FFFFFFF && (mask & (1 << emp)) == 0) begin
                                if (dp[cli+1][mask | (1 << emp)] > dp[cli][mask] + cost[emp][cli]) begin
                                    dp[cli+1][mask | (1 << emp)] <= dp[cli][mask] + cost[emp][cli];
                                end
                            end
                        end
                        if (cycle_count == 10'd999) begin
                            state <= OUTPUT;
                            cycle_count <= 10'd0;
                        end
                    end
                end

                OUTPUT: begin
                    done <= 1'b1;
                    min_val <= 32'h7FFFFFFF;
                    for (mask = 0; mask < 15; mask = mask + 1) begin
                        if ($clogb2(mask) == t && dp[t][mask] < min_val) begin
                            min_val <= dp[t][mask];
                        end
                    end
                    total_distance <= min_val;
                    state <= IDLE;
                    done <= 1'b0;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule