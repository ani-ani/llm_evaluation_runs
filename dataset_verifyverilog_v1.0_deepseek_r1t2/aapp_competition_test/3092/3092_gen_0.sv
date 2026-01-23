module shortest_path_edge_counter (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] config_edge_index,
    input wire [3:0] config_src,
    input wire [3:0] config_dst,
    input wire [15:0] config_weight,
    input wire config_valid,
    input wire [3:0] num_edges,
    input wire compute_start,
    output reg [3:0] result_edge_index,
    output reg [31:0] result_count,
    output reg result_valid,
    output reg done
);

localparam MODULUS = 32'd1000000007;
localparam MAX_CITIES = 8;
localparam MAX_EDGES = 16;

// Edge memory {src[3:0], dst[3:0], weight[15:0]}
reg [23:0] edge_memory [0:15];

// FSM states
localparam [3:0] IDLE          = 4'd0;
localparam [3:0] LOAD_EDGES    = 4'd1;
localparam [3:0] COMPUTE_FLOYD = 4'd2;
localparam [3:0] COUNT_PATHS   = 4'd3;
localparam [3:0] OUTPUT_RESULTS= 4'd4;
localparam [3:0] FINISHED      = 4'd5;

reg [3:0] current_state, next_state;

// Floyd-Warshall matrices
reg [31:0] dist [0:7][0:7];
reg [31:0] paths [0:7][0:7];

// Iteration counters
reg [2:0] i, j, k;
reg [3:0] edge_idx;
reg [7:0] cycle_count;

// Helper signals
wire [3:0] edge_src = edge_memory[edge_idx][23:20];
wire [3:0] edge_dst = edge_memory[edge_idx][19:16];
wire [15:0] edge_w = edge_memory[edge_idx][15:0];

// Modulo addition function
function automatic [31:0] mod_add;
    input [31:0] a, b;
    begin
        mod_add = (a + b) % MODULUS;
    end
endfunction

// State transition
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        current_state <= IDLE;
    end else begin
        current_state <= next_state;
    end
end

// Next state logic
always @(*) begin
    next_state = current_state;
    case (current_state)
        IDLE: begin
            if (compute_start && num_edges > 0) begin
                next_state = COMPUTE_FLOYD;
            end else if (config_valid) begin
                next_state = LOAD_EDGES;
            end
        end
        LOAD_EDGES: begin
            if (!config_valid && compute_start) begin
                next_state = COMPUTE_FLOYD;
            end
        end
        COMPUTE_FLOYD: begin
            if (k == 3'd7 && i == 3'd7 && j == 3'd7) begin
                next_state = COUNT_PATHS;
            end
        end
        COUNT_PATHS: begin
            if (edge_idx >= num_edges) begin
                next_state = OUTPUT_RESULTS;
            end
        end
        OUTPUT_RESULTS: begin
            if (edge_idx >= num_edges) begin
                next_state = FINISHED;
            end
        end
        FINISHED: begin
            next_state = IDLE;
        end
        default: next_state = IDLE;
    endcase
end

// Main FSM logic
integer x, y, e;
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        result_edge_index <= 4'd0;
        result_count <= 32'd0;
        result_valid <= 1'b0;
        done <= 1'b0;
        i <= 3'd0;
        j <= 3'd0;
        k <= 3'd0;
        edge_idx <= 4'd0;
        cycle_count <= 8'd0;

        for (x = 0; x < 8; x = x + 1) begin
            for (y = 0; y < 8; y = y + 1) begin
                dist[x][y] <= (x == y) ? 32'd0 : 32'hFFFF_FFFF;
                paths[x][y] <= (x == y) ? 32'd1 : 32'd0;
            end
        end

        for (e = 0; e < 16; e = e + 1) begin
            edge_memory[e] <= 24'd0;
        end
    end else begin
        case (current_state)
            IDLE: begin
                done <= 1'b0;
                result_valid <= 1'b0;
                cycle_count <= 8'd0;
                edge_idx <= 4'd0;
                if (config_valid) begin
                    edge_memory[config_edge_index] <= {config_src, config_dst, config_weight};
                end
            end

            LOAD_EDGES: begin
                if (config_valid) begin
                    edge_memory[config_edge_index] <= {config_src, config_dst, config_weight};
                end
            end

            COMPUTE_FLOYD: begin
                cycle_count <= cycle_count + 8'd1;

                if (i == 3'd0 && j == 3'd0 && k == 3'd0) begin
                    for (e = 0; e < 16; e = e + 1) begin
                        if (e < num_edges) begin
                            automatic reg [3:0] s = edge_memory[e][23:20];
                            automatic reg [3:0] d = edge_memory[e][19:16];
                            automatic reg [15:0] w = edge_memory[e][15:0];
                            if (w < dist[s][d]) begin
                                dist[s][d] <= w;
                                paths[s][d] <= 32'd1;
                            end else if (w == dist[s][d]) begin
                                paths[s][d] <= paths[s][d] + 32'd1;
                            end
                        end
                    end
                    i <= 3'd0;
                    j <= 3'd0;
                    k <= 3'd0;
                end else begin
                    automatic reg [31:0] dist_ik = dist[i][k];
                    automatic reg [31:0] dist_kj = dist[k][j];
                    automatic reg [31:0] new_dist = dist_ik + dist_kj;

                    if (dist_ik != 32'hFFFF_FFFF && dist_kj != 32'hFFFF_FFFF) begin
                        if (new_dist < dist[i][j]) begin
                            dist[i][j] <= new_dist;
                            paths[i][j] <= (paths[i][k] * paths[k][j]) % MODULUS;
                        end else if (new_dist == dist[i][j]) begin
                            paths[i][j] <= mod_add(paths[i][j], (paths[i][k] * paths[k][j]) % MODULUS);
                        end
                    end

                    // Update indices
                    if (j < 3'd7) begin
                        j <= j + 3'd1;
                    end else begin
                        j <= 3'd0;
                        if (i < 3'd7) begin
                            i <= i + 3'd1;
                        end else begin
                            i <= 3'd0;
                            if (k < 3'd7) begin
                                k <= k + 3'd1;
                            end else begin
                                k <= 3'd7;
                            end
                        end
                    end
                end
            end

            COUNT_PATHS: begin
                if (edge_idx < num_edges) begin
                    automatic reg [31:0] count = 32'd0;

                    for (x = 0; x < 8; x = x + 1) begin
                        for (y = 0; y < 8; y = y + 1) begin
                            if (x != y && dist[x][edge_src] != 32'hFFFF_FFFF && dist[edge_dst][y] != 32'hFFFF_FFFF) begin
                                automatic reg [31:0] total_dist = dist[x][edge_src] + edge_w + dist[edge_dst][y];
                                if (total_dist == dist[x][y]) begin
                                    count = mod_add(count, (paths[x][edge_src] * paths[edge_dst][y]) % MODULUS);
                                end
                            end
                        end
                    end

                    result_edge_index <= edge_idx;
                    result_count <= count;
                    result_valid <= 1'b1;
                    edge_idx <= edge_idx + 4'd1;
                end else begin
                    result_valid <= 1'b0;
                end
            end

            OUTPUT_RESULTS: begin
                result_valid <= 1'b0;
            end

            FINISHED: begin
                done <= 1'b1;
            end
        endcase
    end
end

endmodule