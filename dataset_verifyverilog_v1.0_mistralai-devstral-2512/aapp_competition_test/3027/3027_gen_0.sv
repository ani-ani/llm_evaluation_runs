module StampMinNubs(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [255:0] grid_in,
    input wire [3:0] height,
    input wire [3:0] width,
    output reg [7:0] result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] LOAD = 3'd1;
    localparam [2:0] COMPUTE = 3'd2;
    localparam [2:0] FINISH = 3'd3;
    
    reg [2:0] state, next_state;
    
    // Grid storage
    reg [15:0] grid [0:15];
    reg [3:0] grid_height, grid_width;
    
    // Offset counters
    reg [4:0] dx, dy;
    reg signed [4:0] dx_signed, dy_signed;
    
    // Stamp calculation
    reg [15:0] stamp [0:15];
    reg [7:0] min_nubs;
    reg [7:0] current_nubs;
    
    // Control signals
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd2000;
    
    // Initialize all registers
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            result <= 8'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            
            // Initialize grid
            integer i;
            for (i = 0; i < 16; i = i + 1) begin
                grid[i] <= 16'd0;
            end
            
            grid_height <= 4'd0;
            grid_width <= 4'd0;
            dx <= 5'd0;
            dy <= 5'd0;
            dx_signed <= 5'd0;
            dy_signed <= 5'd0;
            min_nubs <= 8'd255;
            current_nubs <= 8'd0;
            
            // Initialize stamp
            for (i = 0; i < 16; i = i + 1) begin
                stamp[i] <= 16'd0;
            end
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        next_state <= LOAD;
                    end
                end
                
                LOAD: begin
                    // Load grid data
                    integer i, j;
                    for (i = 0; i < 16; i = i + 1) begin
                        for (j = 0; j < 16; j = j + 1) begin
                            grid[i][j] <= grid_in[255 - (i * 16 + j)];
                        end
                    end
                    
                    grid_height <= height;
                    grid_width <= width;
                    
                    // Initialize offset counters
                    dx <= 5'd0;
                    dy <= 5'd0;
                    dx_signed <= 5'd0;
                    dy_signed <= 5'd0;
                    
                    min_nubs <= 8'd255;
                    next_state <= COMPUTE;
                end
                
                COMPUTE: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Calculate stamp for current offset
                    integer r, c;
                    reg [15:0] temp_stamp [0:15];
                    
                    // Initialize temp_stamp to all 1s
                    for (r = 0; r < 16; r = r + 1) begin
                        temp_stamp[r] <= 16'hFFFF;
                    end
                    
                    // Calculate stamp as intersection
                    for (r = 0; r < 16; r = r + 1) begin
                        for (c = 0; c < 16; c = c + 1) begin
                            // Check if both positions are within grid
                            reg valid_pos1, valid_pos2;
                            valid_pos1 = (r < grid_height) && (c < grid_width);
                            valid_pos2 = (r + dy_signed >= 0) && (r + dy_signed < grid_height) && 
                                        (c + dx_signed >= 0) && (c + dx_signed < grid_width);
                            
                            if (valid_pos1 && valid_pos2) begin
                                temp_stamp[r][c] <= grid[r][c] && grid[r + dy_signed][c + dx_signed];
                            end else begin
                                temp_stamp[r][c] <= 1'b0;
                            end
                        end
                    end
                    
                    // Copy temp_stamp to stamp
                    for (r = 0; r < 16; r = r + 1) begin
                        stamp[r] <= temp_stamp[r];
                    end
                    
                    // Calculate popcount of stamp
                    current_nubs <= 8'd0;
                    for (r = 0; r < 16; r = r + 1) begin
                        for (c = 0; c < 16; c = c + 1) begin
                            current_nubs <= current_nubs + stamp[r][c];
                        end
                    end
                    
                    // Verify if this stamp is valid
                    reg valid_stamp;
                    valid_stamp = 1'b1;
                    
                    for (r = 0; r < 16; r = r + 1) begin
                        for (c = 0; c < 16; c = c + 1) begin
                            reg covered;
                            covered = 1'b0;
                            
                            // Check if covered by stamp at (0,0)
                            if (r < grid_height && c < grid_width && stamp[r][c]) begin
                                covered = 1'b1;
                            end
                            
                            // Check if covered by stamp at (dx,dy)
                            if (r - dy_signed >= 0 && r - dy_signed < grid_height && 
                                c - dx_signed >= 0 && c - dx_signed < grid_width && 
                                stamp[r - dy_signed][c - dx_signed]) begin
                                covered = 1'b1;
                            end
                            
                            // If grid has '#' but not covered, invalid
                            if (grid[r][c] && !covered) begin
                                valid_stamp = 1'b0;
                            end
                            
                            // If grid has '.' but covered, invalid
                            if (!grid[r][c] && covered) begin
                                valid_stamp = 1'b0;
                            end
                        end
                    end
                    
                    // Update minimum if valid
                    if (valid_stamp && current_nubs < min_nubs) begin
                        min_nubs <= current_nubs;
                    end
                    
                    // Move to next offset
                    dx <= dx + 5'd1;
                    dx_signed <= dx_signed + 5'd1;
                    
                    // Check if we've covered all offsets for current dy
                    if (dx_signed == (grid_width - 1) || dx_signed == -(grid_width - 1) + 1) begin
                        dx <= 5'd0;
                        dx_signed <= 5'd0;
                        
                        dy <= dy + 5'd1;
                        dy_signed <= dy_signed + 5'd1;
                        
                        // Check if we've covered all offsets
                        if (dy_signed == (grid_height - 1) || dy_signed == -(grid_height - 1) + 1) begin
                            next_state <= FINISH;
                        end
                    end
                    
                    // Safety check for max cycles
                    if (cycle_count >= MAX_CYCLES) begin
                        next_state <= FINISH;
                    end
                end
                
                FINISH: begin
                    result <= min_nubs;
                    done <= 1'b1;
                    next_state <= IDLE;
                end
                
                default: next_state <= IDLE;
            endcase
        end
    end
endmodule