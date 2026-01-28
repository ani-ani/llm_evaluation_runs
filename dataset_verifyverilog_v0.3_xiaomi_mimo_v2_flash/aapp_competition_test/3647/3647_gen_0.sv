module IceMazeSolver #(
    parameter ROWS = 4,
    parameter COLS = 4,
    parameter CELL_COUNT = 16,
    parameter DATA_WIDTH = 2,
    parameter DIST_WIDTH = 5,
    parameter DIR_COUNT = 4,
    parameter MAX_CYCLES = 256
)(
    input clk,
    input rst_n,
    input start,
    input [CELL_COUNT*DATA_WIDTH-1:0] grid_data,
    output reg [CELL_COUNT*DIST_WIDTH-1:0] distances_data,
    output reg done
);
    // State encoding
    localparam [3:0] IDLE = 4'd0;
    localparam [3:0] SETUP = 4'd1;
    localparam [3:0] CHECK_CELL = 4'd2;
    localparam [3:0] CALC_SLIDE = 4'd3;
    localparam [3:0] UPDATE = 4'd4;
    localparam [3:0] NEXT_DIR = 4'd5;
    localparam [3:0] NEXT_CELL = 4'd6;
    localparam [3:0] FINISHED = 4'd7;
    
    reg [3:0] state;
    
    // Grid and distance storage - unpack into arrays
    reg [DATA_WIDTH-1:0] grid [0:CELL_COUNT-1];
    reg [DIST_WIDTH-1:0] dist [0:CELL_COUNT-1];
    reg [DIST_WIDTH-1:0] next_dist [0:CELL_COUNT-1];
    
    // Current cell and direction
    reg [5:0] curr_cell;
    reg [1:0] curr_dir;
    reg [8:0] cycle_count;
    
    // Slide computation
    reg [3:0] slide_r, slide_c;
    reg [3:0] next_r, next_c;
    reg [5:0] target_idx;
    reg slide_active;
    reg slide_done;
    
    // Helper: convert coordinates to linear index
    function automatic [5:0] coord_to_idx;
        input [3:0] r, c;
        begin
            coord_to_idx = r * COLS + c;
        end
    endfunction
    
    // Unpack grid_data into array (combinational)
    integer g;
    always @(*) begin
        for (g = 0; g < CELL_COUNT; g = g + 1) begin
            grid[g] = grid_data[g*DATA_WIDTH +: DATA_WIDTH];
        end
    end
    
    // Slide computation combinational logic
    always @(*) begin
        slide_done = 0;
        next_r = slide_r;
        next_c = slide_c;
        target_idx = coord_to_idx(slide_r, slide_c);
        
        if (slide_active) begin
            // Calculate next position based on direction
            case (curr_dir)
                2'b00: next_r = slide_r - 4'd1; // up
                2'b01: next_r = slide_r + 4'd1; // down
                2'b10: next_c = slide_c - 4'd1; // left
                2'b11: next_c = slide_c + 4'd1; // right
                default: next_r = slide_r;
            endcase
            
            // Check boundaries
            if (next_r >= ROWS || next_c >= COLS) begin
                slide_done = 1;
            end else begin
                // Check cell type
                case (grid[coord_to_idx(next_r, next_c)])
                    2'b00: slide_done = 1; // obstacle
                    2'b01, 2'b11: begin // gravel or goal
                        target_idx = coord_to_idx(next_r, next_c);
                        slide_done = 1;
                    end
                    2'b10: begin // ice - continue sliding
                        // Update for next iteration
                        slide_r = next_r;
                        slide_c = next_c;
                    end
                    default: slide_done = 1;
                endcase
            end
        end
    end
    
    // State machine and distance updates
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 0;
            cycle_count <= 9'd0;
            slide_active <= 0;
            slide_done <= 0;
            curr_cell <= 6'd0;
            curr_dir <= 2'd0;
            slide_r <= 4'd0;
            slide_c <= 4'd0;
            target_idx <= 6'd0;
            // Reset distances to INF (31)
            for (integer i = 0; i < CELL_COUNT; i = i + 1) begin
                dist[i] <= {DIST_WIDTH{1'b1}};
                next_dist[i] <= {DIST_WIDTH{1'b1}};
            end
            distances_data <= {CELL_COUNT*DIST_WIDTH{1'b0}};
        end else begin
            case (state)
                IDLE: begin
                    done <= 0;
                    cycle_count <= 9'd0;
                    slide_active <= 0;
                    if (start) begin
                        state <= SETUP;
                    end
                end
                SETUP: begin
                    // Find goal and set distance to 0
                    for (integer i = 0; i < CELL_COUNT; i = i + 1) begin
                        if (grid[i] == 2'b11) begin
                            dist[i] <= {DIST_WIDTH{1'b0}};
                            next_dist[i] <= {DIST_WIDTH{1'b0}};
                        end else begin
                            dist[i] <= {DIST_WIDTH{1'b1}};
                            next_dist[i] <= {DIST_WIDTH{1'b1}};
                        end
                    end
                    curr_cell <= 6'd0;
                    curr_dir <= 2'd0;
                    cycle_count <= 9'd0;
                    state <= CHECK_CELL;
                end
                CHECK_CELL: begin
                    if (curr_cell < CELL_COUNT && cycle_count < MAX_CYCLES) begin
                        if (dist[curr_cell] != {DIST_WIDTH{1'b1}}) begin
                            // Calculate starting position for slide
                            slide_r <= curr_cell / COLS;
                            slide_c <= curr_cell % COLS;
                            slide_active <= 1;
                            state <= CALC_SLIDE;
                        end else begin
                            state <= NEXT_CELL;
                        end
                    end else begin
                        state <= FINISHED;
                    end
                end
                CALC_SLIDE: begin
                    if (slide_done) begin
                        slide_active <= 0;
                        state <= UPDATE;
                    end
                end
                UPDATE: begin
                    if (target_idx != curr_cell && target_idx < CELL_COUNT) begin
                        // Update distance using reverse edge: dist[target] = min(dist[target], dist[curr] + 1)
                        if (next_dist[target_idx] > dist[curr_cell] + 1) begin
                            next_dist[target_idx] <= dist[curr_cell] + 1;
                        end
                    end
                    state <= NEXT_DIR;
                end
                NEXT_DIR: begin
                    if (curr_dir < DIR_COUNT - 1) begin
                        curr_dir <= curr_dir + 2'd1;
                        state <= CHECK_CELL;
                    end else begin
                        state <= NEXT_CELL;
                    end
                end
                NEXT_CELL: begin
                    curr_cell <= curr_cell + 6'd1;
                    curr_dir <= 2'd0;
                    cycle_count <= cycle_count + 9'd1;
                    // Update all distances at end of iteration
                    for (integer i = 0; i < CELL_COUNT; i = i + 1) begin
                        dist[i] <= next_dist[i];
                    end
                    state <= CHECK_CELL;
                end
                FINISHED: begin
                    // Pack distances into output
                    for (integer i = 0; i < CELL_COUNT; i = i + 1) begin
                        distances_data[i*DIST_WIDTH +: DIST_WIDTH] <= dist[i];
                    end
                    done <= 1;
                    state <= IDLE;
                end
                default: state <= IDLE;
            endcase
        end
    end
endmodule