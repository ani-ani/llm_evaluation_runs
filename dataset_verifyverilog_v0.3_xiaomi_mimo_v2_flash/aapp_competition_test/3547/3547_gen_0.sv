module land_area (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [1:0] n,           // Number of rectangles (1-4)
    input wire [3:0] rect_x1,     // Rectangle coordinates (0-15)
    input wire [3:0] rect_y1,
    input wire [3:0] rect_x2,
    input wire [3:0] rect_y2,
    input wire rect_valid,        // Valid signal for rectangle input
    output reg [15:0] area,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE        = 3'b000;
    localparam [2:0] WAIT_RECT   = 3'b001;
    localparam [2:0] UPDATE_GRID = 3'b010;
    localparam [2:0] COMPUTE     = 3'b011;
    localparam [2:0] DONE_STATE  = 3'b100;

    // Internal registers
    reg [2:0] state;
    reg [1:0] rect_count;          // Number of rectangles received (0-3)
    reg [3:0] rect_x1_reg, rect_y1_reg, rect_x2_reg, rect_y2_reg;  // Current rectangle
    reg [3:0] x, y;               // Counters for grid traversal
    reg [8:0] area_acc;           // Accumulator for area (0-255)
    reg [7:0] cycle_counter;      // Cycle counter for safety
    localparam [7:0] MAX_CYCLES = 8'd200;
    
    // Grid storage - 16 rows, each 16 bits wide
    reg [15:0] grid [0:15];
    
    // Combinational logic for grid access
    wire grid_write_en;
    wire [3:0] grid_x, grid_y;
    wire grid_value;
    
    assign grid_write_en = (state == UPDATE_GRID) && (x >= rect_x1_reg) && (x < rect_x2_reg) && (y >= rect_y1_reg) && (y < rect_y2_reg);
    assign grid_x = x;
    assign grid_y = y;
    assign grid_value = grid[grid_x][grid_y];

    // Main state machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            rect_count <= 2'b00;
            area <= 16'b0;
            done <= 1'b0;
            area_acc <= 9'b0;
            x <= 4'b0;
            y <= 4'b0;
            cycle_counter <= 8'd0;
            // Clear grid
            begin : reset_grid
                integer i;
                for (i = 0; i < 16; i = i + 1) begin
                    grid[i] <= 16'b0;
                end
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_counter <= 8'd0;
                    if (start) begin
                        // Clear grid and reset counters
                        begin : clear_grid
                            integer i;
                            for (i = 0; i < 16; i = i + 1) begin
                                grid[i] <= 16'b0;
                            end
                        end
                        rect_count <= 2'b00;
                        state <= WAIT_RECT;
                    end
                end
                
                WAIT_RECT: begin
                    if (rect_valid) begin
                        // Capture current rectangle
                        rect_x1_reg <= rect_x1;
                        rect_y1_reg <= rect_y1;
                        rect_x2_reg <= rect_x2;
                        rect_y2_reg <= rect_y2;
                        x <= 4'b0;
                        y <= 4'b0;
                        state <= UPDATE_GRID;
                    end
                end
                
                UPDATE_GRID: begin
                    cycle_counter <= cycle_counter + 8'd1;
                    
                    // Update grid for current cell if within rectangle
                    if (grid_write_en) begin
                        grid[grid_x][grid_y] <= 1'b1;
                    end
                    
                    // Increment counters
                    if (y == 4'd15) begin
                        y <= 4'b0;
                        if (x == 4'd15) begin
                            // Finished updating grid for this rectangle
                            if (rect_count + 1'b1 == n) begin
                                // All rectangles processed, move to compute
                                state <= COMPUTE;
                                x <= 4'b0;
                                y <= 4'b0;
                                area_acc <= 9'b0;
                            end else begin
                                rect_count <= rect_count + 1'b1;
                                state <= WAIT_RECT;
                            end
                        end else begin
                            x <= x + 1'b1;
                        end
                    end else begin
                        y <= y + 1'b1;
                    end
                end
                
                COMPUTE: begin
                    cycle_counter <= cycle_counter + 8'd1;
                    
                    // Count covered cells
                    if (grid_value) begin
                        area_acc <= area_acc + 1'b1;
                    end
                    
                    // Increment counters
                    if (y == 4'd15) begin
                        y <= 4'b0;
                        if (x == 4'd15) begin
                            // Finished counting
                            area <= {7'b0, area_acc};  // Convert to 16-bit
                            state <= DONE_STATE;
                        end else begin
                            x <= x + 1'b1;
                        end
                    end else begin
                        y <= y + 1'b1;
                    end
                    
                    // Safety timeout
                    if (cycle_counter >= MAX_CYCLES) begin
                        area <= 16'd0;
                        state <= DONE_STATE;
                    end
                end
                
                DONE_STATE: begin
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end

endmodule