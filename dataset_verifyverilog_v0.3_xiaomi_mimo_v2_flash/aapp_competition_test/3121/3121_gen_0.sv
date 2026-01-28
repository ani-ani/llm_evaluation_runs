module CaveSystem (
    input clk, rst_n, start,
    input [15:0] A, H,
    input [3:0] n, m,
    input [3:0] from_0, to_0, from_1, to_1, from_2, to_2, from_3, to_3,
    input [3:0] from_4, to_4, from_5, to_5, from_6, to_6, from_7, to_7,
    input [3:0] from_8, to_8, from_9, to_9, from_10, to_10, from_11, to_11,
    input [3:0] from_12, to_12, from_13, to_13, from_14, to_14, from_15, to_15,
    input [15:0] a_0, h_0, a_1, h_1, a_2, h_2, a_3, h_3,
    input [15:0] a_4, h_4, a_5, h_5, a_6, h_6, a_7, h_7,
    input [15:0] a_8, h_8, a_9, h_9, a_10, h_10, a_11, h_11,
    input [15:0] a_12, h_12, a_13, h_13, a_14, h_14, a_15, h_15,
    output reg [31:0] result,
    output reg done
);

// States
localparam [2:0] IDLE = 3'b000;
localparam [2:0] PRECOMP = 3'b001;
localparam [2:0] DIJK_INIT = 3'b010;
localparam [2:0] DIJK_SELECT = 3'b011;
localparam [2:0] DIJK_RELAX = 3'b100;
localparam [2:0] OUTPUT = 3'b101;

reg [2:0] state;
reg [3:0] edge_cnt, node_cnt;
reg [3:0] current_node;
reg [31:0] k_reg, damage_reg;

// Edge buffer
reg [3:0] edge_from [0:15];
reg [3:0] edge_to [0:15];
reg [31:0] edge_damage [0:15];

// Dijkstra storage
reg [31:0] dist [0:7];
reg visited [0:7];

// Cycle counter
reg [7:0] cycle_count;
localparam [7:0] MAX_CYCLES = 8'd200;

// Helper functions
function [3:0] get_from(input [3:0] idx);
    case(idx)
        0: get_from = from_0; 1: get_from = from_1; 2: get_from = from_2; 3: get_from = from_3;
        4: get_from = from_4; 5: get_from = from_5; 6: get_from = from_6; 7: get_from = from_7;
        8: get_from = from_8; 9: get_from = from_9; 10: get_from = from_10; 11: get_from = from_11;
        12: get_from = from_12; 13: get_from = from_13; 14: get_from = from_14; 15: get_from = from_15;
        default: get_from = 4'b0;
    endcase
endfunction

function [3:0] get_to(input [3:0] idx);
    case(idx)
        0: get_to = to_0; 1: get_to = to_1; 2: get_to = to_2; 3: get_to = to_3;
        4: get_to = to_4; 5: get_to = to_5; 6: get_to = to_6; 7: get_to = to_7;
        8: get_to = to_8; 9: get_to = to_9; 10: get_to = to_10; 11: get_to = to_11;
        12: get_to = to_12; 13: get_to = to_13; 14: get_to = to_14; 15: get_to = to_15;
        default: get_to = 4'b0;
    endcase
endfunction

function [15:0] get_a(input [3:0] idx);
    case(idx)
        0: get_a = a_0; 1: get_a = a_1; 2: get_a = a_2; 3: get_a = a_3;
        4: get_a = a_4; 5: get_a = a_5; 6: get_a = a_6; 7: get_a = a_7;
        8: get_a = a_8; 9: get_a = a_9; 10: get_a = a_10; 11: get_a = a_11;
        12: get_a = a_12; 13: get_a = a_13; 14: get_a = a_14; 15: get_a = a_15;
        default: get_a = 16'b0;
    endcase
endfunction

function [15:0] get_h(input [3:0] idx);
    case(idx)
        0: get_h = h_0; 1: get_h = h_1; 2: get_h = h_2; 3: get_h = h_3;
        4: get_h = h_4; 5: get_h = h_5; 6: get_h = h_6; 7: get_h = h_7;
        8: get_h = h_8; 9: get_h = h_9; 10: get_h = h_10; 11: get_h = h_11;
        12: get_h = h_12; 13: get_h = h_13; 14: get_h = h_14; 15: get_h = h_15;
        default: get_h = 16'b0;
    endcase
