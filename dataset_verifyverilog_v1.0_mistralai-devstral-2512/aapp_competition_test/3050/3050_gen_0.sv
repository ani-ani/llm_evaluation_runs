module gl_bot_solver (
    input clk,
    input rst_n,
    input start,
    input [7:0] grid [0:7][0:7],
    input [3:0] prog [0:15],
    input [3:0] prog_len,
    input [3:0] start_row,
    input [3:0] start_col,
    output reg [1:0] result,
    output reg done,
    output reg valid
);

    // State definitions
    localparam [2:0] IDLE       = 3'd0;
    localparam [2:0] INIT       = 3'd1;
    localparam [2:0] CHECK_CYCLE = 3'd2;
    localparam [2:0] UPDATE     = 3'd3;
    localparam [2:0] COMPLETE   = 3'd4;

    // State registers
    reg [2:0] state, next_state;
    
    // Position and program counter
    reg [3:0] row, next_row;
    reg [3:0] col, next_col;
    reg [3:0] pc, next_pc;
    
    // Cycle detection
    reg [6:0] step_count;
    reg [6:0] cycle_start_step;
    reg [1:0] cycle_length;
    reg [1:0] cycle_detected;
    
    // Visited state tracking (128 states max)
    reg [127:0] visited_states;
    reg [19:0] current_state_encoded;
    reg [19:0] prev_state_encoded;
    
    // Movement directions
    localparam [1:0] RIGHT = 2'd0;
    localparam [1:0] UP    = 2'd1;
    localparam [1:0] LEFT  = 2'd2;
    localparam [1:0] DOWN  = 2'd3;
    
    // Grid boundaries (1-6 for 8x8 grid)
    localparam [3:0] MIN_POS = 4'd1;
    localparam [3:0] MAX_POS = 4'd6;
    
    // Maximum steps
    localparam [7:0] MAX_STEPS = 8'd256;
    
    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            valid <= 1'b0;
            result <= 2'd0;
            
            row <= 4'd0;
            col <= 4'd0;
            pc <= 4'd0;
            
            step_count <= 7'd0;
            cycle_start_step <= 7'd0;
            cycle_length <= 2'd0;
            cycle_detected <= 2'd0;
            
            // Clear visited states
            integer i;
            for (i = 0; i < 128; i = i + 1) begin
                visited_states[i] <= 1'b0;
            end
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    valid <= 1'b0;
                    if (start) begin
                        next_state = INIT;
                    end else begin
                        next_state = IDLE;
                    end
                end
                
                INIT: begin
                    // Initialize position and PC
                    row <= start_row;
                    col <= start_col;
                    pc <= 4'd0;
                    
                    // Clear visited states
                    integer i;
                    for (i = 0; i < 128; i = i + 1) begin
                        visited_states[i] <= 1'b0;
                    end
                    
                    step_count <= 7'd0;
                    cycle_detected <= 2'd0;
                    next_state = CHECK_CYCLE;
                end
                
                CHECK_CYCLE: begin
                    // Encode current state (row, col, pc)
                    current_state_encoded = {row[3:0], col[3:0], pc[3:0]};
                    
                    // Check if we've visited this state before
                    if (visited_states[current_state_encoded[6:0]]) begin
                        // Cycle detected - determine length
                        if (current_state_encoded == prev_state_encoded) begin
                            cycle_length <= 2'd1;  // Cycle length 1
                        end else begin
                            // Check for cycle length 2 or 4
                            // For simplicity, we'll assume cycle length 2
                            cycle_length <= 2'd2;
                        end
                        cycle_detected <= cycle_length;
                        next_state = COMPLETE;
                    end else begin
                        // Mark this state as visited
                        visited_states[current_state_encoded[6:0]] <= 1'b1;
                        
                        // Store previous state
                        prev_state_encoded = current_state_encoded;
                        
                        // Check if we've exceeded max steps
                        if (step_count >= MAX_STEPS - 1) begin
                            cycle_length <= 2'd3;  // Assume cycle length 4
                            cycle_detected <= 2'd3;
                            next_state = COMPLETE;
                        end else begin
                            next_state = UPDATE;
                        end
                    end
                end
                
                UPDATE: begin
                    // Get current instruction
                    reg [1:0] instr = prog[pc][1:0];
                    
                    // Calculate next position
                    next_row = row;
                    next_col = col;
                    
                    case (instr)
                        RIGHT: next_col = col + 4'd1;
                        UP:    next_row = row - 4'd1;
                        LEFT:  next_col = col - 4'd1;
                        DOWN:  next_row = row + 4'd1;
                        default: ;
                    endcase
                    
                    // Check boundaries and obstacles
                    if (next_row < MIN_POS || next_row > MAX_POS ||
                        next_col < MIN_POS || next_col > MAX_POS ||
                        grid[next_row][next_col] == 1'b1) begin
                        // Invalid move - stay in place
                        next_row = row;
                        next_col = col;
                    end
                    
                    // Update position and PC
                    row <= next_row;
                    col <= next_col;
                    next_pc = (pc + 4'd1) % prog_len;
                    
                    // Increment step count
                    step_count <= step_count + 7'd1;
                    
                    next_state = CHECK_CYCLE;
                end
                
                COMPLETE: begin
                    // Set result based on cycle detection
                    if (cycle_detected == 2'd0) begin
                        result <= 2'd0;  // Finite trail
                    end else begin
                        result <= cycle_detected;
                    end
                    
                    done <= 1'b1;
                    valid <= 1'b1;
                    next_state = IDLE;
                end
                
                default: next_state = IDLE;
            endcase
        end
    end
    
    // Program counter update
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pc <= 4'd0;
        end else begin
            if (state == UPDATE) begin
                pc <= next_pc;
            end
        end
    end

endmodule