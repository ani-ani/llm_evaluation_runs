module bureaucrat_stamp (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] grid_in [0:7],
    output reg [7:0] min_nubs,
    output reg done
);

    // State declarations
    localparam [3:0] IDLE       = 4'd0;
    localparam [3:0] LOAD_GRID  = 4'd1;
    localparam [3:0] RESET_VARS = 4'd2;
    localparam [3:0] SHIFT_LOOP = 4'd3;
    localparam [3:0] CHECK_SHIFT = 4'd4;
    localparam [3:0] COUNT_OVERLAP = 4'd5;
    localparam [3:0] UPDATE_MIN = 4'd6;
    localparam [3:0] NEXT_SHIFT = 4'd7;
    localparam [3:0] FINISH     = 4'd8;

    reg [3:0] state, next_state;
    
    // Grid storage (8x8 bits)
    reg [7:0] grid [0:7];
    
    // Shift coordinates
    reg signed [3:0] dx, dy;
    reg signed [3:0] next_dx, next_dy;
    
    // Counters
    reg [2:0] row, col;
    reg [3:0] overlap_count;
    reg [7:0] current_min;
    
    // Loop control
    reg shift_valid;
    reg [2:0] row_idx;
    reg [2:0] col_idx;
    reg signed [3:0] check_x, check_y;
    
    // Cycle counter for safety
    reg [15:0] cycle_count;
    localparam [15:0] MAX_CYCLES = 16'd10000;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            min_nubs <= 8'd0;
            done <= 1'b0;
            dx <= 4'sd0;
            dy <= 4'sd0;
            row <= 3'd0;
            col <= 3'd0;
            overlap_count <= 4'd0;
            current_min <= 8'd255;
            cycle_count <= 16'd0;
            shift_valid <= 1'b0;
            row_idx <= 3'd0;
            col_idx <= 3'd0;
            check_x <= 4'sd0;
            check_y <= 4'sd0;
            // Initialize grid
            grid[0] <= 8'd0;
            grid[1] <= 8'd0;
            grid[2] <= 8'd0;
            grid[3] <= 8'd0;
            grid[4] <= 8'd0;
            grid[5] <= 8'd0;
            grid[6] <= 8'd0;
            grid[7] <= 8'd0;
        end else begin
            state <= next_state;
            dx <= next_dx;
            dy <= next_dy;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 16'd0;
                    current_min <= 8'd255;
                end
                
                LOAD_GRID: begin
                    // Load grid from input array
                    grid[0] <= grid_in[0];
                    grid[1] <= grid_in[1];
                    grid[2] <= grid_in[2];
                    grid[3] <= grid_in[3];
                    grid[4] <= grid_in[4];
                    grid[5] <= grid_in[5];
                    grid[6] <= grid_in[6];
                    grid[7] <= grid_in[7];
                end
                
                RESET_VARS: begin
                    dx <= -4'sd7;
                    dy <= -4'sd7;
                    current_min <= 8'd255;
                end
                
                SHIFT_LOOP: begin
                    cycle_count <= cycle_count + 16'd1;
                end
                
                CHECK_SHIFT: begin
                    // Check if shift is valid (not 0,0 and within bounds)
                    if (dx == 0 && dy == 0) begin
                        shift_valid <= 1'b0;
                    end else if (dx >= -4'sd7 && dx <= 4'sd7 && dy >= -4'sd7 && dy <= 4'sd7) begin
                        shift_valid <= 1'b1;
                    end else begin
                        shift_valid <= 1'b0;
                    end
                    overlap_count <= 4'd0;
                    row_idx <= 3'd0;
                    col_idx <= 3'd0;
                end
                
                COUNT_OVERLAP: begin
                    if (row_idx < 8) begin
                        if (col_idx < 8) begin
                            // Check if shifted cell is within bounds
                            check_x <= {1'b0, col_idx} + dx;
                            check_y <= {1'b0, row_idx} + dy;
                            
                            if ({1'b0, col_idx} + dx >= 0 && {1'b0, col_idx} + dx < 8 &&
                                {1'b0, row_idx} + dy >= 0 && {1'b0, row_idx} + dy < 8) begin
                                // Both cells are within bounds
                                if (grid[row_idx][col_idx] == 1'b1 && 
                                    grid[{1'b0, row_idx} + dy][{1'b0, col_idx} + dx] == 1'b1) begin
                                    overlap_count <= overlap_count + 4'd1;
                                end
                            end
                            col_idx <= col_idx + 3'd1;
                        end else begin
                            col_idx <= 3'd0;
                            row_idx <= row_idx + 3'd1;
                        end
                    end
                end
                
                UPDATE_MIN: begin
                    if (shift_valid && overlap_count < current_min) begin
                        current_min <= overlap_count;
                    end
                end
                
                NEXT_SHIFT: begin
                    // Move to next shift
                    if (dx < 4'sd7) begin
                        next_dx <= dx + 4'sd1;
                        next_dy <= dy;
                    end else begin
                        next_dx <= -4'sd7;
                        if (dy < 4'sd7) begin
                            next_dy <= dy + 4'sd1;
                        end else begin
                            next_dy <= -4'sd7;
                        end
                    end
                end
                
                FINISH: begin
                    min_nubs <= current_min;
                    done <= 1'b1;
                end
            endcase
        end
    end

    always @(*) begin
        next_state = state;
        
        case (state)
            IDLE: begin
                if (start) next_state = LOAD_GRID;
            end
            
            LOAD_GRID: begin
                next_state = RESET_VARS;
            end
            
            RESET_VARS: begin
                next_state = SHIFT_LOOP;
            end
            
            SHIFT_LOOP: begin
                // Check if we've processed all shifts
                if (dx == 4'sd7 && dy == 4'sd7) begin
                    next_state = FINISH;
                end else begin
                    next_state = CHECK_SHIFT;
                end
            end
            
            CHECK_SHIFT: begin
                if (shift_valid) begin
                    next_state = COUNT_OVERLAP;
                end else begin
                    next_state = NEXT_SHIFT;
                end
            end
            
            COUNT_OVERLAP: begin
                if (row_idx >= 8) begin
                    next_state = UPDATE_MIN;
                end else begin
                    next_state = COUNT_OVERLAP;
                end
            end
            
            UPDATE_MIN: begin
                next_state = NEXT_SHIFT;
            end
            
            NEXT_SHIFT: begin
                next_state = SHIFT_LOOP;
            end
            
            FINISH: begin
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
        
        // Safety: prevent infinite loops
        if (cycle_count >= MAX_CYCLES) begin
            next_state = FINISH;
        end
    end

endmodule