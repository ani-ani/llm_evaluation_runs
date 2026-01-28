module boat_crossing(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [5:0] c50_in,
    input wire [5:0] c100_in,
    input wire [12:0] k_in,
    output reg [7:0] result_dist,
    output reg [31:0] result_ways,
    output reg valid,
    output reg done
);

    // Constants
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] SEARCH = 3'd1;
    localparam [2:0] FINISH = 3'd2;
    localparam [2:0] IMPOSSIBLE = 3'd3;
    localparam [31:0] MOD = 32'd1000000007;
    localparam [5:0] MAX_PEOPLE = 6'd50;

    // State machine
    reg [2:0] state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd200000;

    // Input registers
    reg [5:0] c50_reg;
    reg [5:0] c100_reg;
    reg [12:0] k_reg;

    // Queue for BFS (circular buffer)
    localparam [9:0] QUEUE_DEPTH = 10'd1024;
    reg [9:0] queue_head, queue_tail;
    reg [5:0] queue_c50 [0:1023];
    reg [5:0] queue_c100 [0:1023];
    reg queue_shore [0:1023];
    reg [7:0] queue_dist [0:1023];
    reg [31:0] queue_ways [0:1023];
    reg queue_empty, queue_full;

    // Visited, dist, ways arrays (using distributed RAM)
    reg visited [0:50][0:50][0:1];
    reg [7:0] dist [0:50][0:50][0:1];
    reg [31:0] ways [0:50][0:50][0:1];

    // Current state being processed
    reg [5:0] curr_c50, curr_c100;
    reg curr_shore;
    reg [7:0] curr_dist;
    reg [31:0] curr_ways;

    // Combination ROM (Pascal's triangle up to 50)
    reg [31:0] comb_rom [0:50][0:50];
    integer i, j;

    // Initialize combination ROM
    initial begin
        for (i = 0; i <= 50; i = i + 1) begin
            for (j = 0; j <= i; j = j + 1) begin
                if (j == 0 || j == i) begin
                    comb_rom[i][j] = 32'd1;
                end else begin
                    comb_rom[i][j] = (comb_rom[i-1][j-1] + comb_rom[i-1][j]) % MOD;
                end
            end
        end
    end

    // Queue management
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            queue_head <= 10'd0;
            queue_tail <= 10'd0;
            queue_empty <= 1'b1;
            queue_full <= 1'b0;
        end else begin
            // Update empty/full flags
            queue_empty <= (queue_head == queue_tail);
            queue_full <= ((queue_tail + 10'd1) % QUEUE_DEPTH == queue_head);
        end
    end

    // Enqueue operation
    always @(posedge clk) begin
        if (!queue_full && state == SEARCH) begin
            // Enqueue logic would go here (handled in FSM)
        end
    end

    // Dequeue operation
    always @(posedge clk) begin
        if (!queue_empty && state == SEARCH) begin
            curr_c50 <= queue_c50[queue_head];
            curr_c100 <= queue_c100[queue_head];
            curr_shore <= queue_shore[queue_head];
            curr_dist <= queue_dist[queue_head];
            curr_ways <= queue_ways[queue_head];
            queue_head <= (queue_head + 10'd1) % QUEUE_DEPTH;
        end
    end

    // Main FSM
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result_dist <= 8'd0;
            result_ways <= 32'd0;
            valid <= 1'b0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            c50_reg <= 6'd0;
            c100_reg <= 6'd0;
            k_reg <= 13'd0;
            
            // Initialize visited, dist, ways arrays
            for (i = 0; i <= 50; i = i + 1) begin
                for (j = 0; j <= 50; j = j + 1) begin
                    for (k = 0; k <= 1; k = k + 1) begin
                        visited[i][j][k] <= 1'b0;
                        dist[i][j][k] <= 8'd0;
                        ways[i][j][k] <= 32'd0;
                    end
                end
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    valid <= 1'b0;
                    cycle_count <= 8'd0;
                    
                    if (start) begin
                        // Register inputs
                        c50_reg <= c50_in;
                        c100_reg <= c100_in;
                        k_reg <= k_in;
                        
                        // Initialize BFS
                        queue_head <= 10'd0;
                        queue_tail <= 10'd0;
                        queue_empty <= 1'b1;
                        queue_full <= 1'b0;
                        
                        // Reset visited, dist, ways
                        for (i = 0; i <= 50; i = i + 1) begin
                            for (j = 0; j <= 50; j = j + 1) begin
                                for (k = 0; k <= 1; k = k + 1) begin
                                    visited[i][j][k] <= 1'b0;
                                    dist[i][j][k] <= 8'd0;
                                    ways[i][j][k] <= 32'd0;
                                end
                            end
                        end
                        
                        // Start state: all people on starting bank
                        visited[c50_reg][c100_reg][0] <= 1'b1;
                        dist[c50_reg][c100_reg][0] <= 8'd0;
                        ways[c50_reg][c100_reg][0] <= 32'd1;
                        
                        // Enqueue start state
                        queue_c50[queue_tail] <= c50_reg;
                        queue_c100[queue_tail] <= c100_reg;
                        queue_shore[queue_tail] <= 1'b0;
                        queue_dist[queue_tail] <= 8'd0;
                        queue_ways[queue_tail] <= 32'd1;
                        queue_tail <= (queue_tail + 10'd1) % QUEUE_DEPTH;
                        queue_empty <= 1'b0;
                        
                        state <= SEARCH;
                    end
                end
                
                SEARCH: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    if (queue_empty) begin
                        // Check if we reached destination
                        if (dist[0][0][1] > 8'd0) begin
                            state <= FINISH;
                        end else begin
                            state <= IMPOSSIBLE;
                        end
                    end else begin
                        // Process current state
                        // Generate all valid moves
                        integer move50, move100;
                        reg [12:0] total_weight;
                        reg [5:0] next_c50, next_c100;
                        reg next_shore;
                        reg [7:0] next_dist;
                        reg [31:0] next_ways;
                        
                        for (move50 = 0; move50 <= curr_c50; move50 = move50 + 1) begin
                            for (move100 = 0; move100 <= curr_c100; move100 = move100 + 1) begin
                                if (move50 == 0 && move100 == 0) continue;
                                
                                total_weight = (move50 * 13'd50) + (move100 * 13'd100);
                                
                                if (total_weight <= k_reg) begin
                                    // Calculate next state
                                    if (curr_shore == 1'b0) begin
                                        next_c50 = curr_c50 - move50;
                                        next_c100 = curr_c100 - move100;
                                        next_shore = 1'b1;
                                    end else begin
                                        next_c50 = curr_c50 + move50;
                                        next_c100 = curr_c100 + move100;
                                        next_shore = 1'b0;
                                    end
                                    
                                    next_dist = curr_dist + 8'd1;
                                    
                                    // Calculate ways
                                    next_ways = (curr_ways * comb_rom[curr_c50][move50] % MOD) * 
                                               comb_rom[curr_c100][move100] % MOD;
                                    
                                    // Update if not visited or better path
                                    if (!visited[next_c50][next_c100][next_shore] || 
                                        next_dist < dist[next_c50][next_c100][next_shore]) begin
                                        
                                        visited[next_c50][next_c100][next_shore] <= 1'b1;
                                        dist[next_c50][next_c100][next_shore] <= next_dist;
                                        ways[next_c50][next_c100][next_shore] <= next_ways;
                                        
                                        // Enqueue if not full
                                        if (!queue_full) begin
                                            queue_c50[queue_tail] <= next_c50;
                                            queue_c100[queue_tail] <= next_c100;
                                            queue_shore[queue_tail] <= next_shore;
                                            queue_dist[queue_tail] <= next_dist;
                                            queue_ways[queue_tail] <= next_ways;
                                            queue_tail <= (queue_tail + 10'd1) % QUEUE_DEPTH;
                                        end
                                    end else if (next_dist == dist[next_c50][next_c100][next_shore]) begin
                                        // Update ways if same distance
                                        ways[next_c50][next_c100][next_shore] <= 
                                            (ways[next_c50][next_c100][next_shore] + next_ways) % MOD;
                                    end
                                end
                            end
                        end
                    end
                    
                    // Check for timeout
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= IMPOSSIBLE;
                    end
                end
                
                FINISH: begin
                    result_dist <= dist[0][0][1];
                    result_ways <= ways[0][0][1];
                    valid <= 1'b1;
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                IMPOSSIBLE: begin
                    result_dist <= 8'd255;  // -1 in 8-bit unsigned
                    result_ways <= 32'd0;
                    valid <= 1'b1;
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end

endmodule