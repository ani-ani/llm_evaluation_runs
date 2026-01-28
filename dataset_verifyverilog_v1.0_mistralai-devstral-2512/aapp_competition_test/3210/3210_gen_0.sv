module dots_and_boxes (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [224:0] grid_packed,
    output reg [7:0] result,
    output reg done
);

    // State definitions
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] PARSE = 2'd1;
    localparam [1:0] COMPUTE = 2'd2;
    localparam [1:0] FINISH = 2'd3;
    
    reg [1:0] state;
    reg [7:0] safe_move_count;
    reg [7:0] edge_index;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd5000;

    // Grid dimensions (N=8 for 15x15 grid)
    localparam [3:0] N = 4'd8;
    localparam [3:0] NUM_HORIZONTAL = 4'd56; // N*(N-1)
    localparam [3:0] NUM_VERTICAL = 4'd56;   // (N-1)*N
    localparam [3:0] TOTAL_EDGES = 4'd112;  // NUM_HORIZONTAL + NUM_VERTICAL

    // Internal grid representations
    reg [1:0] horizontal_edges [0:7][0:6]; // [row][col]
    reg [1:0] vertical_edges [0:6][0:7];   // [row][col]
    reg [2:0] boxes [0:7][0:7];           // [row][col], count of edges (0-4)

    // Parse grid into internal representation
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            safe_move_count <= 8'd0;
            edge_index <= 8'd0;
            cycle_count <= 8'd0;
            done <= 1'b0;
            result <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= PARSE;
                    end
                end

                PARSE: begin
                    // Parse the packed grid into horizontal and vertical edges
                    integer i, j;
                    for (i = 0; i < 15; i = i + 1) begin
                        for (j = 0; j < 15; j = j + 1) begin
                            integer idx = i * 15 + j;
                            reg [1:0] cell = grid_packed[idx*2 +: 2];
                            
                            // Horizontal edges are at odd columns (j=1,3,5,...)
                            if (i % 2 == 0 && j % 2 == 1) begin
                                horizontal_edges[i/2][j/2] <= cell;
                            end
                            
                            // Vertical edges are at odd rows (i=1,3,5,...)
                            if (i % 2 == 1 && j % 2 == 0) begin
                                vertical_edges[i/2][j/2] <= cell;
                            end
                        end
                    end
                    
                    // Initialize box edge counts
                    for (i = 0; i < 8; i = i + 1) begin
                        for (j = 0; j < 8; j = j + 1) begin
                            boxes[i][j] <= 3'd0;
                        end
                    end
                    
                    // Count edges for each box
                    for (i = 0; i < 8; i = i + 1) begin
                        for (j = 0; j < 8; j = j + 1) begin
                            // Top edge
                            if (horizontal_edges[i][j] != 2'd0) begin
                                boxes[i][j] <= boxes[i][j] + 3'd1;
                            end
                            
                            // Bottom edge
                            if (horizontal_edges[i+1][j] != 2'd0) begin
                                boxes[i][j] <= boxes[i][j] + 3'd1;
                            end
                            
                            // Left edge
                            if (vertical_edges[i][j] != 2'd0) begin
                                boxes[i][j] <= boxes[i][j] + 3'd1;
                            end
                            
                            // Right edge
                            if (vertical_edges[i][j+1] != 2'd0) begin
                                boxes[i][j] <= boxes[i][j] + 3'd1;
                            end
                        end
                    end
                    
                    state <= COMPUTE;
                end

                COMPUTE: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Check if we've processed all edges
                    if (edge_index >= TOTAL_EDGES) begin
                        state <= FINISH;
                    end else begin
                        reg can_add_edge;
                        reg [3:0] row, col;
                        reg is_horizontal;
                        
                        // Determine edge type and position
                        if (edge_index < NUM_HORIZONTAL) begin
                            is_horizontal = 1'b1;
                            row = edge_index / (N-1);
                            col = edge_index % (N-1);
                        end else begin
                            is_horizontal = 1'b0;
                            edge_index = edge_index - NUM_HORIZONTAL;
                            row = edge_index / N;
                            col = edge_index % N;
                        end
                        
                        // Check if edge is already present
                        if (is_horizontal && horizontal_edges[row][col] != 2'd0) begin
                            can_add_edge = 1'b0;
                        end else if (!is_horizontal && vertical_edges[row][col] != 2'd0) begin
                            can_add_edge = 1'b0;
                        end else begin
                            // Check if adding this edge would create any 3-edge boxes
                            can_add_edge = 1'b1;
                            
                            if (is_horizontal) begin
                                // Check top box (if exists)
                                if (row > 0) begin
                                    reg [2:0] top_box = boxes[row-1][col];
                                    if (top_box == 3'd3) begin
                                        can_add_edge = 1'b0;
                                    end
                                end
                                
                                // Check bottom box (if exists)
                                if (row < N-1) begin
                                    reg [2:0] bottom_box = boxes[row][col];
                                    if (bottom_box == 3'd3) begin
                                        can_add_edge = 1'b0;
                                    end
                                end
                            end else begin
                                // Check left box (if exists)
                                if (col > 0) begin
                                    reg [2:0] left_box = boxes[row][col-1];
                                    if (left_box == 3'd3) begin
                                        can_add_edge = 1'b0;
                                    end
                                end
                                
                                // Check right box (if exists)
                                if (col < N-1) begin
                                    reg [2:0] right_box = boxes[row][col];
                                    if (right_box == 3'd3) begin
                                        can_add_edge = 1'b0;
                                    end
                                end
                            end
                        end
                        
                        // If we can add this edge, increment count
                        if (can_add_edge) begin
                            safe_move_count <= safe_move_count + 8'd1;
                        end
                        
                        edge_index <= edge_index + 8'd1;
                    end
                    
                    // Safety check for cycle count
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= FINISH;
                    end
                end

                FINISH: begin
                    done <= 1'b1;
                    result <= safe_move_count;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule