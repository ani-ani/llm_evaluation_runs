module TreasureHuntingBFS(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] grid [0:255],
    input wire [7:0] K,
    output reg [7:0] result,
    output reg done
);

    // State definitions
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] INIT = 2'd1;
    localparam [1:0] PROCESS = 2'd2;
    localparam [1:0] FINISH = 2'd3;
    
    reg [1:0] state;
    
    // Grid dimensions
    localparam [3:0] GRID_SIZE = 4'd16;
    localparam [7:0] MAX_CYCLES = 8'd2048;
    
    // Queue parameters
    localparam [10:0] QUEUE_DEPTH = 11'd1024;
    
    // FIFO queue pointers
    reg [10:0] queue_head;
    reg [10:0] queue_tail;
    reg [10:0] queue_count;
    
    // Queue storage
    reg [3:0] queue_row [0:1023];
    reg [3:0] queue_col [0:1023];
    reg [7:0] queue_stamina [0:1023];
    reg [7:0] queue_days [0:1023];
    
    // Visited array (stores max stamina at each cell)
    reg [7:0] visited [0:15][0:15];
    
    // Current processing element
    reg [3:0] current_row;
    reg [3:0] current_col;
    reg [7:0] current_stamina;
    reg [7:0] current_days;
    
    // Start position (S = 4)
    reg [3:0] start_row;
    reg [3:0] start_col;
    
    // Cycle counter
    reg [11:0] cycle_count;
    
    // Helper variables
    reg [3:0] neighbor_row;
    reg [3:0] neighbor_col;
    reg [7:0] neighbor_stamina;
    reg [7:0] neighbor_days;
    reg [7:0] terrain_cost;
    reg [7:0] grid_value;
    
    integer i;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 8'd255;
            done <= 1'b0;
            
            // Reset queue
            queue_head <= 11'd0;
            queue_tail <= 11'd0;
            queue_count <= 11'd0;
            
            // Reset visited array
            for (i = 0; i < 16; i = i + 1) begin
                integer j;
                for (j = 0; j < 16; j = j + 1) begin
                    visited[i][j] <= 8'd0;
                end
            end
            
            cycle_count <= 12'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= INIT;
                    end
                end
                
                INIT: begin
                    // Find start position (S = 4)
                    integer idx;
                    for (idx = 0; idx < 256; idx = idx + 1) begin
                        if (grid[idx] == 4'd4) begin
                            start_row <= idx[7:4];
                            start_col <= idx[3:0];
                        end
                    end
                    
                    // Initialize queue with start position
                    queue_row[0] <= start_row;
                    queue_col[0] <= start_col;
                    queue_stamina[0] <= K;
                    queue_days[0] <= 8'd0;
                    
                    queue_head <= 11'd0;
                    queue_tail <= 11'd1;
                    queue_count <= 11'd1;
                    
                    // Mark start as visited
                    visited[start_row][start_col] <= K;
                    
                    cycle_count <= 12'd0;
                    state <= PROCESS;
                end
                
                PROCESS: begin
                    // Check if queue is empty
                    if (queue_count == 11'd0) begin
                        result <= 8'd255;
                        state <= FINISH;
                    end else begin
                        // Pop from queue
                        current_row <= queue_row[queue_head];
                        current_col <= queue_col[queue_head];
                        current_stamina <= queue_stamina[queue_head];
                        current_days <= queue_days[queue_head];
                        
                        queue_head <= queue_head + 11'd1;
                        queue_count <= queue_count - 11'd1;
                        
                        // Check if current position is goal (G = 5)
                        grid_value <= grid[{current_row, current_col}];
                        if (grid_value == 4'd5) begin
                            result <= current_days;
                            state <= FINISH;
                        end else begin
                            // Expand neighbors
                            integer dir;
                            for (dir = 0; dir < 4; dir = dir + 1) begin
                                case (dir)
                                    0: begin // Up
                                        neighbor_row <= current_row - 4'd1;
                                        neighbor_col <= current_col;
                                    end
                                    1: begin // Down
                                        neighbor_row <= current_row + 4'd1;
                                        neighbor_col <= current_col;
                                    end
                                    2: begin // Left
                                        neighbor_row <= current_row;
                                        neighbor_col <= current_col - 4'd1;
                                    end
                                    3: begin // Right
                                        neighbor_row <= current_row;
                                        neighbor_col <= current_col + 4'd1;
                                    end
                                endcase
                                
                                // Check bounds
                                if (neighbor_row >= 4'd0 && neighbor_row < GRID_SIZE && 
                                    neighbor_col >= 4'd0 && neighbor_col < GRID_SIZE) begin
                                    
                                    grid_value <= grid[{neighbor_row, neighbor_col}];
                                    
                                    // Check if river (blocked)
                                    if (grid_value != 4'd3) begin
                                        // Calculate terrain cost
                                        case (grid_value)
                                            4'd0, 4'd4, 4'd5: terrain_cost <= 8'd1; // Plain, S, G
                                            4'd1: terrain_cost <= 8'd2; // Forest
                                            4'd2: terrain_cost <= 8'd3; // Mountain
                                            default: terrain_cost <= 8'd0;
                                        endcase
                                        
                                        // Calculate new stamina and days
                                        if (current_stamina >= terrain_cost) begin
                                            neighbor_stamina <= current_stamina - terrain_cost;
                                            neighbor_days <= current_days;
                                        end else begin
                                            neighbor_stamina <= K - terrain_cost;
                                            neighbor_days <= current_days + 8'd1;
                                        end
                                        
                                        // Check if better than visited
                                        if (neighbor_stamina > visited[neighbor_row][neighbor_col]) begin
                                            visited[neighbor_row][neighbor_col] <= neighbor_stamina;
                                            
                                            // Push to queue
                                            queue_row[queue_tail] <= neighbor_row;
                                            queue_col[queue_tail] <= neighbor_col;
                                            queue_stamina[queue_tail] <= neighbor_stamina;
                                            queue_days[queue_tail] <= neighbor_days;
                                            
                                            queue_tail <= queue_tail + 11'd1;
                                            queue_count <= queue_count + 11'd1;
                                        end
                                    end
                                end
                            end
                            
                            // Increment cycle counter
                            cycle_count <= cycle_count + 12'd1;
                            
                            // Safety check for max cycles
                            if (cycle_count >= MAX_CYCLES) begin
                                result <= 8'd255;
                                state <= FINISH;
                            end
                        end
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