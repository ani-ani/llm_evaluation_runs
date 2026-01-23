module robot_fixer #(
    parameter H = 4,
    parameter W = 4,
    parameter MAX_CMDS = 8,
    parameter CMD_BITS = 2,
    parameter CHANGES_BITS = 4
)(
    input clk,
    input rst_n,
    input start,
    
    // Grid: H*W bits, row-major, 1=obstacle
    input [H*W-1:0] grid,
    
    // Start and goal positions (2 bits each for 4x4 grid)
    input [1:0] start_x,
    input [1:0] start_y,
    input [1:0] goal_x,
    input [1:0] goal_y,
    
    // Command string: MAX_CMDS * CMD_BITS (L=00, R=01, U=10, D=11)
    input [MAX_CMDS*CMD_BITS-1:0] commands,
    input [3:0] cmd_len,  // 1-MAX_CMDS
    
    output reg [CHANGES_BITS-1:0] min_changes,
    output reg done,
    output reg valid
);

// State machine definitions
reg [2:0] state;
localparam S_IDLE = 3'b000,
           S_RESET_COST = 3'b001,
           S_INIT = 3'b010,
           S_PROCESS = 3'b011,
           S_EXPLORE = 3'b100,
           S_DONE = 3'b110;

// Cost table: stores min edits for each state (x,y,cmd_idx)
reg [CHANGES_BITS-1:0] cost_table [0:255];
reg [7:0] reset_idx;  // For initialization

// BFS queue: stores {x,y,cmd_idx} packed as 8 bits
reg [7:0] queue [0:31];
reg [5:0] q_head, q_tail;
reg queue_empty;

// Current state being processed
reg [7:0] current_state;
reg [CHANGES_BITS-1:0] current_cost;

// Operation type during exploration
reg [1:0] op_type;  // 0=execute, 1=delete, 2=insert

// Next state and cost calculations
reg [7:0] next_state;
reg [CHANGES_BITS-1:0] next_cost;

// Helper: extract fields from current state
wire [1:0] curr_x = current_state[7:6];
wire [1:0] curr_y = current_state[5:4];
wire [3:0] curr_cmd_idx = current_state[3:0];

// Helper: check if position is valid
wire is_valid_pos = (curr_x < W) && (curr_y < H) && 
                    !grid[curr_y * W + curr_x];

// Helper: check if goal reached
wire is_goal = (curr_x == goal_x) && (curr_y == goal_y);

// Helper: check if more commands available
wire has_more_cmds = (curr_cmd_idx < cmd_len);

// Helper: get current command
wire [1:0] current_cmd = commands[curr_cmd_idx * CMD_BITS +: CMD_BITS];

// Combinational: calculate next position for execute operation
always @(*) begin
    reg [1:0] new_x, new_y;
    new_x = curr_x;
    new_y = curr_y;
    
    if (has_more_cmds) begin
        case (current_cmd)
            2'b00: if (curr_x > 0) new_x = curr_x - 1;      // L
            2'b01: if (curr_x < W-1) new_x = curr_x + 1;    // R
            2'b10: if (curr_y > 0) new_y = curr_y - 1;      // U
            2'b11: if (curr_y < H-1) new_y = curr_y + 1;    // D
        endcase
        
        // Check obstacle collision
        if (grid[new_y * W + new_x]) begin
            new_x = curr_x;
            new_y = curr_y;
        end
    end
    
    next_state = {new_x, new_y, curr_cmd_idx + 1};
    next_cost = current_cost;  // Execute doesn't add cost
end

