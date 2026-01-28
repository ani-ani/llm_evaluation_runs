module turtle_drawing(
    input clk,
    input rst_n,
    input start,
    input [1:0] cmd_dir [0:4],
    input [7:0] cmd_dist [0:4],
    input [47:0] target_grid,
    output reg [7:0] min_time,
    output reg [7:0] max_time,
    output reg valid,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] PROCESS_CMD = 3'd1;
    localparam [2:0] COMPUTE = 3'd2;
    localparam [2:0] FINISH = 3'd3;
    
    reg [2:0] state, next_state;
    
    // Command processing
    reg [2:0] cmd_index;
    reg [7:0] cmd_counter;
    reg [7:0] total_steps;
    reg [7:0] current_step;
    reg [2:0] current_dir;
    reg [7:0] current_dist;
    
    // Position tracking
    reg [2:0] x_pos;  // 0-7 (3 bits)
    reg [2:0] y_pos;  // 0-5 (3 bits)
    
    // Grid tracking
    reg [47:0] marked_grid;
    reg [47:0] temp_grid;
    
    // Timing and validation
    reg [7:0] time_counter;
    reg [7:0] min_valid_time;
    reg [7:0] max_valid_time;
    reg found_valid;
    reg first_valid;
    
    // Cycle counter for timeout
    reg [8:0] cycle_count;
    localparam [8:0] MAX_CYCLES = 9'd500;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all registers
            state <= IDLE;
            cmd_index <= 3'd0;
            cmd_counter <= 8'd0;
            total_steps <= 8'd0;
            current_step <= 8'd0;
            current_dir <= 2'd0;
            current_dist <= 8'd0;
            x_pos <= 3'd0;
            y_pos <= 3'd5;
            
            // Initialize grid
            integer i;
            for (i = 0; i < 48; i = i + 1) begin
                marked_grid[i] <= 1'b0;
            end
            
            min_time <= 8'd0;
            max_time <= 8'd0;
            valid <= 1'b0;
            done <= 1'b0;
            time_counter <= 8'd0;
            min_valid_time <= 8'd0;
            max_valid_time <= 8'd0;
            found_valid <= 1'b0;
            first_valid <= 1'b0;
            cycle_count <= 9'd0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    valid <= 1'b0;
                    cycle_count <= 9'd0;
                    
                    if (start) begin
                        // Reset path tracking
                        x_pos <= 3'd0;
                        y_pos <= 3'd5;
                        cmd_index <= 3'd0;
                        cmd_counter <= 8'd0;
                        total_steps <= 8'd0;
                        current_step <= 8'd0;
                        
                        // Clear grid
                        integer i;
                        for (i = 0; i < 48; i = i + 1) begin
                            marked_grid[i] <= 1'b0;
                        end
                        
                        // Mark starting position
                        marked_grid[5*8 + 0] <= 1'b1;
                        
                        next_state <= PROCESS_CMD;
                    end else begin
                        next_state <= IDLE;
                    end
                end
                
                PROCESS_CMD: begin
                    cycle_count <= cycle_count + 9'd1;
                    
                    if (cmd_counter == 8'd0) begin
                        // Load next command
                        if (cmd_index < 5) begin
                            current_dir <= cmd_dir[cmd_index];
                            current_dist <= cmd_dist[cmd_index];
                            cmd_index <= cmd_index + 3'd1;
                        end
                    end
                    
                    // Process current command
                    if (cmd_counter < current_dist && cmd_index <= 5) begin
                        // Update position based on direction
                        case (current_dir)
                            2'd0: y_pos <= y_pos + 3'd1;  // Up
                            2'd1: y_pos <= y_pos - 3'd1;  // Down
                            2'd2: x_pos <= x_pos - 3'd1;  // Left
                            2'd3: x_pos <= x_pos + 3'd1;  // Right
                        endcase
                        
                        // Mark current position
                        marked_grid[y_pos*8 + x_pos] <= 1'b1;
                        
                        cmd_counter <= cmd_counter + 8'd1;
                        total_steps <= total_steps + 8'd1;
                    end else begin
                        cmd_counter <= 8'd0;
                        
                        if (cmd_index >= 5) begin
                            // All commands processed
                            next_state <= COMPUTE;
                            time_counter <= 8'd0;
                            found_valid <= 1'b0;
                            first_valid <= 1'b0;
                        end
                    end
                end
                
                COMPUTE: begin
                    cycle_count <= cycle_count + 9'd1;
                    
                    // Check if we've processed all possible times
                    if (time_counter > total_steps || time_counter == 8'd255) begin
                        if (found_valid) begin
                            min_time <= min_valid_time;
                            max_time <= max_valid_time;
                            valid <= 1'b1;
                        end else begin
                            valid <= 1'b0;
                        end
                        next_state <= FINISH;
                    end else begin
                        // Create temporary grid for current time
                        integer i;
                        for (i = 0; i < 48; i = i + 1) begin
                            temp_grid[i] <= marked_grid[i] && (i == (5*8 + 0) || 
                                (i[5:3] * 8 + i[2:0]) == (y_pos*8 + x_pos) || 
                                (i[5:3] * 8 + i[2:0]) == (y_pos*8 + x_pos));
                        end
                        
                        // Compare with target
                        reg match;
                        match = 1'b1;
                        for (i = 0; i < 48; i = i + 1) begin
                            if (temp_grid[i] != target_grid[i]) begin
                                match = 1'b0;
                            end
                        end
                        
                        if (match) begin
                            found_valid <= 1'b1;
                            if (!first_valid) begin
                                min_valid_time <= time_counter;
                                first_valid <= 1'b1;
                            end
                            max_valid_time <= time_counter;
                        end
                        
                        time_counter <= time_counter + 8'd1;
                    end
                end
                
                FINISH: begin
                    done <= 1'b1;
                    next_state <= IDLE;
                end
                
                default: begin
                    next_state <= IDLE;
                    done <= 1'b0;
                    valid <= 1'b0;
                end
            endcase
            
            // Timeout check
            if (cycle_count >= MAX_CYCLES) begin
                next_state <= IDLE;
                done <= 1'b1;
            end
        end
    end

    // Position clamping (combinational)
    always @(*) begin
        if (x_pos > 7) x_pos = 3'd7;
        if (x_pos < 0) x_pos = 3'd0;
        if (y_pos > 5) y_pos = 3'd5;
        if (y_pos < 0) y_pos = 3'd0;
    end

endmodule