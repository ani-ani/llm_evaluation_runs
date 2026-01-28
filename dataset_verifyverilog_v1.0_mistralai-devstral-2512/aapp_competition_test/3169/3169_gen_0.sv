module StickRemoval(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [2:0] N,
    input wire [9:0] x1_0, input wire [9:0] y1_0, input wire [9:0] x2_0, input wire [9:0] y2_0,
    input wire [9:0] x1_1, input wire [9:0] y1_1, input wire [9:0] x2_1, input wire [9:0] y2_1,
    input wire [9:0] x1_2, input wire [9:0] y1_2, input wire [9:0] x2_2, input wire [9:0] y2_2,
    input wire [9:0] x1_3, input wire [9:0] y1_3, input wire [9:0] x2_3, input wire [9:0] y2_3,
    input wire [9:0] x1_4, input wire [9:0] y1_4, input wire [9:0] x2_4, input wire [9:0] y2_4,
    input wire [9:0] x1_5, input wire [9:0] y1_5, input wire [9:0] x2_5, input wire [9:0] y2_5,
    input wire [9:0] x1_6, input wire [9:0] y1_6, input wire [9:0] x2_6, input wire [9:0] y2_6,
    input wire [9:0] x1_7, input wire [9:0] y1_7, input wire [9:0] x2_7, input wire [9:0] y2_7,
    output reg [31:0] result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] STORE = 3'd1;
    localparam [2:0] BUILD_GRAPH = 3'd2;
    localparam [2:0] TOPO_SORT = 3'd3;
    localparam [2:0] OUTPUT = 3'd4;

    reg [2:0] state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd250;

    // Stick coordinate storage
    reg [9:0] x1 [0:7];
    reg [9:0] y1 [0:7];
    reg [9:0] x2 [0:7];
    reg [9:0] y2 [0:7];

    // Graph representation
    reg [7:0] in_degree [0:7];
    reg [7:0] adj_matrix [0:7];

    // Topological sort variables
    reg [7:0] queue [0:7];
    reg [2:0] queue_head, queue_tail;
    reg [2:0] result_index;
    reg [3:0] result_temp [0:7];

    // Current stick indices for processing
    reg [2:0] i_reg, j_reg;

    // Helper signals for intersection check
    reg [9:0] x1_i, y1_i, x2_i, y2_i;
    reg [9:0] x1_j, y1_j, x2_j, y2_j;
    reg [9:0] x1_min_i, x1_max_i, y1_min_i, y1_max_i;
    reg [9:0] x1_min_j, x1_max_j, y1_min_j, y1_max_j;
    reg x_overlap, y_overlap;
    reg blocks;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 32'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;

            // Initialize all registers
            for (integer k = 0; k < 8; k = k + 1) begin
                x1[k] <= 10'd0;
                y1[k] <= 10'd0;
                x2[k] <= 10'd0;
                y2[k] <= 10'd0;
                in_degree[k] <= 8'd0;
                adj_matrix[k] <= 8'd0;
                queue[k] <= 8'd0;
                result_temp[k] <= 4'd0;
            end
            queue_head <= 3'd0;
            queue_tail <= 3'd0;
            result_index <= 3'd0;
            i_reg <= 3'd0;
            j_reg <= 3'd0;
        end else begin
            cycle_count <= cycle_count + 8'd1;

            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= STORE;
                        cycle_count <= 8'd0;
                    end
                end

                STORE: begin
                    // Store all stick coordinates
                    x1[0] <= x1_0; y1[0] <= y1_0; x2[0] <= x2_0; y2[0] <= y2_0;
                    x1[1] <= x1_1; y1[1] <= y1_1; x2[1] <= x2_1; y2[1] <= y2_1;
                    x1[2] <= x1_2; y1[2] <= y1_2; x2[2] <= x2_2; y2[2] <= y2_2;
                    x1[3] <= x1_3; y1[3] <= y1_3; x2[3] <= x2_3; y2[3] <= y2_3;
                    x1[4] <= x1_4; y1[4] <= y1_4; x2[4] <= x2_4; y2[4] <= y2_4;
                    x1[5] <= x1_5; y1[5] <= y1_5; x2[5] <= x2_5; y2[5] <= y2_5;
                    x1[6] <= x1_6; y1[6] <= y1_6; x2[6] <= x2_6; y2[6] <= y2_6;
                    x1[7] <= x1_7; y1[7] <= y1_7; x2[7] <= x2_7; y2[7] <= y2_7;
                    
                    state <= BUILD_GRAPH;
                    i_reg <= 3'd0;
                    j_reg <= 3'd0;
                end

                BUILD_GRAPH: begin
                    // Process each pair (i,j)
                    if (i_reg < N && j_reg < N) begin
                        // Load coordinates for current pair
                        x1_i <= x1[i_reg]; y1_i <= y1[i_reg]; x2_i <= x2[i_reg]; y2_i <= y2[i_reg];
                        x1_j <= x1[j_reg]; y1_j <= y1[j_reg]; x2_j <= x2[j_reg]; y2_j <= y2[j_reg];
                        
                        // Compute bounding boxes
                        x1_min_i <= (x1_i < x2_i) ? x1_i : x2_i;
                        x1_max_i <= (x1_i > x2_i) ? x1_i : x2_i;
                        y1_min_i <= (y1_i < y2_i) ? y1_i : y2_i;
                        y1_max_i <= (y1_i > y2_i) ? y1_i : y2_i;

                        x1_min_j <= (x1_j < x2_j) ? x1_j : x2_j;
                        x1_max_j <= (x1_j > x2_j) ? x1_j : x2_j;
                        y1_min_j <= (y1_j < y2_j) ? y1_j : y2_j;
                        y1_max_j <= (y1_j > y2_j) ? y1_j : y2_j;

                        // Check x overlap
                        x_overlap <= (x1_min_i <= x1_max_j) && (x1_max_i >= x1_min_j);
                        
                        // Check y overlap (stick i translated down to y=0)
                        y_overlap <= (y1_min_i <= y1_max_j) && (y1_max_i >= y1_min_j);
                        
                        // Stick i blocks stick j if they overlap
                        blocks <= x_overlap && y_overlap;
                        
                        if (blocks && (i_reg != j_reg)) begin
                            // i blocks j, so add edge i->j
                            adj_matrix[i_reg][j_reg] <= 1'b1;
                            in_degree[j_reg] <= in_degree[j_reg] + 8'd1;
                        end
                        
                        // Move to next j
                        j_reg <= j_reg + 3'd1;
                        
                        if (j_reg >= N) begin
                            j_reg <= 3'd0;
                            i_reg <= i_reg + 3'd1;
                        end
                    end else begin
                        state <= TOPO_SORT;
                        queue_head <= 3'd0;
                        queue_tail <= 3'd0;
                        result_index <= 3'd0;
                        
                        // Initialize queue with nodes having in_degree 0
                        for (integer k = 0; k < 8; k = k + 1) begin
                            if (k < N && in_degree[k] == 8'd0) begin
                                queue[queue_tail] <= k;
                                queue_tail <= queue_tail + 3'd1;
                            end
                        end
                    end
                end

                TOPO_SORT: begin
                    if (queue_head != queue_tail) begin
                        // Dequeue a node
                        result_temp[result_index] <= queue[queue_head];
                        result_index <= result_index + 3'd1;
                        
                        // Remove this node from graph
                        integer current = queue[queue_head];
                        for (integer k = 0; k < 8; k = k + 1) begin
                            if (k < N && adj_matrix[current][k]) begin
                                in_degree[k] <= in_degree[k] - 8'd1;
                                if (in_degree[k] == 8'd0) begin
                                    queue[queue_tail] <= k;
                                    queue_tail <= queue_tail + 3'd1;
                                end
                            end
                        end
                        queue_head <= queue_head + 3'd1;
                    end else begin
                        // Pack result
                        result <= {result_temp[7], result_temp[6], result_temp[5], result_temp[4],
                                  result_temp[3], result_temp[2], result_temp[1], result_temp[0]};
                        state <= OUTPUT;
                    end
                end

                OUTPUT: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule