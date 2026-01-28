module min_max_angle_route(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] node_count,
    input wire [15:0] max_dist,
    input wire [3:0] src_node,
    input wire [3:0] dst_node,
    input wire [3:0] edges_i,
    input wire [3:0] edges_a,
    input wire [3:0] edges_b,
    input wire [3:0] coord_x_i,
    input wire [15:0] coord_x,
    input wire [15:0] coord_y,
    output reg [4:0] result_angle_bin,
    output reg [31:0] result_angle_deg,
    output reg result_valid,
    output reg done,
    output reg impossible
);

    // Constants
    localparam [3:0] MAX_NODES = 4'd16;
    localparam [5:0] MAX_EDGES = 6'd64;
    localparam [4:0] ANGLE_BINS = 5'd32;
    localparam [4:0] MAX_ANGLE_BIN = 5'd31;

    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] LOAD_COORDS = 3'd1;
    localparam [2:0] LOAD_EDGES = 3'd2;
    localparam [2:0] COMPUTE = 3'd3;
    localparam [2:0] DONE_STATE = 3'd4;

    // Registers
    reg [2:0] state, next_state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd200;

    // Coordinate storage (16 nodes, 32-bit each: X[15:0], Y[31:16])
    reg signed [31:0] coord_mem [0:15];
    reg [3:0] coord_ptr;

    // Edge storage (64 edges, 8-bit each: src[3:0], dst[3:0])
    reg [7:0] edge_mem [0:63];
    reg [5:0] edge_ptr;

    // State memory (16 nodes * 32 angle bins)
    reg [15:0] best_distance [0:15][0:31];
    reg [4:0] max_angle_bin [0:15][0:31];
    reg visited [0:15][0:31];

    // Priority queue (32 angle bins)
    reg [3:0] queue [0:31];
    reg [4:0] queue_ptr;

    // Current processing state
    reg [3:0] current_node;
    reg [4:0] current_angle_bin;
    reg [15:0] current_distance;

    // Temporary calculations
    reg signed [15:0] dx1, dy1, dx2, dy2;
    reg signed [31:0] dot_product;
    reg [15:0] mag1, mag2;
    reg [4:0] turn_angle_bin;

    // FSM
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result_angle_bin <= 5'd0;
            result_angle_deg <= 32'd0;
            result_valid <= 1'b0;
            done <= 1'b0;
            impossible <= 1'b0;
            cycle_count <= 8'd0;
            coord_ptr <= 4'd0;
            edge_ptr <= 6'd0;
            queue_ptr <= 5'd0;
            
            // Initialize state memory
            integer i, j;
            for (i = 0; i < 16; i = i + 1) begin
                for (j = 0; j < 32; j = j + 1) begin
                    best_distance[i][j] <= 16'd32768; // Max value
                    max_angle_bin[i][j] <= 5'd0;
                    visited[i][j] <= 1'b0;
                end
            end
            
            // Initialize queue
            for (i = 0; i < 32; i = i + 1) begin
                queue[i] <= 4'd0;
            end
        end else begin
            state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = LOAD_COORDS;
                end
            end
            
            LOAD_COORDS: begin
                if (coord_ptr == node_count - 1) begin
                    next_state = LOAD_EDGES;
                end
            end
            
            LOAD_EDGES: begin
                if (edge_ptr == MAX_EDGES - 1) begin
                    next_state = COMPUTE;
                end
            end
            
            COMPUTE: begin
                if (done || cycle_count >= MAX_CYCLES) begin
                    next_state = DONE_STATE;
                end
            end
            
            DONE_STATE: begin
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end

    // Coordinate loading
    always @(posedge clk) begin
        if (state == LOAD_COORDS && coord_ptr < node_count) begin
            coord_mem[coord_ptr] <= {coord_y, coord_x};
            coord_ptr <= coord_ptr + 1;
        end
    end

    // Edge loading
    always @(posedge clk) begin
        if (state == LOAD_EDGES && edge_ptr < MAX_EDGES) begin
            edge_mem[edge_ptr] <= {edges_b, edges_a};
            edge_ptr <= edge_ptr + 1;
        end
    end

    // Main computation
    always @(posedge clk) begin
        if (state == COMPUTE) begin
            cycle_count <= cycle_count + 1;
            
            // Process queue
            if (queue_ptr < 32 && queue[queue_ptr] != 4'd0) begin
                current_node <= queue[queue_ptr];
                current_angle_bin <= queue_ptr;
                current_distance <= best_distance[current_node][current_angle_bin];
                visited[current_node][current_angle_bin] <= 1'b1;
                queue[queue_ptr] <= 4'd0;
                queue_ptr <= queue_ptr + 1;
                
                // Check if destination reached
                if (current_node == dst_node) begin
                    result_angle_bin <= current_angle_bin;
                    result_angle_deg <= $signed(current_angle_bin) * 32'd11250; // 11.25° per bin in Q16.16
                    result_valid <= 1'b1;
                    done <= 1'b1;
                end
                
                // Process outgoing edges
                integer k;
                for (k = 0; k < MAX_EDGES; k = k + 1) begin
                    if (edge_mem[k][3:0] == current_node) begin
                        reg [3:0] next_node = edge_mem[k][7:4];
                        
                        // Calculate turning angle
                        // Get coordinates
                        reg signed [15:0] x1 = coord_mem[current_node][15:0];
                        reg signed [15:0] y1 = coord_mem[current_node][31:16];
                        reg signed [15:0] x2 = coord_mem[next_node][15:0];
                        reg signed [15:0] y2 = coord_mem[next_node][31:16];
                        
                        dx1 = x2 - x1;
                        dy1 = y2 - y1;
                        
                        // Calculate angle bin (simplified for example)
                        // In real implementation, use LUT or CORDIC
                        turn_angle_bin = 5'd0; // Placeholder
                        
                        // Update state
                        reg [4:0] new_angle_bin = (turn_angle_bin > current_angle_bin) ? turn_angle_bin : current_angle_bin;
                        reg [15:0] edge_distance = 16'd100; // Placeholder
                        reg [15:0] new_distance = current_distance + edge_distance;
                        
                        if (new_distance <= max_dist && 
                            (new_angle_bin < max_angle_bin[next_node][new_angle_bin] ||
                             (new_angle_bin == max_angle_bin[next_node][new_angle_bin] && 
                              new_distance < best_distance[next_node][new_angle_bin]))) begin
                            best_distance[next_node][new_angle_bin] <= new_distance;
                            max_angle_bin[next_node][new_angle_bin] <= new_angle_bin;
                            
                            // Add to queue
                            queue[new_angle_bin] <= next_node;
                        end
                    end
                end
            end else begin
                // Queue empty
                if (!result_valid) begin
                    impossible <= 1'b1;
                    done <= 1'b1;
                end
            end
        end
    end

    // Initial state setup
    always @(posedge clk) begin
        if (state == COMPUTE && cycle_count == 1) begin
            // Initialize source node (angle_bin = 0)
            best_distance[src_node][0] <= 16'd0;
            max_angle_bin[src_node][0] <= 5'd0;
            queue[0] <= src_node;
        end
    end

endmodule