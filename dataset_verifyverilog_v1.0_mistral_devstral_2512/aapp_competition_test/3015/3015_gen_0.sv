module hamster_path(
    input clk,
    input rst_n,
    input start,
    input [2:0] s,
    input [2:0] t,
    input [3:0] num_edges,
    input [2:0] edge_src [0:15],
    input [2:0] edge_dst [0:15],
    input [7:0] edge_weight [0:15],
    output reg [15:0] result,
    output reg infinite,
    output reg done
);

    localparam MAX_NODES = 8;
    localparam MAX_EDGES = 16;
    localparam DATA_WIDTH = 8;
    localparam RESULT_WIDTH = 16;
    localparam MAX_ITER = 2 * MAX_NODES;

    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] INIT = 2'd1;
    localparam [1:0] ITERATE = 2'd2;
    localparam [1:0] FINISH = 2'd3;

    reg [1:0] state;
    reg [7:0] iter_count;
    reg [7:0] edge_idx;
    reg [15:0] dp0 [0:7];
    reg [15:0] dp1 [0:7];
    reg [15:0] next_dp0 [0:7];
    reg [15:0] next_dp1 [0:7];
    reg converged;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd1000;

    integer i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            iter_count <= 8'd0;
            edge_idx <= 8'd0;
            for (i = 0; i < MAX_NODES; i = i + 1) begin
                dp0[i] <= 16'hFFFF;
                dp1[i] <= 16'hFFFF;
                next_dp0[i] <= 16'hFFFF;
                next_dp1[i] <= 16'hFFFF;
            end
            converged <= 1'b0;
            result <= 16'd0;
            infinite <= 1'b0;
            done <= 1'b0;
            cycle_count <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= INIT;
                    end
                end

                INIT: begin
                    for (i = 0; i < MAX_NODES; i = i + 1) begin
                        dp0[i] <= 16'hFFFF;
                        dp1[i] <= 16'hFFFF;
                        next_dp0[i] <= 16'hFFFF;
                        next_dp1[i] <= 16'hFFFF;
                    end
                    dp0[t] <= 16'd0;
                    dp1[t] <= 16'd0;
                    iter_count <= 8'd0;
                    edge_idx <= 8'd0;
                    converged <= 1'b0;
                    state <= ITERATE;
                end

                ITERATE: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= FINISH;
                    end else begin
                        if (edge_idx == 8'd0) begin
                            for (i = 0; i < MAX_NODES; i = i + 1) begin
                                next_dp0[i] <= dp0[i];
                                next_dp1[i] <= dp1[i];
                            end
                            converged <= 1'b1;
                        end

                        if (edge_idx < num_edges) begin
                            reg [2:0] u = edge_src[edge_idx];
                            reg [2:0] v = edge_dst[edge_idx];
                            reg [15:0] w_extended = {8'd0, edge_weight[edge_idx]};

                            if (u[0] == 1'b0) begin
                                if (w_extended + dp1[v] > next_dp0[u]) begin
                                    next_dp0[u] <= w_extended + dp1[v];
                                    converged <= 1'b0;
                                end
                            end else begin
                                if (w_extended + dp0[v] < next_dp1[u]) begin
                                    next_dp1[u] <= w_extended + dp0[v];
                                    converged <= 1'b0;
                                end
                            end

                            edge_idx <= edge_idx + 8'd1;
                        end else begin
                            if (converged || iter_count == MAX_ITER - 1) begin
                                state <= FINISH;
                            end else begin
                                for (i = 0; i < MAX_NODES; i = i + 1) begin
                                    dp0[i] <= next_dp0[i];
                                    dp1[i] <= next_dp1[i];
                                end
                                iter_count <= iter_count + 8'd1;
                                edge_idx <= 8'd0;
                            end
                        end
                    end
                end

                FINISH: begin
                    if (dp0[s] == 16'hFFFF || iter_count == MAX_ITER) begin
                        infinite <= 1'b1;
                        result <= 16'd0;
                    end else begin
                        infinite <= 1'b0;
                        result <= dp0[s];
                    end
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule