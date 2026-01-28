module SurfaceAreaCalculator (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] num_defects,
    input wire [2:0] defect_x [0:255],
    input wire [2:0] defect_y [0:255],
    input wire [2:0] defect_z [0:255],
    output reg [15:0] result,
    output reg done
);

    // Grid dimensions (5x5x5 = 125 cells)
    localparam [3:0] GRID_DIM = 4'd5;
    localparam [7:0] TOTAL_CELLS = 8'd125;

    // State definitions
    localparam [2:0] IDLE          = 3'd0;
    localparam [2:0] INIT_GRID     = 3'd1;
    localparam [2:0] POPULATE      = 3'd2;
    localparam [2:0] COMPUTE       = 3'd3;
    localparam [2:0] FINISH        = 3'd4;

    // Internal state registers
    reg [2:0] state;
    reg [2:0] next_state;
    reg [7:0] counter;          // Generic counter
    reg [7:0] defect_idx;       // Index into defect arrays
    reg [7:0] cell_idx;         // Index for grid traversal (0-124)
    reg [15:0] area_sum;        // Accumulated surface area

    // Occupancy grid: 5x5x5 boolean (125 bits)
    // Access: grid[x][y][z]
    reg [4:0] grid [0:4][0:4][0:4];
    
    // Neighbor coordinates
    reg signed [3:0] x, y, z;
    reg signed [3:0] nx, ny, nz;
    reg neighbor_occupied;

    // Update logic for state machine
    always @(*) begin
        case (state)
            IDLE:         next_state = start ? INIT_GRID : IDLE;
            INIT_GRID:    next_state = (counter >= GRID_DIM) ? POPULATE : INIT_GRID;
            POPULATE:     next_state = (defect_idx >= num_defects) ? COMPUTE : POPULATE;
            COMPUTE:      next_state = (cell_idx >= TOTAL_CELLS) ? FINISH : COMPUTE;
            FINISH:       next_state = IDLE;
            default:      next_state = IDLE;
        endcase
    end

    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            counter <= 8'd0;
            defect_idx <= 8'd0;
            cell_idx <= 8'd0;
            area_sum <= 16'd0;
            x <= 4'sd0;
            y <= 4'sd0;
            z <= 4'sd0;
            // Initialize all grid cells to 0
            for (integer i = 0; i < 5; i = i + 1) begin
                for (integer j = 0; j < 5; j = j + 1) begin
                    for (integer k = 0; k < 5; k = k + 1) begin
                        grid[i][j][k] <= 1'b0;
                    end
                end
            end
        end else begin
            state <= next_state;
            done <= 1'b0;
            
            case (state)
                IDLE: begin
                    result <= 16'd0;
                    counter <= 8'd0;
                    defect_idx <= 8'd0;
                    cell_idx <= 8'd0;
                    area_sum <= 16'd0;
                    x <= 4'sd0;
                    y <= 4'sd0;
                    z <= 4'sd0;
                end

                INIT_GRID: begin
                    // Initialize grid rows for current x
                    if (counter < GRID_DIM) begin
                        for (integer j = 0; j < 5; j = j + 1) begin
                            for (integer k = 0; k < 5; k = k + 1) begin
                                grid[counter][j][k] <= 1'b0;
                            end
                        end
                        counter <= counter + 8'd1;
                    end
                end

                POPULATE: begin
                    if (defect_idx < num_defects) begin
                        // Clamp coordinates to 0-4 range and mark occupied
                        if (defect_x[defect_idx] < 5) begin
                            if (defect_y[defect_idx] < 5) begin
                                if (defect_z[defect_idx] < 5) begin
                                    grid[defect_x[defect_idx]][defect_y[defect_idx]][defect_z[defect_idx]] <= 1'b1;
                                end
                            end
                        end
                        defect_idx <= defect_idx + 8'd1;
                    end
                end

                COMPUTE: begin
                    if (cell_idx < TOTAL_CELLS) begin
                        // Convert linear index to 3D coordinates
                        x <= cell_idx / 25;
                        y <= (cell_idx % 25) / 5;
                        z <= cell_idx % 5;
                        
                        // Check if current cell is occupied
                        if (grid[cell_idx / 25][(cell_idx % 25) / 5][cell_idx % 5] == 1'b1) begin
                            // Check 6 neighbors
                            // +X
                            nx <= (cell_idx / 25) + 1;
                            ny <= (cell_idx % 25) / 5;
                            nz <= cell_idx % 5;
                            if ((nx >= 0) && (nx < 5)) begin
                                if (grid[nx][ny][nz] == 1'b0) begin
                                    area_sum <= area_sum + 16'd1;
                                end
                            end else begin
                                area_sum <= area_sum + 16'd1;
                            end
                            
                            // -X
                            nx <= (cell_idx / 25) - 1;
                            if ((nx >= 0) && (nx < 5)) begin
                                if (grid[nx][ny][nz] == 1'b0) begin
                                    area_sum <= area_sum + 16'd1;
                                end
                            end else begin
                                area_sum <= area_sum + 16'd1;
                            end
                            
                            // +Y
                            nx <= cell_idx / 25;
                            ny <= ((cell_idx % 25) / 5) + 1;
                            if ((ny >= 0) && (ny < 5)) begin
                                if (grid[nx][ny][nz] == 1'b0) begin
                                    area_sum <= area_sum + 16'd1;
                                end
                            end else begin
                                area_sum <= area_sum + 16'd1;
                            end
                            
                            // -Y
                            ny <= ((cell_idx % 25) / 5) - 1;
                            if ((ny >= 0) && (ny < 5)) begin
                                if (grid[nx][ny][nz] == 1'b0) begin
                                    area_sum <= area_sum + 16'd1;
                                end
                            end else begin
                                area_sum <= area_sum + 16'd1;
                            end
                            
                            // +Z
                            ny <= (cell_idx % 25) / 5;
                            nz <= (cell_idx % 5) + 1;
                            if ((nz >= 0) && (nz < 5)) begin
                                if (grid[nx][ny][nz] == 1'b0) begin
                                    area_sum <= area_sum + 16'd1;
                                end
                            end else begin
                                area_sum <= area_sum + 16'd1;
                            end
                            
                            // -Z
                            nz <= (cell_idx % 5) - 1;
                            if ((nz >= 0) && (nz < 5)) begin
                                if (grid[nx][ny][nz] == 1'b0) begin
                                    area_sum <= area_sum + 16'd1;
                                end
                            end else begin
                                area_sum <= area_sum + 16'd1;
                            end
                        end
                        cell_idx <= cell_idx + 8'd1;
                    end
                end

                FINISH: begin
                    result <= area_sum;
                    done <= 1'b1;
                end

                default: begin
                    state <= IDLE;
                    result <= 16'd0;
                    done <= 1'b0;
                end
            endcase
        end
    end
endmodule