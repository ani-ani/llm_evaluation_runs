module torus_puzzle_solver (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [1:0] grid [15:0],
    output reg [3:0] moves,
    output reg done
);
    
    // State declarations
    localparam [2:0] IDLE      = 3'd0;
    localparam [2:0] INIT      = 3'd1;
    localparam [2:0] BFS       = 3'd2;
    localparam [2:0] CHECK     = 3'd3;
    localparam [2:0] FINISH    = 3'd4;
    
    reg [2:0] state;
    
    // Internal state representation (32-bit)
    reg [31:0] current_state;
    reg [31:0] next_state;
    
    // BFS queue (circular buffer)
    reg [31:0] queue [0:15];  // 16 entries (depth limit 12)
    reg [3:0] queue_head;
    reg [3:0] queue_tail;
    reg [3:0] queue_count;
    
    // Depth tracking
    reg [3:0] current_depth;
    reg [3:0] next_depth;
    
    // Visited RAM (simplified with 16-bit hash)
    reg [15:0] visited_ram [0:65535];
    reg [15:0] current_hash;
    
    // Move generation
    reg [3:0] move_index;
    reg [31:0] temp_state;
    
    // LFSR for hashing
    reg [15:0] lfsr;
    
    // Helper signals
    reg state_solved;
    reg state_visited;
    
    // Flatten grid to 32-bit state
    always @(*) begin
        current_state = {
            grid[15], grid[14], grid[13], grid[12],
            grid[11], grid[10], grid[9],  grid[8],
            grid[7],  grid[6],  grid[5],  grid[4],
            grid[3],  grid[2],  grid[1],  grid[0]
        };
    end
    
    // LFSR for hashing
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            lfsr <= 16'd1;
        end else begin
            lfsr[0] <= lfsr[15] ^ lfsr[13] ^ lfsr[12] ^ lfsr[10];
            lfsr[15:1] <= lfsr[14:0];
        end
    end
    
    // Hash computation
    always @(*) begin
        temp_state = current_state;
        current_hash = 16'd0;
        for (integer i = 0; i < 32; i = i + 1) begin
            current_hash = (current_hash << 1) | temp_state[0];
            temp_state = temp_state >> 1;
        end
    end
    
    // Check if state is solved
    always @(*) begin
        state_solved = 1'b1;
        for (integer i = 0; i < 4; i = i + 1) begin
            if (current_state[2*i+1:2*i] != 2'd0) begin
                state_solved = 1'b0;
            end
        end
        for (integer i = 4; i < 8; i = i + 1) begin
            if (current_state[2*i+1:2*i] != 2'd1) begin
                state_solved = 1'b0;
            end
        end
        for (integer i = 8; i < 12; i = i + 1) begin
            if (current_state[2*i+1:2*i] != 2'd2) begin
                state_solved = 1'b0;
            end
        end
        for (integer i = 12; i < 16; i = i + 1) begin
            if (current_state[2*i+1:2*i] != 2'd3) begin
                state_solved = 1'b0;
            end
        end
    end
    
    // Check if state is visited
    always @(*) begin
        state_visited = visited_ram[current_hash];
    end
    
    // Move generation (row/column shifts)
    always @(*) begin
        case (move_index)
            // Row shifts (left/right)
            4'd0:  next_state = {current_state[1:0], current_state[31:2]};  // Row 0 left
            4'd1:  next_state = {current_state[30:0], current_state[31]};  // Row 0 right
            4'd2:  next_state = {current_state[5:0], current_state[31:6]};  // Row 1 left
            4'd3:  next_state = {current_state[30:6], current_state[5:0]};  // Row 1 right
            4'd4:  next_state = {current_state[9:0], current_state[31:10]}; // Row 2 left
            4'd5:  next_state = {current_state[30:10], current_state[9:0]}; // Row 2 right
            4'd6:  next_state = {current_state[13:0], current_state[31:14]}; // Row 3 left
            4'd7:  next_state = {current_state[30:14], current_state[13:0]}; // Row 3 right
            
            // Column shifts (up/down)
            4'd8:  next_state = {current_state[2:0], current_state[31:3]};  // Col 0 up
            4'd9:  next_state = {current_state[31:1], current_state[0]};  // Col 0 down
            4'd10: next_state = {current_state[4:0], current_state[31:5]};  // Col 1 up
            4'd11: next_state = {current_state[31:3], current_state[2:0]};  // Col 1 down
            4'd12: next_state = {current_state[6:0], current_state[31:7]};  // Col 2 up
            4'd13: next_state = {current_state[31:5], current_state[4:0]};  // Col 2 down
            4'd14: next_state = {current_state[8:0], current_state[31:9]};  // Col 3 up
            4'd15: next_state = {current_state[31:7], current_state[6:0]};  // Col 3 down
            default: next_state = current_state;
        endcase
    end
    
    // Main FSM
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            moves <= 4'd0;
            done <= 1'b0;
            queue_head <= 4'd0;
            queue_tail <= 4'd0;
            queue_count <= 4'd0;
            current_depth <= 4'd0;
            move_index <= 4'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= INIT;
                    end
                end
                
                INIT: begin
                    // Initialize queue with start state
                    queue[0] <= current_state;
                    queue_head <= 4'd0;
                    queue_tail <= 4'd1;
                    queue_count <= 4'd1;
                    current_depth <= 4'd0;
                    move_index <= 4'd0;
                    state <= BFS;
                end
                
                BFS: begin
                    if (queue_count == 4'd0) begin
                        state <= FINISH;
                    end else begin
                        // Dequeue
                        current_state <= queue[queue_head];
                        queue_head <= queue_head + 4'd1;
                        queue_count <= queue_count - 4'd1;
                        
                        if (state_solved) begin
                            moves <= current_depth;
                            state <= FINISH;
                        end else begin
                            state <= CHECK;
                        end
                    end
                end
                
                CHECK: begin
                    if (move_index == 4'd16) begin
                        move_index <= 4'd0;
                        state <= BFS;
                    end else begin
                        // Generate next state
                        next_state <= current_state;
                        next_depth <= current_depth + 4'd1;
                        
                        // Check if visited
                        if (!state_visited && next_depth <= 4'd12) begin
                            // Enqueue
                            queue[queue_tail] <= next_state;
                            queue_tail <= queue_tail + 4'd1;
                            queue_count <= queue_count + 4'd1;
                            visited_ram[current_hash] <= 1'b1;
                        end
                        
                        move_index <= move_index + 4'd1;
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
    
    // Handle queue wrap-around
    always @(posedge clk) begin
        if (queue_head == 4'd16) begin
            queue_head <= 4'd0;
        end
        if (queue_tail == 4'd16) begin
            queue_tail <= 4'd0;
        end
    end
    
endmodule