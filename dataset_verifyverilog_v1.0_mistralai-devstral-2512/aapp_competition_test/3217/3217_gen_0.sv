module PanelCounter(
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

    // State declarations
    localparam [2:0] IDLE      = 3'd0;
    localparam [2:0] LOAD      = 3'd1;
    localparam [2:0] COMPUTE   = 3'd2;
    localparam [2:0] FINISH    = 3'd3;
    
    reg [2:0] state;
    reg [7:0] defect_index;
    reg [7:0] cell_index;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd1000;

    // Occupancy grid: 5x5x5 = 125 bits
    reg [4:0] x;
    reg [4:0] y;
    reg [4:0] z;
    reg occupied [0:4][0:4][0:4];

    // Surface area computation
    reg [15:0] surface_area;
    reg [2:0] nx, ny, nz;
    reg neighbor_occupied;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            defect_index <= 8'd0;
            cell_index <= 8'd0;
            cycle_count <= 8'd0;
            result <= 16'd0;
            done <= 1'b0;
            surface_area <= 16'd0;
            
            // Initialize occupancy grid
            integer i, j, k;
            for (i = 0; i < 5; i = i + 1) begin
                for (j = 0; j < 5; j = j + 1) begin
                    for (k = 0; k < 5; k = k + 1) begin
                        occupied[i][j][k] <= 1'b0;
                    end
                end
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= LOAD;
                        defect_index <= 8'd0;
                    end
                end
                
                LOAD: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Load defect coordinates into occupancy grid
                    if (defect_index < num_defects) begin
                        x <= defect_x[defect_index];
                        y <= defect_y[defect_index];
                        z <= defect_z[defect_index];
                        occupied[x][y][z] <= 1'b1;
                        defect_index <= defect_index + 8'd1;
                    end else begin
                        defect_index <= 8'd0;
                        cell_index <= 8'd0;
                        surface_area <= 16'd0;
                        state <= COMPUTE;
                    end
                    
                    // Safety: prevent infinite loops
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= FINISH;
                    end
                end
                
                COMPUTE: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Iterate through all cells
                    x <= cell_index[6:4];
                    y <= cell_index[3:1];
                    z <= cell_index[0];
                    
                    if (occupied[x][y][z]) begin
                        // Check all 6 neighbors
                        surface_area <= surface_area + 16'd6;
                        
                        // Check -x neighbor
                        nx <= x - 3'd1;
                        if (nx < 5'd0) begin
                            if (occupied[nx][y][z]) begin
                                surface_area <= surface_area - 16'd1;
                            end
                        end
                        
                        // Check +x neighbor
                        nx <= x + 3'd1;
                        if (nx < 5'd5) begin
                            if (occupied[nx][y][z]) begin
                                surface_area <= surface_area - 16'd1;
                            end
                        end
                        
                        // Check -y neighbor
                        ny <= y - 3'd1;
                        if (ny < 5'd0) begin
                            if (occupied[x][ny][z]) begin
                                surface_area <= surface_area - 16'd1;
                            end
                        end
                        
                        // Check +y neighbor
                        ny <= y + 3'd1;
                        if (ny < 5'd5) begin
                            if (occupied[x][ny][z]) begin
                                surface_area <= surface_area - 16'd1;
                            end
                        end
                        
                        // Check -z neighbor
                        nz <= z - 3'd1;
                        if (nz < 5'd0) begin
                            if (occupied[x][y][nz]) begin
                                surface_area <= surface_area - 16'd1;
                            end
                        end
                        
                        // Check +z neighbor
                        nz <= z + 3'd1;
                        if (nz < 5'd5) begin
                            if (occupied[x][y][nz]) begin
                                surface_area <= surface_area - 16'd1;
                            end
                        end
                    end
                    
                    // Move to next cell
                    cell_index <= cell_index + 8'd1;
                    
                    // Check if all cells processed
                    if (cell_index >= 8'd125) begin
                        result <= surface_area;
                        state <= FINISH;
                    end
                    
                    // Safety: prevent infinite loops
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= FINISH;
                    end
                end
                
                FINISH: begin
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end

endmodule