// State machine and sequential logic
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= S_IDLE;
        done <= 0;
        valid <= 0;
        min_changes <= 0;
        reset_idx <= 0;
        q_head <= 0;
        q_tail <= 0;
        queue_empty <= 1;
    end else begin
        case (state)
            S_IDLE: begin
                if (start) begin
                    state <= S_RESET_COST;
                    reset_idx <= 0;
                end
            end
            
            S_RESET_COST: begin
                // Initialize cost table to max value (15)
                if (reset_idx < 255) begin
                    cost_table[reset_idx] <= CHANGES_BITS'hF;
                    reset_idx <= reset_idx + 1;
                end else begin
                    cost_table[255] <= CHANGES_BITS'hF;
                    state <= S_INIT;
                end
            end
            
            S_INIT: begin
                // Push start state (cost 0)
                queue[0] <= {start_x, start_y, 4'h0};
                q_tail <= 1;
                q_head <= 0;
                queue_empty <= 0;
                cost_table[{start_x, start_y, 4'h0}] <= 0;
                state <= S_PROCESS;
            end
            
            S_PROCESS: begin
                if (!queue_empty && q_head != q_tail) begin
                    // Pop current state from queue
                    current_state <= queue[q_head];
                    current_cost <= cost_table[queue[q_head]];
                    q_head <= q_head + 1;
                    
                    // Check if queue becomes empty
                    if (q_head + 1 == q_tail) begin
                        queue_empty <= 1;
                    end
                    
                    op_type <= 0;  // Start with execute
                    state <= S_EXPLORE;
                end else begin
                    // Queue empty - done
                    state <= S_DONE;
                end
            end
            
            S_EXPLORE: begin
                case (op_type)
                    2'b00: begin  // Execute command
                        if (has_more_cmds) begin
                            // next_state already computed by combinational logic
                            if (next_cost < cost_table[next_state]) begin
                                cost_table[next_state] <= next_cost;
                                
                                // Check if goal reached
                                if (next_state[7:4] == {goal_x, goal_y}) begin
                                    min_changes <= next_cost;
                                    valid <= 1;
                                    state <= S_DONE;
                                end else if (q_tail < 31) begin
                                    // Enqueue new state
                                    queue[q_tail] <= next_state;
                                    q_tail <= q_tail + 1;
                                    queue_empty <= 0;
                                end
                            end
                        end
                        op_type <= 2'b01;  // Next: delete
                    end
                    
                    2'b01: begin  // Delete current command
                        if (has_more_cmds) begin
                            next_state <= {curr_x, curr_y, curr_cmd_idx + 1};
                            next_cost <= current_cost + 1;
                            
                            if (next_cost < cost_table[next_state]) begin
                                cost_table[next_state] <= next_cost;
                                
                                if (next_state[7:4] == {goal_x, goal_y}) begin
                                    min_changes <= next_cost;
                                    valid <= 1;
                                    state <= S_DONE;
                                end else if (q_tail < 31) begin
                                    queue[q_tail] <= next_state;
                                    q_tail <= q_tail + 1;
                                    queue_empty <= 0;
                                end
                            end
                        end
                        op_type <= 2'b10;  // Next: insert
                    end
                    
                    2'b10: begin  // Insert command (simplified)
                        // Insert at current position: stay at same cmd_idx, add cost
                        // This represents inserting a command that moves the robot
                        // For hardware simplicity, we treat insert as:
                        // - Try all 4 directions from current position
                        // - Increase cost by 1
                        // - Keep same cmd_idx
                        
                        // Simplified: just increment cost for insert operation
                        next_state <= {curr_x, curr_y, curr_cmd_idx};
                        next_cost <= current_cost + 1;
                        
                        if (next_cost < cost_table[next_state]) begin
                            cost_table[next_state] <= next_cost;
                            
                            if (next_state[7:4] == {goal_x, goal_y}) begin
                                min_changes <= next_cost;
                                valid <= 1;
                                state <= S_DONE;
                            end else if (q_tail < 31) begin
                                queue[q_tail] <= next_state;
                                q_tail <= q_tail + 1;
                                queue_empty <= 0;
                            end
                        end
                        
                        state <= S_PROCESS;  // Back to queue processing
                    end
                    
                    default: op_type <= 2'b00;
                endcase
            end
            
            S_DONE: begin
                done <= 1;
                if (!valid) begin
                    // No path found within cost limit
                    min_changes <= CHANGES_BITS'hF;
                end
            end
        endcase
    end
end

endmodule