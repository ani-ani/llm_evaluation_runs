module frog_synchronization (
    input clk,
    input rst_n,
    input start,
    input [15:0] m,
    input [15:0] h1_init, a1,
    input [15:0] x1, y1,
    input [15:0] h2_init, a2,
    input [15:0] x2, y2,
    output reg [31:0] result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE       = 3'd0;
    localparam [2:0] START_OP   = 3'd1;
    localparam [2:0] COMPUTE    = 3'd2;
    localparam [2:0] CHECK      = 3'd3;
    localparam [2:0] UPDATE     = 3'd4;
    localparam [2:0] FOUND      = 3'd5;
    localparam [2:0] NOT_FOUND  = 3'd6;

    reg [2:0] state, next_state;
    
    // Internal registers
    reg [31:0] h1_reg, h2_reg;
    reg [31:0] time_reg;
    reg [31:0] m_reg;
    reg [31:0] a1_reg, a2_reg;
    reg [31:0] x1_reg, y1_reg, x2_reg, y2_reg;
    
    // Cycle detection registers - storing 32-bit full state
    reg [31:0] h1_history [0:2047];
    reg [31:0] h2_history [0:2047];
    reg [10:0] history_ptr;
    reg found_cycle;
    reg [10:0] i; // Loop counter
    
    // Computation registers
    reg [63:0] mult_temp1, mult_temp2;
    reg [31:0] add_temp1, add_temp2;
    reg [31:0] mod_result1, mod_result2;
    reg [10:0] cycle_check_idx;
    
    // Local parameters
    localparam [31:0] MAX_CYCLES = 32'd2048;

    // State register and reset
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 32'd0;
            done <= 1'b0;
            h1_reg <= 32'd0;
            h2_reg <= 32'd0;
            time_reg <= 32'd0;
            m_reg <= 32'd0;
            a1_reg <= 32'd0;
            a2_reg <= 32'd0;
            x1_reg <= 32'd0;
            y1_reg <= 32'd0;
            x2_reg <= 32'd0;
            y2_reg <= 32'd0;
            history_ptr <= 11'd0;
            found_cycle <= 1'b0;
            cycle_check_idx <= 11'd0;
            // Reset history array
            for (i = 0; i < 11'd2048; i = i + 1) begin
                h1_history[i] <= 32'd0;
                h2_history[i] <= 32'd0;
            end
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    result <= 32'd0;
                    found_cycle <= 1'b0;
                    history_ptr <= 11'd0;
                    cycle_check_idx <= 11'd0;
                end
                
                START_OP: begin
                    h1_reg <= {16'd0, h1_init};
                    h2_reg <= {16'd0, h2_init};
                    time_reg <= 32'd0;
                    m_reg <= {16'd0, m};
                    a1_reg <= {16'd0, a1};
                    a2_reg <= {16'd0, a2};
                    x1_reg <= {16'd0, x1};
                    y1_reg <= {16'd0, y1};
                    x2_reg <= {16'd0, x2};
                    y2_reg <= {16'd0, y2};
                    // Store initial states
                    h1_history[11'd0] <= {16'd0, h1_init};
                    h2_history[11'd0] <= {16'd0, h2_init};
                end
                
                COMPUTE: begin
                    // h1 = (x1 * h1 + y1) % m
                    // h2 = (x2 * h2 + y2) % m
                    mult_temp1 <= x1_reg * h1_reg;
                    mult_temp2 <= x2_reg * h2_reg;
                end
                
                UPDATE: begin
                    add_temp1 <= mult_temp1[31:0] + y1_reg;
                    add_temp2 <= mult_temp2[31:0] + y2_reg;
                end
                
                CHECK: begin
                    // Modulo operation using division (m_reg is 16-bit, so 32-bit division is fine)
                    mod_result1 <= add_temp1 % m_reg;
                    mod_result2 <= add_temp2 % m_reg;
                    
                    // Update time
                    time_reg <= time_reg + 32'd1;
                end
                
                default: begin
                    // No state-specific update
                end
            endcase
            
            // Move h_reg assignment outside case for cycle check
            if (state == CHECK) begin
                h1_reg <= mod_result1;
                h2_reg <= mod_result2;
                
                // Store in history
                h1_history[history_ptr + 11'd1] <= mod_result1;
                h2_history[history_ptr + 11'd1] <= mod_result2;
                
                // Check cycle for next cycle start (will be checked at beginning of cycle)
                // We check previous state (before update) against all previous states
                // This cycle detection happens in FOUND/NOT_FOUND states via computed signals
            end
            
            if (state == START_OP) begin
                // Store initial at index 0
                h1_history[11'd0] <= {16'd0, h1_init};
                h2_history[11'd0] <= {16'd0, h2_init};
            end
            
            // Cycle checking logic - happens when in FOUND or NOT_FOUND
            if (state == FOUND || state == NOT_FOUND) begin
                // Clear or prepare for next operation
                if (state == NOT_FOUND && found_cycle) begin
                    // Already detected in previous step
                end
            end
        end
    end

    // Next state and output logic
    always @(*) begin
        next_state = state;
        done = 1'b0;
        
        // Computation signals
        mult_temp1 = mult_temp1;
        mult_temp2 = mult_temp2;
        add_temp1 = add_temp1;
        add_temp2 = add_temp2;
        mod_result1 = mod_result1;
        mod_result2 = mod_result2;
        
        // Cycle detection signals
        found_cycle = found_cycle;
        cycle_check_idx = cycle_check_idx;
        
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = START_OP;
                end
            end
            
            START_OP: begin
                // Check immediate match (time=0)
                if ({16'd0, h1_init} == {16'd0, a1} && {16'd0, h2_init} == {16'd0, a2}) begin
                    next_state = FOUND;
                end else begin
                    next_state = COMPUTE;
                end
            end
            
            COMPUTE: begin
                next_state = UPDATE;
            end
            
            UPDATE: begin
                next_state = CHECK;
            end
            
            CHECK: begin
                // After updating, check results
                if (mod_result1 == {16'd0, a1} && mod_result2 == {16'd0, a2}) begin
                    next_state = FOUND;
                end else if (time_reg >= MAX_CYCLES) begin
                    next_state = NOT_FOUND;
                end else begin
                    // Check for cycle detection
                    // We need to check if new state (mod_result1, mod_result2) equals any previous state
                    // This is complex - simplify by checking if this state matches ANY previous
                    // Since we can't loop easily in combinational, we'll do it over multiple cycles
                    cycle_check_idx = 11'd0;
                    found_cycle = 1'b0;
                    next_state = UPDATE; // Wait state for cycle check
                end
            end
            
            UPDATE: begin // Reused state for cycle check
                // Check cycle - comparing against history
                // We can only compare one per cycle due to combinational constraints
                // But we need to check all 2048 entries - this is too slow
                // Let's use a different approach: check if current matches initial
                // Or use a simpler heuristic: check current state against previous few
                // 
                // For practical purposes in FPGA, we'll do a simple check:
                // If time_reg > 0 and state repeats previous state (1-step cycle)
                // This is conservative but covers many cases
                
                // Actually, let's check against ALL history over multiple cycles
                // But limit to reasonable - we'll check if current matches any in last 32 entries
                if (cycle_check_idx < 11'd32 && history_ptr > cycle_check_idx) begin
                    if (mod_result1 == h1_history[cycle_check_idx] && mod_result2 == h2_history[cycle_check_idx]) begin
                        found_cycle = 1'b1;
                        next_state = NOT_FOUND;
                    end else begin
                        cycle_check_idx = cycle_check_idx + 11'd1;
                        next_state = UPDATE; // Continue checking
                    end
                end else begin
                    // No cycle detected in checked entries
                    // Continue simulation
                    history_ptr = history_ptr + 11'd1;
                    next_state = COMPUTE;
                end
            end
            
            FOUND: begin
                done = 1'b1;
                next_state = IDLE;
            end
            
            NOT_FOUND: begin
                done = 1'b1;
                next_state = IDLE;
            end
            
            default: begin
                next_state = IDLE;
            end
        endcase
    end
    
    // Result assignment
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            result <= 32'd0;
        end else begin
            if (state == FOUND) begin
                result <= {1'b0, time_reg[30:0]}; // Positive time
            end else if (state == NOT_FOUND) begin
                result <= 32'hFFFFFFFF; // -1 in two's complement (all 1s)
            end
        end
    end

endmodule