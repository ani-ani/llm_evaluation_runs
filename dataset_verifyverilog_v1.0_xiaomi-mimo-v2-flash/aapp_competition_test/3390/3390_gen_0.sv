module MaxPathLength(
    input clk,
    input rst_n,
    input start,
    input [3:0] n,
    input [5:0] m,
    input [3:0] edge_a,
    input [3:0] edge_b,
    output reg [7:0] result,
    output reg done,
    output reg valid
);

    // State declarations
    localparam [2:0] IDLE      = 3'd0;
    localparam [2:0] LOAD_EDGES = 3'd1;
    localparam [2:0] COMPUTE   = 3'd2;
    localparam [2:0] UPDATE    = 3'd3;
    localparam [2:0] FINISH    = 3'd4;
    localparam [2:0] ERROR     = 3'd5;

    // Edge storage: 32 edges max, each 8 bits (4 bits a, 4 bits b)
    reg [7:0] edge_storage [0:31];
    reg [7:0] dist [0:15];
    reg [7:0] next_dist [0:15];
    reg [4:0] edge_count;
    reg [3:0] node_count;
    reg [4:0] edge_idx;
    reg [3:0] node_idx;
    reg [3:0] cycle_detect [0:3];
    reg [1:0] cycle_count;
    reg [7:0] max_dist;
    reg [7:0] temp_dist;
    reg [7:0] result_reg;
    reg [7:0] cycle_check;
    reg [7:0] i;
    reg [7:0] j;
    reg found_cycle;
    reg change_detected;
    reg [7:0] cycle_counter;
    localparam [7:0] MAX_CYCLE_LIMIT = 8'd250;
    
    // State and next state registers
    reg [2:0] state;
    reg [2:0] next_state;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 8'd0;
            done <= 1'b0;
            valid <= 1'b0;
            edge_count <= 5'd0;
            node_count <= 4'd0;
            edge_idx <= 5'd0;
            node_idx <= 4'd0;
            max_dist <= 8'd0;
            result_reg <= 8'd0;
            cycle_count <= 2'd0;
            cycle_counter <= 8'd0;
            found_cycle <= 1'b0;
            change_detected <= 1'b0;
            // Initialize arrays
            for (i = 0; i < 32; i = i + 1) begin
                edge_storage[i] <= 8'd0;
            end
            for (j = 0; j < 16; j = j + 1) begin
                dist[j] <= 8'd0;
                next_dist[j] <= 8'd0;
            end
            for (j = 0; j < 4; j = j + 1) begin
                cycle_detect[j] <= 4'd0;
            end
        end else begin
            state <= next_state;
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    valid <= 1'b0;
                    edge_count <= 5'd0;
                    edge_idx <= 5'd0;
                    node_idx <= 4'd0;
                    max_dist <= 8'd0;
                    result_reg <= 8'd0;
                    cycle_count <= 2'd0;
                    cycle_counter <= 8'd0;
                    found_cycle <= 1'b0;
                    change_detected <= 1'b0;
                end
                LOAD_EDGES: begin
                    if (edge_count < m) begin
                        edge_storage[edge_count] <= {edge_a, edge_b};
                        edge_count <= edge_count + 5'd1;
                    end
                end
                COMPUTE: begin
                    // Initialize distances
                    if (node_idx < n) begin
                        dist[node_idx] <= (node_idx == 4'd0) ? 8'd0 : 8'd0;
                        next_dist[node_idx] <= (node_idx == 4'd0) ? 8'd0 : 8'd0;
                        node_idx <= node_idx + 4'd1;
                    end
                end
                UPDATE: begin
                    cycle_counter <= cycle_counter + 8'd1;
                    change_detected <= 1'b0;
                    if (edge_idx < edge_count) begin
                        // Process edge
                        edge_idx <= edge_idx + 5'd1;
                        temp_dist <= dist[edge_storage[edge_idx][7:4]] + 8'd1;
                        if (temp_dist > next_dist[edge_storage[edge_idx][3:0]]) begin
                            next_dist[edge_storage[edge_idx][3:0]] <= temp_dist;
                            change_detected <= 1'b1;
                        end
                    end else begin
                        // End of iteration
                        edge_idx <= 5'd0;
                        if (change_detected && cycle_counter < MAX_CYCLE_LIMIT) begin
                            // Update dist array
                            for (i = 0; i < n; i = i + 1) begin
                                dist[i] <= next_dist[i];
                            end
                            change_detected <= 1'b0;
                        end else begin
                            // No more changes or timeout
                            // Find max distance
                            max_dist <= 8'd0;
                            for (i = 0; i < n; i = i + 1) begin
                                if (dist[i] > max_dist) begin
                                    max_dist <= dist[i];
                                end
                            end
                        end
                    end
                end
                FINISH: begin
                    result_reg <= max_dist + 8'd1;
                    result <= max_dist + 8'd1;
                    done <= 1'b1;
                    valid <= 1'b1;
                end
                ERROR: begin
                    done <= 1'b1;
                    valid <= 1'b0;
                    result <= 8'd0;
                end
            endcase
        end
    end

    always @(*) begin
        case (state)
            IDLE: begin
                if (start && n <= 4'd16 && m <= 6'd32 && m != 6'd0)
                    next_state = LOAD_EDGES;
                else
                    next_state = IDLE;
            end
            LOAD_EDGES: begin
                if (edge_count >= m)
                    next_state = COMPUTE;
                else
                    next_state = LOAD_EDGES;
            end
            COMPUTE: begin
                if (node_idx >= n)
                    next_state = UPDATE;
                else
                    next_state = COMPUTE;
            end
            UPDATE: begin
                if (edge_idx >= edge_count && (!change_detected || cycle_counter >= MAX_CYCLE_LIMIT))
                    next_state = FINISH;
                else if (edge_idx >= edge_count && change_detected && cycle_counter < MAX_CYCLE_LIMIT)
                    next_state = UPDATE;
                else
                    next_state = UPDATE;
            end
            FINISH: next_state = IDLE;
            ERROR: next_state = IDLE;
            default: next_state = IDLE;
        endcase
    end
endmodule