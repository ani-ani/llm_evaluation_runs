module ObstaclePlacementCounter(
    input wire clk,
    input wire rst_n,
    input wire start,
    output reg [15:0] result,
    output reg done
);
    
    // Parameters
    localparam N = 4;  // Grid rows (fixed for Verilog)
    localparam M = 4;  // Grid columns (fixed for Verilog)
    localparam MODULUS = 32'd999999937;
    localparam MAX_STATES = 16;  // 2^N
    localparam MAX_OBSTACLES = 16;  // ceil(N*M/4) = 4
    
    // State machine
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] INIT = 2'd1;
    localparam [1:0] COMPUTE = 2'd2;
    localparam [1:0] FINISH = 2'd3;
    
    reg [1:0] state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd1000;
    
    // DP tables
    reg [31:0] dp_current [0:MAX_STATES-1];  // dp[state] = count
    reg [31:0] dp_next [0:MAX_STATES-1];
    reg [7:0] min_obstacles_current [0:MAX_STATES-1];
    reg [7:0] min_obstacles_next [0:MAX_STATES-1];
    
    // Counters
    reg [7:0] col_idx;
    reg [7:0] state_idx;
    reg [7:0] prev_state_idx;
    
    // Intermediate signals
    reg [31:0] transition_count;
    reg [7:0] obstacle_count;
    reg [7:0] min_obstacles;
    reg [31:0] total_count;
    
    // Initialize DP for column 0
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            col_idx <= 8'd0;
            state_idx <= 8'd0;
            prev_state_idx <= 8'd0;
            transition_count <= 32'd0;
            obstacle_count <= 8'd0;
            min_obstacles <= 8'd0;
            total_count <= 32'd0;
            
            // Initialize DP arrays
            integer i;
            for (i = 0; i < MAX_STATES; i = i + 1) begin
                dp_current[i] <= 32'd0;
                dp_next[i] <= 32'd0;
                min_obstacles_current[i] <= 8'd0;
                min_obstacles_next[i] <= 8'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= INIT;
                    end
                end
                
                INIT: begin
                    // Initialize column 0
                    integer i;
                    for (i = 0; i < MAX_STATES; i = i + 1) begin
                        obstacle_count = $clog2(i) + 1'd1;  // Popcount approximation
                        if (obstacle_count <= MAX_OBSTACLES) begin
                            dp_current[i] <= 32'd1;
                            min_obstacles_current[i] <= obstacle_count;
                        end else begin
                            dp_current[i] <= 32'd0;
                            min_obstacles_current[i] <= 8'd0;
                        end
                    end
                    col_idx <= 8'd1;
                    state <= COMPUTE;
                end
                
                COMPUTE: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Reset next DP
                    integer i;
                    for (i = 0; i < MAX_STATES; i = i + 1) begin
                        dp_next[i] <= 32'd0;
                        min_obstacles_next[i] <= 8'd0;
                    end
                    
                    // Iterate over all previous states
                    if (prev_state_idx == 8'd0) begin
                        state_idx <= 8'd0;
                    end
                    
                    // Check if current state is valid
                    if (state_idx < MAX_STATES) begin
                        // Check 2x2 constraints with previous state
                        reg valid;
                        reg [3:0] current_state_bits;
                        reg [3:0] prev_state_bits;
                        integer j;
                        
                        current_state_bits = state_idx[3:0];
                        prev_state_bits = prev_state_idx[3:0];
                        valid = 1'b1;
                        
                        // Check all adjacent row pairs
                        for (j = 0; j < N-1; j = j + 1) begin
                            reg has_obstacle;
                            has_obstacle = (current_state_bits[j] || current_state_bits[j+1] || 
                                          prev_state_bits[j] || prev_state_bits[j+1]);
                            if (!has_obstacle) begin
                                valid = 1'b0;
                            end
                        end
                        
                        if (valid && dp_current[prev_state_idx] > 0) begin
                            obstacle_count = $clog2(state_idx) + 1'd1;
                            transition_count = (dp_current[prev_state_idx] + 
                                              min_obstacles_current[prev_state_idx]) % MODULUS;
                            
                            if (transition_count > dp_next[state_idx]) begin
                                dp_next[state_idx] <= transition_count;
                                min_obstacles_next[state_idx] <= min_obstacles_current[prev_state_idx] + obstacle_count;
                            end else if (transition_count == dp_next[state_idx]) begin
                                if (min_obstacles_current[prev_state_idx] + obstacle_count < 
                                    min_obstacles_next[state_idx]) begin
                                    min_obstacles_next[state_idx] <= min_obstacles_current[prev_state_idx] + obstacle_count;
                                end
                            end
                        end
                        
                        state_idx <= state_idx + 8'd1;
                    end else begin
                        // Move to next previous state
                        prev_state_idx <= prev_state_idx + 8'd1;
                        if (prev_state_idx >= MAX_STATES) begin
                            // Copy next to current
                            for (i = 0; i < MAX_STATES; i = i + 1) begin
                                dp_current[i] <= dp_next[i];
                                min_obstacles_current[i] <= min_obstacles_next[i];
                            end
                            
                            col_idx <= col_idx + 8'd1;
                            prev_state_idx <= 8'd0;
                            
                            if (col_idx >= M) begin
                                state <= FINISH;
                            end
                        end
                        state_idx <= 8'd0;
                    end
                end
                
                FINISH: begin
                    // Find minimum obstacles
                    integer i;
                    min_obstacles = 8'd255;
                    total_count = 32'd0;
                    
                    for (i = 0; i < MAX_STATES; i = i + 1) begin
                        if (min_obstacles_current[i] < min_obstacles && 
                            min_obstacles_current[i] > 0) begin
                            min_obstacles = min_obstacles_current[i];
                            total_count = dp_current[i];
                        end else if (min_obstacles_current[i] == min_obstacles) begin
                            total_count = (total_count + dp_current[i]) % MODULUS;
                        end
                    end
                    
                    result <= total_count[15:0];
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
    
    // Popcount function (approximation for N=4)
    function [7:0] popcount;
        input [3:0] val;
        begin
            popcount = val[0] + val[1] + val[2] + val[3];
        end
    endfunction
    
endmodule