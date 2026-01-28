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
    
    // Start and goal positions
    input [1:0] start_x,
    input [1:0] start_y,
    input [1:0] goal_x,
    input [1:0] goal_y,
    
    // Command string
    input [MAX_CMDS*CMD_BITS-1:0] commands,
    input [3:0] cmd_len,
    
    output reg [CHANGES_BITS-1:0] min_changes,
    output reg done,
    output reg valid
);

// State declarations
localparam [2:0] S_IDLE     = 3'd0;
localparam [2:0] S_RESET    = 3'd1;
localparam [2:0] S_INIT     = 3'd2;
localparam [2:0] S_PROCESS  = 3'd3;
localparam [2:0] S_EXPLORE  = 3'd4;
localparam [2:0] S_DONE     = 3'd5;
reg [2:0] state;

// Cost table declaration
reg [CHANGES_BITS-1:0] cost_table [0:255];  // 4x4x8=256 states

// BFS queue implementation
reg [7:0] queue [0:31];  // Stores {x,y,cmd_idx}
reg [5:0] q_head, q_tail;
reg queue_empty;

// State processing registers
reg [7:0] current_state;
reg [CHANGES_BITS-1:0] current_cost;
reg [1:0] op_type;

// Helper signals
wire [1:0] curr_x        = current_state[7:6];
wire [1:0] curr_y        = current_state[5:4];
wire [3:0] curr_cmd_idx  = current_state[3:0];
wire has_more_cmds       = (curr_cmd_idx < cmd_len);
wire [1:0] current_cmd   = commands[curr_cmd_idx*CMD_BITS +: CMD_BITS];
wire is_valid            = (curr_x < W) && (curr_y < H) && !grid[curr_y*W + curr_x];
wire is_goal             = (curr_x == goal_x) && (curr_y == goal_y);

// Next state variables
reg [7:0] next_state;
reg [CHANGES_BITS-1:0] next_cost;

// Reset & initialization counter
reg [7:0] init_counter;

// Cost table initialization
integer i;

// Main FSM
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        done <= 1'b0;
        valid <= 1'b0;
        q_head <= 6'd0;
        q_tail <= 6'd0;
        queue_empty <= 1'b1;
        min_changes <= 4'b1111;
        state <= S_IDLE;
        
        // Initialize cost table
        for (i = 0; i < 256; i = i + 1) begin
            cost_table[i] <= 4'hF;
        end
    end else begin
        case (state)
            S_IDLE: begin
                done <= 1'b0;
                valid <= 1'b0;
                min_changes <= 4'hF;
                if (start) begin
                    state <= S_RESET;
                end
            end
            
            S_RESET: begin
                // Reset cost table
                for (i = 0; i < 256; i = i + 1) begin
                    cost_table[i] <= 4'hF;
                end
                state <= S_INIT;
            end
            
            S_INIT: begin
                // Initialize queue with start state
                q_head <= 6'd0;
                q_tail <= 6'd1;
                queue[0] <= {start_x, start_y, 4'd0};
                cost_table[{start_x, start_y, 4'd0}] <= 4'd0;
                queue_empty <= 1'b0;
                state <= S_PROCESS;
            end
            
            S_PROCESS: begin
                if (queue_empty) begin
                    state <= S_DONE;
                end else begin
                    // Dequeue current state
                    current_state <= queue[q_head];
                    current_cost <= cost_table[queue[q_head]];
                    q_head <= q_head + 1;
                    op_type <= 2'd0;  // Start with execute operation
                    state <= S_EXPLORE;
                    
                    // Update queue empty status
                    if (q_head + 1 == q_tail) begin
                        queue_empty <= 1'b1;
                    end
                end
            end
            
            S_EXPLORE: begin
                if (is_goal) begin
                    min_changes <= current_cost;
                    valid <= 1'b1;
                    state <= S_DONE;
                end
                else if (!is_valid) begin
                    state <= S_PROCESS;  // Invalid state - skip
                end
                else if (op_type == 2'd0) begin  // Execute
                    if (has_more_cmds) begin
                        case (current_cmd)
                            2'b00: next_state = { (curr_x > 0)    ? curr_x-1   : curr_x, curr_y, curr_cmd_idx+1 };
                            2'b01: next_state = { (curr_x < W-1) ? curr_x+1   : curr_x, curr_y, curr_cmd_idx+1 };
                            2'b10: next_state = { curr_x, (curr_y > 0)    ? curr_y-1   : curr_y, curr_cmd_idx+1 };
                            2'b11: next_state = { curr_x, (curr_y < H-1) ? curr_y+1   : curr_y, curr_cmd_idx+1 };
                        endcase
                        
                        // Check for obstacle collision
                        if (grid[next_state[5:4]*W + next_state[7:6]]) begin
                            next_state <= current_state;  // Collision, don't move
                        end
                    
                        if (cost_table[next_state] > current_cost) begin
                            cost_table[next_state] <= current_cost;
                            if (q_tail < 31) begin
                                queue[q_tail] <= next_state;
                                q_tail <= q_tail + 1;
                                queue_empty <= 1'b0;
                            end
                        end
                    end
                    op_type <= 2'd1;
                end
                
                else if (op_type == 2'd1) begin  // Delete
                    next_state = {curr_x, curr_y, curr_cmd_idx + 1};
                    next_cost = current_cost + 1;
                    
                    if (has_more_cmds && (cost_table[next_state] > next_cost)) begin
                        cost_table[next_state] <= next_cost;
                        if (q_tail < 31) begin
                            queue[q_tail] <= next_state;
                            q_tail <= q_tail + 1;
                            queue_empty <= 1'b0;
                        end
                    end
                    op_type <= 2'd2;
                end
                
                else begin  // Insert (simplified)
                    next_state = {curr_x, curr_y, curr_cmd_idx};
                    next_cost = current_cost + 1;
                    
                    if (cost_table[next_state] > next_cost) begin
                        cost_table[next_state] <= next_cost;
                        if (q_tail < 31) begin
                            queue[q_tail] <= next_state;
                            q_tail <= q_tail + 1;
                            queue_empty <= 1'b0;
                        end
                    end
                    state <= S_PROCESS;
                end
            end
            
            S_DONE: begin
                done <= 1'b1;
                if (!start) begin
                    state <= S_IDLE;
                end
            end
            
            default: state <= S_IDLE;
        endcase
    end
end

endmodule