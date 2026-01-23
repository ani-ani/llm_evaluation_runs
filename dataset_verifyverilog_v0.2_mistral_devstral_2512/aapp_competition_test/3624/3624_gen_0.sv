module trek_planner (
    input clk,
    input rst_n,
    input start,
    input [3:0] node_count,
    input [3:0] edge_count,
    input [5:0] edge_u,
    input [5:0] edge_v,
    input [5:0] edge_weight,
    input edge_valid,
    input compute_start,
    output reg [7:0] wait_time,
    output reg done,
    output reg error
);

    // Parameters
    parameter IDLE = 3'b000;
    parameter LOAD_EDGES = 3'b001;
    parameter COMPUTE_KNIGHT = 3'b010;
    parameter COMPUTE_DAY = 3'b011;
    parameter CALC_RESULT = 3'b100;
    parameter DONE = 3'b101;

    // State register
    reg [2:0] state;

    // Edge storage
    reg [5:0] edge_u_mem [0:15];
    reg [5:0] edge_v_mem [0:15];
    reg [5:0] edge_weight_mem [0:15];
    reg [3:0] edge_counter;

    // Dijkstra variables for Dr. Knight
    reg [7:0] knight_dist [0:15];
    reg [3:0] knight_current;
    reg [3:0] knight_next;
    reg [7:0] knight_min_dist;
    reg [3:0] knight_min_node;
    reg [3:0] knight_visited [0:15];

    // DP variables for Mr. Day
    reg [7:0] day_dist [0:15];
    reg [3:0] day_current;
    reg [3:0] day_next;
    reg [7:0] day_min_dist;
    reg [3:0] day_min_node;
    reg [3:0] day_visited [0:15];

    // Result variables
    reg [7:0] knight_total;
    reg [7:0] day_total;

    // Initialize state machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            edge_counter <= 0;
            done <= 0;
            error <= 0;
            wait_time <= 0;
        end else begin
            case (state)
                IDLE: begin
                    if (compute_start) begin
                        state <= LOAD_EDGES;
                        edge_counter <= 0;
                    end
                end
                LOAD_EDGES: begin
                    if (edge_valid) begin
                        edge_u_mem[edge_counter] <= edge_u;
                        edge_v_mem[edge_counter] <= edge_v;
                        edge_weight_mem[edge_counter] <= edge_weight;
                        edge_counter <= edge_counter + 1;
                        if (edge_counter == edge_count) begin
                            state <= COMPUTE_KNIGHT;
                        end
                    end
                end
                COMPUTE_KNIGHT: begin
                    // Dijkstra initialization
                    if (edge_counter == 0) begin
                        knight_dist[0] <= 0;
                        for (int i = 1; i < node_count; i = i + 1) begin
                            knight_dist[i] <= 16'hFFFF;
                        end
                        knight_visited[0] <= 1;
                        knight_current <= 0;
                        knight_next <= 0;
                        knight_min_dist <= 0;
                        knight_min_node <= 0;
                    end else begin
                        // Dijkstra step
                        knight_min_dist <= 16'hFFFF;
                        knight_min_node <= 0;
                        for (int i = 0; i < node_count; i = i + 1) begin
                            if (!knight_visited[i] && knight_dist[i] < knight_min_dist) begin
                                knight_min_dist <= knight_dist[i];
                                knight_min_node <= i;
                            end
                        end
                        if (knight_min_dist == 16'hFFFF) begin
                            state <= COMPUTE_DAY;
                        end else begin
                            knight_current <= knight_min_node;
                            knight_visited[knight_current] <= 1;
                            for (int i = 0; i < edge_count; i = i + 1) begin
                                if (edge_u_mem[i] == knight_current) begin
                                    knight_next <= edge_v_mem[i];
                                    if (knight_dist[knight_next] > knight_dist[knight_current] + edge_weight_mem[i]) begin
                                        knight_dist[knight_next] <= knight_dist[knight_current] + edge_weight_mem[i];
                                    end
                                end
                            end
                        end
                    end
                end
                COMPUTE_DAY: begin
                    // DP initialization
                    if (edge_counter == 0) begin
                        day_dist[0] <= 0;
                        for (int i = 1; i < node_count; i = i + 1) begin
                            day_dist[i] <= 16'hFFFF;
                        end
                        day_visited[0] <= 1;
                        day_current <= 0;
                        day_next <= 0;
                        day_min_dist <= 0;
                        day_min_node <= 0;
                    end else begin
                        // DP step
                        day_min_dist <= 16'hFFFF;
                        day_min_node <= 0;
                        for (int i = 0; i < node_count; i = i + 1) begin
                            if (!day_visited[i] && day_dist[i] < day_min_dist) begin
                                day_min_dist <= day_dist[i];
                                day_min_node <= i;
                            end
                        end
                        if (day_min_dist == 16'hFFFF) begin
                            state <= CALC_RESULT;
                        end else begin
                            day_current <= day_min_node;
                            day_visited[day_current] <= 1;
                            for (int i = 0; i < edge_count; i = i + 1) begin
                                if (edge_u_mem[i] == day_current) begin
                                    day_next <= edge_v_mem[i];
                                    if (day_dist[day_next] > day_dist[day_current] + edge_weight_mem[i]) begin
                                        day_dist[day_next] <= day_dist[day_current] + edge_weight_mem[i];
                                    end
                                end
                            end
                        end
                    end
                end
                CALC_RESULT: begin
                    // Calculate total hours for both strategies
                    knight_total <= knight_dist[node_count - 1];
                    day_total <= day_dist[node_count - 1];
                    if (knight_total == 16'hFFFF || day_total == 16'hFFFF) begin
                        error <= 1;
                    end else begin
                        wait_time <= day_total - knight_total;
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