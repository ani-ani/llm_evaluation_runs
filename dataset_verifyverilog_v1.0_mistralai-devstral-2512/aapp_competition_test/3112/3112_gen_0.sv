module MaxActiveProducers(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire config_valid,
    input wire [31:0] edge_src,
    input wire [31:0] edge_dst,
    input wire [4:0] num_edges,
    input wire [3:0] num_producers,
    output reg [3:0] result,
    output reg done
);

    // Constants
    localparam [3:0] MAX_NODES = 4'd16;
    localparam [4:0] MAX_EDGES = 5'd32;
    localparam [3:0] MAX_PRODUCERS = 4'd8;
    localparam [7:0] INF = 8'd31;

    // State declarations
    localparam [3:0] IDLE = 4'd0;
    localparam [3:0] COMPUTE_DISTANCES = 4'd1;
    localparam [3:0] CHECK_SUBSETS = 4'd2;
    localparam [3:0] FINISH = 4'd3;

    // Internal registers
    reg [3:0] state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd500;

    // Distance arrays (flattened for synthesis)
    reg [7:0] dist [0:MAX_PRODUCERS-1][0:MAX_NODES-1];
    integer i, j, k, m, n;

    // Subset checking variables
    reg [7:0] current_mask;
    reg [3:0] max_active;
    reg [3:0] current_count;
    reg valid_mask;

    // BFS variables
    reg [3:0] current_producer;
    reg [3:0] current_node;
    reg [7:0] current_dist;
    reg [3:0] queue [0:MAX_NODES-1];
    reg [3:0] queue_head;
    reg [3:0] queue_tail;

    // Edge processing
    reg [3:0] edge_index;
    reg [3:0] producer_i;
    reg [3:0] producer_j;
    reg [3:0] node_u;
    reg [3:0] node_v;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 4'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            current_mask <= 8'd0;
            max_active <= 4'd0;
            current_count <= 4'd0;
            valid_mask <= 1'b0;
            current_producer <= 4'd0;
            current_node <= 4'd0;
            current_dist <= 8'd0;
            queue_head <= 4'd0;
            queue_tail <= 4'd0;
            edge_index <= 4'd0;
            producer_i <= 4'd0;
            producer_j <= 4'd0;
            node_u <= 4'd0;
            node_v <= 4'd0;

            // Initialize distance arrays
            for (i = 0; i < MAX_PRODUCERS; i = i + 1) begin
                for (j = 0; j < MAX_NODES; j = j + 1) begin
                    dist[i][j] <= INF;
                end
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start && config_valid) begin
                        state <= COMPUTE_DISTANCES;
                        current_producer <= 4'd0;
                    end
                end

                COMPUTE_DISTANCES: begin
                    cycle_count <= cycle_count + 8'd1;

                    // Initialize BFS for current producer
                    if (current_producer == 4'd0) begin
                        // Initialize queue
                        queue_head <= 4'd0;
                        queue_tail <= 4'd0;
                        
                        // Reset distances for this producer
                        for (i = 0; i < MAX_NODES; i = i + 1) begin
                            dist[current_producer][i] <= INF;
                        end
                        
                        // Set distance for producer node (node = current_producer + 1)
                        dist[current_producer][current_producer] <= 8'd0;
                        queue[queue_tail] <= current_producer;
                        queue_tail <= queue_tail + 4'd1;
                    end

                    // BFS iteration
                    if (queue_head < queue_tail) begin
                        current_node <= queue[queue_head];
                        current_dist <= dist[current_producer][current_node];
                        queue_head <= queue_head + 4'd1;

                        // Check all edges
                        for (i = 0; i < num_edges; i = i + 1) begin
                            node_u <= edge_src[(i*8)+:4];
                            node_v <= edge_dst[(i*8)+:4];
                            
                            if (node_u == current_node) begin
                                if (dist[current_producer][node_v] == INF) begin
                                    dist[current_producer][node_v] <= current_dist + 8'd1;
                                    queue[queue_tail] <= node_v;
                                    queue_tail <= queue_tail + 4'd1;
                                end
                            end
                        end
                    end else begin
                        // Move to next producer
                        current_producer <= current_producer + 4'd1;
                        if (current_producer >= num_producers) begin
                            state <= CHECK_SUBSETS;
                            current_mask <= 8'd1;
                            max_active <= 4'd0;
                        end
                    end
                end

                CHECK_SUBSETS: begin
                    cycle_count <= cycle_count + 8'd1;

                    // Check if current mask is valid
                    valid_mask <= 1'b1;
                    producer_i <= 4'd0;
                    producer_j <= 4'd0;
                    edge_index <= 4'd0;

                    // Check all pairs of producers in the mask
                    for (i = 0; i < num_producers; i = i + 1) begin
                        if (current_mask[i]) begin
                            for (j = i + 1; j < num_producers; j = j + 1) begin
                                if (current_mask[j]) begin
                                    // Check all edges
                                    for (k = 0; k < num_edges; k = k + 1) begin
                                        node_u <= edge_src[(k*8)+:4];
                                        node_v <= edge_dst[(k*8)+:4];
                                        
                                        // Check if both producers reach node_u
                                        if (dist[i][node_u] != INF && dist[j][node_u] != INF) begin
                                            // Check parity
                                            if ((dist[i][node_u][0] == dist[j][node_u][0])) begin
                                                valid_mask <= 1'b0;
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end

                    // Update max_active if valid
                    if (valid_mask) begin
                        current_count <= 4'd0;
                        for (i = 0; i < num_producers; i = i + 1) begin
                            if (current_mask[i]) begin
                                current_count <= current_count + 4'd1;
                            end
                        end
                        
                        if (current_count > max_active) begin
                            max_active <= current_count;
                        end
                    end

                    // Move to next mask
                    current_mask <= current_mask + 8'd1;
                    if (current_mask >= (1 << num_producers)) begin
                        state <= FINISH;
                    end
                end

                FINISH: begin
                    result <= max_active;
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule