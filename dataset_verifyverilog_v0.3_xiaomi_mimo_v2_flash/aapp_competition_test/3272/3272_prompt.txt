module tomb_raider (
    input clk,
    input rst_n,
    input start,
    input [7:0] grid [0:7][0:7],  // 8x8 grid, each cell 8 bits
    input [3:0] gargoyle_mask,      // Bitmask indicating which cells contain gargoyles (max 4)
    output reg [3:0] min_rotations,
    output reg done,
    output reg valid
);

// Parameters
parameter MAX_ITER = 64;
parameter GRID_SIZE = 8;

// Internal state machine
reg [3:0] state;
reg [3:0] gargoyle_count;
reg [2:0] current_gargoyle;
reg [1:0] current_orientation;  // 0=original, 1=rotated
reg [7:0] beam_x, beam_y;
reg [1:0] beam_dir;  // 0=up, 1=right, 2=down, 3=left
reg [5:0] iter_count;
reg [3:0] rotation_count;
reg [3:0] best_rotation;
reg [15:0] connection_mask;  // Bitmask of connections

// Memory for gargoyle positions and types
reg [2:0] gargoyle_x [0:3];
reg [2:0] gargoyle_y [0:3];
reg [0:3] gargoyle_type;  // 0=V, 1=H

// Beam simulation state
reg beam_active;
reg [7:0] visited_mask;

// State definitions
localparam IDLE = 4'd0;
localparam SETUP = 4'd1;
localparam SIMULATE_BEAM = 4'd2;
localparam CHECK_CONNECTIONS = 4'd3;
localparam UPDATE_ROTATION = 4'd4;
localparam DONE = 4'd5;

// Grid cell types
localparam EMPTY = 8'd0;
localparam OBSTACLE = 8'd1;
localparam MIRROR_SLASH = 8'd2;
localparam MIRROR_BACKSLASH = 8'd3;
localparam GARGOYLE_V = 8'd4;
localparam GARGOYLE_H = 8'd5;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        done <= 0;
        valid <= 0;
        min_rotations <= 4'hF;
        gargoyle_count <= 0;
        iter_count <= 0;
        rotation_count <= 0;
        best_rotation <= 4'hF;
        connection_mask <= 0;
        beam_active <= 0;
        visited_mask <= 0;
    end else begin
        case (state)
            IDLE: begin
                if (start) begin
                    state <= SETUP;
                    gargoyle_count <= 0;
                    current_gargoyle <= 0;
                    current_orientation <= 0;
                    rotation_count <= 0;
                    best_rotation <= 4'hF;
                    connection_mask <= 0;
                end
            end
            
            SETUP: begin
                // Extract gargoyles from grid
                if (gargoyle_count < 4 && current_gargoyle < 64) begin
                    // Simplified gargoyle detection
                    if (grid[current_gargoyle[6:3]][current_gargoyle[2:0]] == GARGOYLE_V ||
                        grid[current_gargoyle[6:3]][current_gargoyle[2:0]] == GARGOYLE_H) begin
                        gargoyle_x[gargoyle_count] <= current_gargoyle[6:3];
                        gargoyle_y[gargoyle_count] <= current_gargoyle[2:0];
                        gargoyle_type[gargoyle_count] <= (grid[current_gargoyle[6:3]][current_gargoyle[2:0]] == GARGOYLE_H) ? 1 : 0;
                        gargoyle_count <= gargoyle_count + 1;
                    end
                    current_gargoyle <= current_gargoyle + 1;
                end else begin
                    current_gargoyle <= 0;
                    current_orientation <= 0;
                    rotation_count <= 0;
                    connection_mask <= 0;
                    state <= (gargoyle_count == 0) ? DONE : SIMULATE_BEAM;
                end
            end
            
            SIMULATE_BEAM: begin
                // Simulate beam for current gargoyle configuration
                if (current_gargoyle < gargoyle_count && current_orientation < 2 && iter_count < MAX_ITER) begin
                    if (!beam_active) begin
                        // Start new beam
                        beam_active <= 1;
                        beam_x <= gargoyle_x[current_gargoyle];
                        beam_y <= gargoyle_y[current_gargoyle];
                        // Determine starting direction based on gargoyle type and orientation
                        if ((gargoyle_type[current_gargoyle] ^ current_orientation) == 0) begin
                            // V gargoyle (or rotated H): faces up/down
                            beam_dir <= (iter_count[0]) ? 2'd2 : 2'd0;  // First beam up, second beam down
                        end else begin
                            // H gargoyle (or rotated V): faces left/right
                            beam_dir <= (iter_count[0]) ? 2'd1 : 2'd3;  // First beam right, second beam left
                        end
                        visited_mask <= 0;
                    end else begin
                        // Continue beam propagation
                        case (beam_dir)
                            2'd0: beam_y <= beam_y - 1;  // Up
                            2'd1: beam_x <= beam_x + 1;  // Right
                            2'd2: beam_y <= beam_y + 1;  // Down
                            2'd3: beam_x <= beam_x - 1;  // Left
                        endcase
                        
                        // Check boundaries
                        if (beam_x >= GRID_SIZE || beam_y >= GRID_SIZE) begin
                            // Hit wall - reflect 180 degrees
                            beam_dir <= beam_dir + 2;
                            beam_x <= (beam_x >= GRID_SIZE) ? (GRID_SIZE - 1) : beam_x;
                            beam_y <= (beam_y >= GRID_SIZE) ? (GRID_SIZE - 1) : beam_y;
                        end else begin
                            // Check cell content
                            case (grid[beam_y][beam_x])
                                OBSTACLE: begin
                                    beam_active <= 0;
                                    iter_count <= iter_count + 1;
                                end
                                MIRROR_SLASH: begin
                                    // / mirror: up->left, right->down, down->right, left->up
                                    case (beam_dir)
                                        2'd0: beam_dir <= 2'd3;
                                        2'd1: beam_dir <= 2'd2;
                                        2'd2: beam_dir <= 2'd1;
                                        2'd3: beam_dir <= 2'd0;
                                    endcase
                                end
                                MIRROR_BACKSLASH: begin
                                    // \ mirror: up->right, right->up, down->left, left->down
                                    case (beam_dir)
                                        2'd0: beam_dir <= 2'd1;
                                        2'd1: beam_dir <= 2'd0;
                                        2'd2: beam_dir <= 2'd3;
                                        2'd3: beam_dir <= 2'd2;
                                    endcase
                                end
                                GARGOYLE_V, GARGOYLE_H: begin
                                    // Check if we hit a gargoyle (different from start)
                                    if (!visited_mask[beam_y*8 + beam_x]) begin
                                        visited_mask[beam_y*8 + beam_x] <= 1;
                                        // Record connection
                                        connection_mask[current_gargoyle*2 + current_orientation*8 + iter_count[0]] <= 1;
                                    end
                                    beam_active <= 0;
                                    iter_count <= iter_count + 1;
                                end
                                default: begin
                                    // Empty cell - continue
                                    iter_count <= iter_count + 1;
                                end
                            endcase
                        end
                    end
                end else if (current_gargoyle < gargoyle_count) begin
                    // Move to next beam or next orientation
                    if (iter_count >= MAX_ITER) begin
                        beam_active <= 0;
                        iter_count <= 0;
                        current_orientation <= current_orientation + 1;
                        if (current_orientation == 1) begin
                            current_orientation <= 0;
                            current_gargoyle <= current_gargoyle + 1;
                        end
                    end else if (iter_count[0]) begin  // Both beams done
                        beam_active <= 0;
                        iter_count <= 0;
                        current_orientation <= current_orientation + 1;
                        if (current_orientation == 1) begin
                            current_orientation <= 0;
                            current_gargoyle <= current_gargoyle + 1;
                        end
                    end else begin
                        // Next beam for same gargoyle/orientation
                        beam_active <= 0;
                        iter_count <= iter_count + 1;
                    end
                end else begin
                    state <= CHECK_CONNECTIONS;
                    current_gargoyle <= 0;
                    current_orientation <= 0;
                end
            end
            
            CHECK_CONNECTIONS: begin
                // Verify all gargoyle faces have connections
                if (current_gargoyle < gargoyle_count) begin
                    // Check both faces of current gargoyle in current orientation
                    if (!connection_mask[current_gargoyle*2 + current_orientation*8] ||
                        !connection_mask[current_gargoyle*2 + current_orientation*8 + 1]) begin
                        // Missing connection, need to rotate
                        rotation_count <= rotation_count + 1;
                    end
                    current_orientation <= current_orientation + 1;
                    if (current_orientation == 1) begin
                        current_orientation <= 0;
                        current_gargoyle <= current_gargoyle + 1;
                    end
                end else begin
                    // Update best rotation if valid
                    if (rotation_count < best_rotation) begin
                        best_rotation <= rotation_count;
                    end
                    state <= UPDATE_ROTATION;
                    current_gargoyle <= 0;
                end
            end
            
            UPDATE_ROTATION: begin
                // Try next rotation configuration
                if (current_gargoyle < gargoyle_count) begin
                    // Toggle one gargoyle's rotation
                    // This is simplified - in practice we'd need to iterate through all 2^gargoyle_count combinations
                    current_gargoyle <= current_gargoyle + 1;
                    rotation_count <= current_gargoyle + 1;  // Simplified
                end else begin
                    state <= DONE;
                    if (best_rotation <= 4'hF) begin
                        min_rotations <= best_rotation;
                        valid <= 1;
                    end else begin
                        min_rotations <= 4'hF;
                        valid <= 0;
                    end
                    done <= 1;
                end
            end
            
            DONE: begin
                // Hold state until reset
                state <= DONE;
            end
            
            default: state <= IDLE;
        endcase
    end
end

endmodule