endfunction

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        done <= 0;
        result <= 0;
        edge_cnt <= 0;
        node_cnt <= 0;
        current_node <= 0;
        cycle_count <= 0;
        k_reg <= 0;
        damage_reg <= 0;
        // Initialize arrays
        for (integer i = 0; i < 8; i = i + 1) begin
            visited[i] <= 0;
            dist[i] <= 32'hFFFFFFFF;
        end
        for (integer i = 0; i < 16; i = i + 1) begin
            edge_from[i] <= 0;
            edge_to[i] <= 0;
            edge_damage[i] <= 0;
        end
    end else begin
        case (state)
            IDLE: begin
                done <= 0;
                cycle_count <= 0;
                if (start) begin
                    state <= PRECOMP;
                    edge_cnt <= 0;
                end
            end

            PRECOMP: begin
                if (cycle_count < MAX_CYCLES) begin
                    cycle_count <= cycle_count + 1;
                    if (edge_cnt < m) begin
                        // Get edge data
                        edge_from[edge_cnt] <= get_from(edge_cnt);
                        edge_to[edge_cnt] <= get_to(edge_cnt);
                        // Calculate k and damage
                        if (A != 0) begin
                            k_reg <= ({16'h0, get_h(edge_cnt)} + {16'h0, A} - 32'h1) / {16'h0, A};
                        end else begin
                            k_reg <= 0;
                        end
                        edge_cnt <= edge_cnt + 1;
                        state <= PRECOMP;
                    end else begin
                        state <= DIJK_INIT;
                        edge_cnt <= 0;
                    end
                end else begin
                    state <= OUTPUT; // Timeout
                end
            end

            DIJK_INIT: begin
                if (cycle_count < MAX_CYCLES) begin
                    cycle_count <= cycle_count + 1;
                    if (edge_cnt < m) begin
                        // Store damage from previous calculation
                        if (k_reg > 32'h1) begin
                            edge_damage[edge_cnt] <= (k_reg - 32'h1) * {16'h0, get_a(edge_cnt)};
                        end else begin
                            edge_damage[edge_cnt] <= 0;
                        end
                        edge_cnt <= edge_cnt + 1;
                        state <= DIJK_INIT;
                    end else begin
                        // Initialize Dijkstra
                        dist[0] <= 0;
                        for (integer i = 1; i < 8; i = i + 1) begin
                            dist[i] <= 32'hFFFFFFFF;
                        end
                        for (integer i = 0; i < 8; i = i + 1) begin
                            visited[i] <= 0;
                        end
                        state <= DIJK_SELECT;
                        node_cnt <= 0;
                        current_node <= 8'hFF;
                    end
                end else begin
                    state <= OUTPUT;
                end
            end

            DIJK_SELECT: begin
                if (cycle_count < MAX_CYCLES) begin
                    cycle_count <= cycle_count + 1;
                    if (node_cnt < n) begin
                        // Find unvisited node with minimum dist
                        if (!visited[node_cnt]) begin
                            if (current_node == 8'hFF || dist[node_cnt] < dist[current_node]) begin
                                current_node <= node_cnt;
                            end
                        end
                        node_cnt <= node_cnt + 1;
                        state <= DIJK_SELECT;
                    end else begin
                        if (current_node != 8'hFF && current_node < n && !visited[current_node]) begin
                            state <= DIJK_RELAX;
                            edge_cnt <= 0;
                            visited[current_node] <= 1;
                        end else begin
                            state <= OUTPUT;
                        end
                        node_cnt <= 0;
                    end
                end else begin
                    state <= OUTPUT;
                end
            end

            DIJK_RELAX: begin
                if (cycle_count < MAX_CYCLES) begin
                    cycle_count <= cycle_count + 1;
                    if (edge_cnt < m) begin
                        if (edge_from[edge_cnt] == current_node) begin
                            // Check for valid destination node
                            if (edge_to[edge_cnt] < n) begin
                                if (dist[edge_to[edge_cnt]] > dist[current_node] + edge_damage[edge_cnt]) begin
                                    dist[edge_to[edge_cnt]] <= dist[current_node] + edge_damage[edge_cnt];
                                end
                            end
                        end
                        edge_cnt <= edge_cnt + 1;
                        state <= DIJK_RELAX;
                    end else begin
                        state <= DIJK_SELECT;
                        node_cnt <= 0;
                        current_node <= 8'hFF;
                    end
                end else begin
                    state <= OUTPUT;
                end
            end

            OUTPUT: begin
                // Compute result
                if (n == 0) begin
                    result <= 32'hFFFFFFFF;
                end else if (dist[n-1] < H) begin
                    result <= H - dist[n-1];
                end else begin
                    result <= 32'hFFFFFFFF;
                end
                done <= 1;
                state <= IDLE;
            end

            default: begin
                state <= IDLE;
                done <= 0;
            end
        endcase
    end
end

endmodule