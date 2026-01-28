module PacManZamboni (
    input clk,
    input rst_n,
    input start,
    input [4:0] row_start,
    input [4:0] col_start,
    output reg done,
    output reg grid_valid,
    output reg [7:0] grid_data,
    output reg [5:0] grid_addr
);

    // State declarations
    localparam [1:0] IDLE       = 2'd0;
    localparam [1:0] INIT_GRID  = 2'd1;
    localparam [1:0] SIMULATE   = 2'd2;
    localparam [1:0] OUTPUT     = 2'd3;

    // Direction constants (0=Up, 1=Right, 2=Down, 3=Left)
    localparam [1:0] UP    = 2'd0;
    localparam [1:0] RIGHT = 2'd1;
    localparam [1:0] DOWN  = 2'd2;
    localparam [1:0] LEFT  = 2'd3;

    // Grid memory (5x5 = 25 cells)
    reg [7:0] grid [0:24];
    
    // Control registers
    reg [1:0] state;
    reg [1:0] next_state;
    reg [1:0] direction;
    reg [4:0] color;  // 0-25 for A-Z
    reg [3:0] step_size;  // 1-4
    reg [2:0] step_counter;  // For tracking steps during movement
    reg [2:0] move_counter;  // For counting total moves in simulation
    reg [4:0] row;
    reg [4:0] col;
    reg [4:0] init_counter;
    reg [4:0] output_counter;
    
    // Helper wires for wrapping arithmetic
    wire [4:0] new_col;
    wire [4:0] new_row;
    wire [7:0] ascii_char;
    
    // ASCII conversion
    assign ascii_char = (color < 26) ? (8'h41 + color) : 8'h2E; // 'A' + color, or '.'
    
    // Wrapped column calculation (handles negative and overflow)
    assign new_col = (col >= 5) ? (col - 5) : (col > 4 ? col : col);
    // Note: col is 5-bit unsigned, negative won't happen in standard logic
    // But we handle the modulo 5 arithmetic explicitly
    
    // State transition logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            grid_valid <= 1'b0;
            grid_addr <= 6'd0;
            grid_data <= 8'd0;
            // Initialize all grid cells to '.'
            grid[0] <= 8'h2E;
            grid[1] <= 8'h2E;
            grid[2] <= 8'h2E;
            grid[3] <= 8'h2E;
            grid[4] <= 8'h2E;
            grid[5] <= 8'h2E;
            grid[6] <= 8'h2E;
            grid[7] <= 8'h2E;
            grid[8] <= 8'h2E;
            grid[9] <= 8'h2E;
            grid[10] <= 8'h2E;
            grid[11] <= 8'h2E;
            grid[12] <= 8'h2E;
            grid[13] <= 8'h2E;
            grid[14] <= 8'h2E;
            grid[15] <= 8'h2E;
            grid[16] <= 8'h2E;
            grid[17] <= 8'h2E;
            grid[18] <= 8'h2E;
            grid[19] <= 8'h2E;
            grid[20] <= 8'h2E;
            grid[21] <= 8'h2E;
            grid[22] <= 8'h2E;
            grid[23] <= 8'h2E;
            grid[24] <= 8'h2E;
            direction <= UP;
            color <= 5'd0;
            step_size <= 4'd1;
            step_counter <= 3'd0;
            move_counter <= 3'd0;
            row <= 5'd0;
            col <= 5'd0;
            init_counter <= 5'd0;
            output_counter <= 5'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    grid_valid <= 1'b0;
                    direction <= UP;
                    color <= 5'd0;
                    step_size <= 4'd1;
                    step_counter <= 3'd0;
                    move_counter <= 3'd0;
                    init_counter <= 5'd0;
                    output_counter <= 5'd0;
                    if (start) begin
                        row <= row_start;
                        col <= col_start;
                        state <= INIT_GRID;
                    end
                end

                INIT_GRID: begin
                    // Initialize all cells to '.' (done in reset, but ensuring here)
                    if (init_counter < 25) begin
                        // Already initialized in reset, just progress state
                        init_counter <= init_counter + 5'd1;
                    end else begin
                        state <= SIMULATE;
                    end
                end

                SIMULATE: begin
                    // Simulation logic: 4 iterations (0,1,2,3)
                    if (move_counter < 4) begin
                        // Movement phase
                        if (step_counter < step_size) begin
                            // Move one step in current direction
                            case (direction)
                                UP:    row <= (row == 0) ? 5'd4 : (row - 5'd1);
                                DOWN:  row <= (row == 4) ? 5'd0 : (row + 5'd1);
                                LEFT:  col <= (col == 0) ? 5'd4 : (col - 5'd1);
                                RIGHT: col <= (col == 4) ? 5'd0 : (col + 5'd1);
                            endcase
                            step_counter <= step_counter + 3'd1;
                        end else begin
                            // Move complete, rotate and increment
                            direction <= (direction + 2'd1) % 2'd3 + 2'd1; // (dir + 1) % 4 logic
                            // Actually: (dir + 1) % 4 = (dir == 3) ? 0 : dir + 1
                            if (direction == 2'd3) direction <= UP;
                            else direction <= direction + 2'd1;
                            
                            color <= (color + 5'd1) % 5'd26;
                            step_size <= (step_size < 4'd4) ? (step_size + 4'd1) : 4'd4;
                            step_counter <= 3'd0;
                            move_counter <= move_counter + 3'd1;
                        end
                        
                        // Update grid cell with current color
                        // Calculate address: row * 5 + col
                        grid[row * 5 + col] <= ascii_char;
                    end else begin
                        // All 4 iterations complete
                        // Final mark with '@'
                        grid[row * 5 + col] <= 8'h40; // '@'
                        state <= OUTPUT;
                    end
                end

                OUTPUT: begin
                    if (output_counter < 25) begin
                        grid_addr <= output_counter;
                        grid_data <= grid[output_counter];
                        grid_valid <= 1'b1;
                        output_counter <= output_counter + 5'd1;
                    end else begin
                        grid_valid <= 1'b0;
                        done <= 1'b1;
                        state <= IDLE;
                    end
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule