module CriticalNodes (
    input clk,
    input rst_n,
    input start,
    input edge_valid,
    input [3:0] u,
    input [3:0] v,
    input [15:0] w,
    input config_done,
    input [3:0] src_node,
    input [3:0] dst_node,
    output reg result_valid,
    output reg [3:0] result_idx,
    output reg is_critical,
    output reg done
);

    // Parameters
    localparam [4:0] MAX_N = 5'd16;
    localparam [5:0] MAX_M = 6'd32;
    localparam [31:0] INF = 32'h7FFFFFFF;

    // State definitions
    localparam [3:0] IDLE           = 4'd0;
    localparam [3:0] CONFIG          = 4'd1;
    localparam [3:0] INIT_S          = 4'd2;
    localparam [3:0] INIT_T          = 4'd3;
    localparam [3:0] RELAX_S         = 4'd4;
    localparam [3:0] RELAX_T         = 4'd5;
    localparam [3:0] CHECK_NODES     = 4'd6;
    localparam [3:0] OUTPUT          = 4'd7;
    localparam [3:0] DONE_STATE      = 4'd8;

    // Memory for edges (buffered since M <= 32)
    reg [3:0] edge_u [0:31];
    reg [3:0] edge_v [0:31];
    reg [15:0] edge_w [0:31];
    reg [5:0] edge_count;
    reg [5:0] edge_idx;

    // Memory for distances (N x 32-bit)
    reg [31:0] dist_s [0:15];
    reg [31:0] dist_t [0:15];
    reg [31:0] new_dist_s [0:15];
    reg [31:0] new_dist_t [0:15];

    // State variables
    reg [3:0] state, next_state;
    reg [4:0] node_idx;
    reg [5:0] iter_count;
    reg [4:0] pass_count;
    reg [3:0] check_node;
    reg config_done_reg;
    reg start_reg;

    integer i;

    // Edge buffer write
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            edge_count <= 6'd0;
            config_done_reg <= 1'b0;
        end else begin
            if (edge_valid && edge_count < MAX_M) begin
                edge_u[edge_count] <= u;
                edge_v[edge_count] <= v;
                edge_w[edge_count] <= w;
                edge_count <= edge_count + 6'd1;
            end
            if (config_done) begin
                config_done_reg <= 1'b1;
            end
        end
    end

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result_valid <= 1'b0;
            result_idx <= 4'd0;
            is_critical <= 1'b0;
            done <= 1'b0;
            start_reg <= 1'b0;
            // Initialize all memory
            for (i = 0; i < 16; i = i + 1) begin
                dist_s[i] <= INF;
                dist_t[i] <= INF;
                new_dist_s[i] <= INF;
                new_dist_t[i] <= INF;
            end
            edge_idx <= 6'd0;
            pass_count <= 5'd0;
            iter_count <= 6'd0;
            node_idx <= 5'd0;
            check_node <= 4'd0;
        end else begin
            case (state)
                IDLE: begin
                    result_valid <= 1'b0;
                    done <= 1'b0;
                    if (start) begin
                        start_reg <= 1'b1;
                        state <= CONFIG;
                        edge_idx <= 6'd0;
                    end
                end

                CONFIG: begin
                    if (config_done_reg) begin
                        start_reg <= 1'b0;
                        state <= INIT_S;
                    end
                end

                INIT_S: begin
                    // Initialize dist_s
                    for (i = 0; i < 16; i = i + 1) begin
                        if (i == src_node)
                            dist_s[i] <= 32'd0;
                        else
                            dist_s[i] <= INF;
                    end
                    state <= INIT_T;
                end

                INIT_T: begin
                    // Initialize dist_t (reverse graph)
                    for (i = 0; i < 16; i = i + 1) begin
                        if (i == dst_node)
                            dist_t[i] <= 32'd0;
                        else
                            dist_t[i] <= INF;
                    end
                    pass_count <= 5'd0;
                    state <= RELAX_S;
                end

                RELAX_S: begin
                    // Relaxation for dist_s
                    // First, copy current dist to new_dist for comparison
                    for (i = 0; i < 16; i = i + 1) begin
                        new_dist_s[i] <= dist_s[i];
                    end
                    edge_idx <= 6'd0;
                    iter_count <= 6'd0;
                    state <= RELAX_S; // Stay in same state for processing edges
                end

                RELAX_S: begin
                    if (iter_count < edge_count) begin
                        // Process edge at edge_idx
                        if (dist_s[edge_u[edge_idx]] != INF) begin
                            // Check for overflow: only if w + dist_s[u] < dist_s[v]
                            // Need to check if dist_s[u] + w < dist_s[v]
                            // Since INF is large, dist_s[u] + w may overflow if dist_s[u] is INF
                            // So we check dist_s[u] != INF first
                            if (dist_s[edge_u[edge_idx]] + {16'd0, edge_w[edge_idx]} < new_dist_s[edge_v[edge_idx]]) begin
                                new_dist_s[edge_v[edge_idx]] <= dist_s[edge_u[edge_idx]] + {16'd0, edge_w[edge_idx]};
                            end
                        end
                        edge_idx <= edge_idx + 6'd1;
                        iter_count <= iter_count + 6'd1;
                    end else begin
                        // Update distances
                        for (i = 0; i < 16; i = i + 1) begin
                            dist_s[i] <= new_dist_s[i];
                        end
                        pass_count <= pass_count + 5'd1;
                        if (pass_count == 5'd15) begin
                            // Done with forward graph
                            pass_count <= 5'd0;
                            state <= RELAX_T;
                        end else begin
                            state <= RELAX_S;
                        end
                    end
                end

                RELAX_T: begin
                    // Relaxation for dist_t
                    // Copy dist_t to new_dist_t
                    for (i = 0; i < 16; i = i + 1) begin
                        new_dist_t[i] <= dist_t[i];
                    end
                    edge_idx <= 6'd0;
                    iter_count <= 6'd0;
                    state <= RELAX_T; // Stay for processing
                end

                RELAX_T: begin
                    if (iter_count < edge_count) begin
                        // Reverse graph: edge u->v means in reverse v->u
                        if (dist_t[edge_v[edge_idx]] != INF) begin
                            if (dist_t[edge_v[edge_idx]] + {16'd0, edge_w[edge_idx]} < new_dist_t[edge_u[edge_idx]]) begin
                                new_dist_t[edge_u[edge_idx]] <= dist_t[edge_v[edge_idx]] + {16'd0, edge_w[edge_idx]};
                            end
                        end
                        edge_idx <= edge_idx + 6'd1;
                        iter_count <= iter_count + 6'd1;
                    end else begin
                        for (i = 0; i < 16; i = i + 1) begin
                            dist_t[i] <= new_dist_t[i];
                        end
                        pass_count <= pass_count + 5'd1;
                        if (pass_count == 5'd15) begin
                            // Done with backward graph
                            check_node <= 4'd0;
                            state <= CHECK_NODES;
                        end else begin
                            state <= RELAX_T;
                        end
                    end
                end

                CHECK_NODES: begin
                    // Check all nodes for criticality
                    if (check_node < MAX_N) begin
                        // Check if node lies on shortest path
                        // dist_s[check_node] + dist_t[check_node] == dist_s[dst_node]
                        // AND both distances are finite
                        if (dist_s[check_node] != INF && dist_t[check_node] != INF &&
                            (dist_s[check_node] + dist_t[check_node] == dist_s[dst_node])) begin
                            result_idx <= check_node;
                            is_critical <= 1'b1;
                            result_valid <= 1'b1;
                        end else begin
                            is_critical <= 1'b0;
                            result_valid <= 1'b1;
                        end
                        check_node <= check_node + 4'd1;
                        state <= OUTPUT;
                    end else begin
                        // All nodes checked
                        done <= 1'b1;
                        state <= DONE_STATE;
                    end
                end

                OUTPUT: begin
                    // Deassert result_valid
                    result_valid <= 1'b0;
                    state <= CHECK_NODES;
                end

                DONE_STATE: begin
                    done <= 1'b0;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule