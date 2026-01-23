module bureaucrat_stamp(
    input clk,
    input rst_n,
    input start,
    input [7:0] grid_in [0:7],
    output reg [7:0] min_nubs,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE      = 3'd0;
    localparam [2:0] LOAD      = 3'd1;
    localparam [2:0] COMPUTE   = 3'd2;
    localparam [2:0] FINISH    = 3'd3;

    // Internal registers
    reg [2:0] state, next_state;
    reg [7:0] grid [0:7];
    reg [7:0] current_min;
    reg [3:0] dx, dy;
    reg [7:0] nub_count;
    reg [7:0] temp_grid [0:7];
    reg [7:0] i, j;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd1000;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            min_nubs <= 8'd0;
            done <= 1'b0;
            current_min <= 8'd255;
            dx <= 4'd0;
            dy <= 4'd0;
            nub_count <= 8'd0;
            cycle_count <= 8'd0;
            
            // Initialize grid
            for (i = 0; i < 8; i = i + 1) begin
                grid[i] <= 8'd0;
                temp_grid[i] <= 8'd0;
            end
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        next_state <= LOAD;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                LOAD: begin
                    // Load input grid
                    for (i = 0; i < 8; i = i + 1) begin
                        grid[i] <= grid_in[i];
                    end
                    current_min <= 8'd255;
                    dx <= 4'd0;
                    dy <= 4'd1;  // Start from -7 (represented as 1)
                    next_state <= COMPUTE;
                end

                COMPUTE: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Check if we've processed all shifts
                    if (dx == 4'd0 && dy == 4'd0) begin
                        next_state <= FINISH;
                    end else begin
                        // Calculate nub count for current shift
                        nub_count <= 8'd0;
                        
                        // Apply shift to create temp_grid
                        for (i = 0; i < 8; i = i + 1) begin
                            for (j = 0; j < 8; j = j + 1) begin
                                // Calculate shifted position
                                reg [3:0] new_i = i + dx - 4'd7;
                                reg [3:0] new_j = j + dy - 4'd7;
                                
                                if (new_i >= 4'd0 && new_i < 4'd8 && 
                                    new_j >= 4'd0 && new_j < 4'd8) begin
                                    temp_grid[i][j] <= grid[new_i][new_j];
                                end else begin
                                    temp_grid[i][j] <= 1'b0;
                                end
                            end
                        end
                        
                        // Count nubs in temp_grid
                        for (i = 0; i < 8; i = i + 1) begin
                            for (j = 0; j < 8; j = j + 1) begin
                                if (temp_grid[i][j]) begin
                                    nub_count <= nub_count + 8'd1;
                                end
                            end
                        end
                        
                        // Update minimum
                        if (nub_count < current_min) begin
                            current_min <= nub_count;
                        end
                        
                        // Move to next shift
                        if (dy == 4'd15) begin
                            dy <= 4'd1;
                            if (dx == 4'd15) begin
                                dx <= 4'd0;
                            end else begin
                                dx <= dx + 4'd1;
                            end
                        end else begin
                            dy <= dy + 4'd1;
                        end
                        
                        next_state <= COMPUTE;
                    end
                    
                    // Safety check for cycle count
                    if (cycle_count >= MAX_CYCLES) begin
                        next_state <= FINISH;
                    end
                end

                FINISH: begin
                    min_nubs <= current_min;
                    done <= 1'b1;
                    next_state <= IDLE;
                end

                default: next_state <= IDLE;
            endcase
        end
    end

endmodule