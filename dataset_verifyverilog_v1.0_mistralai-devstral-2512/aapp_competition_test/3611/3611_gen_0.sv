module CriticalNodeIdentifier(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire edge_valid,
    input wire [3:0] u,
    input wire [3:0] v,
    input wire [15:0] w,
    input wire config_done,
    input wire [3:0] src_node,
    input wire [3:0] dst_node,
    output reg result_valid,
    output reg [3:0] result_idx,
    output reg is_critical,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] LOAD_EDGES = 3'd1;
    localparam [2:0] COMPUTE_DIST_S = 3'd2;
    localparam [2:0] COMPUTE_DIST_T = 3'd3;
    localparam [2:0] CHECK_NODES = 3'd4;
    localparam [2:0] FINISH = 3'd5;

    reg [2:0] state, next_state;

    // Edge buffer (max 32 edges)
    reg [3:0] edge_buffer_u [0:31];
    reg [3:0] edge_buffer_v [0:31];
    reg [15:0] edge_buffer_w [0:31];
    reg [4:0] edge_count;

    // Distance memories (N=16 nodes, 32-bit distances)
    reg [31:0] dist_s [0:15];
    reg [31:0] dist_t [0:15];

    // Bellman-Ford control
    reg [3:0] relaxation_cycle;
    reg [3:0] current_node;
    reg [3:0] edge_ptr;

    // Result output control
    reg [3:0] output_node;
    reg [31:0] shortest_path_dist;

    // Initialize all registers
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            edge_count <= 5'd0;
            relaxation_cycle <= 4'd0;
            current_node <= 4'd0;
            edge_ptr <= 4'd0;
            output_node <= 4'd0;
            result_valid <= 1'b0;
            result_idx <= 4'd0;
            is_critical <= 1'b0;
            done <= 1'b0;
            shortest_path_dist <= 32'd0;

            // Initialize edge buffer
            integer i;
            for (i = 0; i < 32; i = i + 1) begin
                edge_buffer_u[i] <= 4'd0;
                edge_buffer_v[i] <= 4'd0;
                edge_buffer_w[i] <= 16'd0;
            end

            // Initialize distance memories
            for (i = 0; i < 16; i = i + 1) begin
                dist_s[i] <= 32'd0;
                dist_t[i] <= 32'd0;
            end
        end else begin
            state <= next_state;
        end
    end

    // Edge loading FSM
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Already initialized above
        end else begin
            case (state)
                IDLE: begin
                    result_valid <= 1'b0;
                    done <= 1'b0;
                    if (start) begin
                        next_state <= LOAD_EDGES;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                LOAD_EDGES: begin
                    if (edge_valid && edge_count < 5'd32) begin
                        edge_buffer_u[edge_count] <= u;
                        edge_buffer_v[edge_count] <= v;
                        edge_buffer_w[edge_count] <= w;
                        edge_count <= edge_count + 5'd1;
                    end
                    if (config_done) begin
                        next_state <= COMPUTE_DIST_S;
                    end else begin
                        next_state <= LOAD_EDGES;
                    end
                end

                COMPUTE_DIST_S: begin
                    // Initialize distances
                    if (relaxation_cycle == 4'd0) begin
                        integer i;
                        for (i = 0; i < 16; i = i + 1) begin
                            dist_s[i] <= 32'd0;
                        end
                        dist_s[src_node] <= 32'd0;
                    end

                    // Relax all edges
                    if (edge_ptr < edge_count) begin
                        reg [31:0] new_dist;
                        new_dist = dist_s[edge_buffer_u[edge_ptr]] + 32'd0 + edge_buffer_w[edge_ptr];
                        if (new_dist < dist_s[edge_buffer_v[edge_ptr]]) begin
                            dist_s[edge_buffer_v[edge_ptr]] <= new_dist;
                        end
                        edge_ptr <= edge_ptr + 4'd1;
                    end else begin
                        edge_ptr <= 4'd0;
                        if (relaxation_cycle < 4'd15) begin
                            relaxation_cycle <= relaxation_cycle + 4'd1;
                        end else begin
                            relaxation_cycle <= 4'd0;
                            next_state <= COMPUTE_DIST_T;
                        end
                    end
                end

                COMPUTE_DIST_T: begin
                    // Initialize distances for reverse graph
                    if (relaxation_cycle == 4'd0) begin
                        integer i;
                        for (i = 0; i < 16; i = i + 1) begin
                            dist_t[i] <= 32'd0;
                        end
                        dist_t[dst_node] <= 32'd0;
                    end

                    // Relax all edges in reverse
                    if (edge_ptr < edge_count) begin
                        reg [31:0] new_dist;
                        new_dist = dist_t[edge_buffer_v[edge_ptr]] + 32'd0 + edge_buffer_w[edge_ptr];
                        if (new_dist < dist_t[edge_buffer_u[edge_ptr]]) begin
                            dist_t[edge_buffer_u[edge_ptr]] <= new_dist;
                        end
                        edge_ptr <= edge_ptr + 4'd1;
                    end else begin
                        edge_ptr <= 4'd0;
                        if (relaxation_cycle < 4'd15) begin
                            relaxation_cycle <= relaxation_cycle + 4'd1;
                        end else begin
                            relaxation_cycle <= 4'd0;
                            shortest_path_dist <= dist_s[dst_node];
                            next_state <= CHECK_NODES;
                        end
                    end
                end

                CHECK_NODES: begin
                    if (output_node < 4'd16) begin
                        result_idx <= output_node;
                        if (dist_s[output_node] + dist_t[output_node] == shortest_path_dist &&
                            dist_s[output_node] != 32'd0 && dist_t[output_node] != 32'd0) begin
                            is_critical <= 1'b1;
                        end else begin
                            is_critical <= 1'b0;
                        end
                        result_valid <= 1'b1;
                        output_node <= output_node + 4'd1;
                    end else begin
                        result_valid <= 1'b0;
                        done <= 1'b1;
                        next_state <= FINISH;
                    end
                end

                FINISH: begin
                    done <= 1'b0;
                    next_state <= IDLE;
                end

                default: next_state <= IDLE;
            endcase
        end
    end

endmodule