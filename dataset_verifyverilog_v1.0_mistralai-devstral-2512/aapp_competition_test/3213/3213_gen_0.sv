module magic_spell_optimizer(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [1:0] step_type,
    input wire step_valid,
    input wire step_end,
    output reg [11:0] result,
    output reg done
);

    // State definitions
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] PROCESS = 2'd1;
    localparam [1:0] COMPUTE = 2'd2;
    localparam [1:0] OUTPUT = 2'd3;
    
    reg [1:0] state, next_state;
    
    // Step counter and storage
    reg [3:0] step_count;
    reg [1:0] step_buffer [0:15];
    reg [3:0] step_ptr;
    
    // DP state: reachable values (bit vector)
    reg [4095:0] reachable_curr;
    reg [4095:0] reachable_next;
    
    // Decision tracking (for backtracing)
    reg [4095:0] decision [0:15];
    
    // Maximum value tracking
    reg [11:0] max_value;
    reg [11:0] max_state;
    
    // Cycle counter to prevent infinite loops
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd200;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            step_count <= 4'd0;
            step_ptr <= 4'd0;
            reachable_curr <= 4096'd0;
            reachable_next <= 4096'd0;
            result <= 12'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            
            // Initialize decision tracking
            integer i, j;
            for (i = 0; i < 16; i = i + 1) begin
                for (j = 0; j < 4096; j = j + 1) begin
                    decision[i][j] <= 1'b0;
                end
            end
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        // Initialize for new computation
                        step_count <= 4'd0;
                        step_ptr <= 4'd0;
                        reachable_curr <= 4096'd0;
                        reachable_curr[1] <= 1'b1;  // Start with power=1
                        next_state <= PROCESS;
                    end
                end
                
                PROCESS: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Buffer steps until step_end
                    if (step_valid && !step_end) begin
                        step_buffer[step_count] <= step_type;
                        step_count <= step_count + 4'd1;
                    end
                    
                    if (step_end) begin
                        // Start computation
                        next_state <= COMPUTE;
                        step_ptr <= 4'd0;
                    end
                    
                    // Safety: prevent infinite loops
                    if (cycle_count >= MAX_CYCLES) begin
                        next_state <= IDLE;
                    end
                end
                
                COMPUTE: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Initialize next state
                    reachable_next <= 4096'd0;
                    
                    // Process current step
                    if (step_ptr < step_count) begin
                        // Option 1: Skip this step (no-op)
                        reachable_next <= reachable_next | reachable_curr;
                        
                        // Option 2: Apply this step
                        integer i;
                        for (i = 0; i < 4096; i = i + 1) begin
                            if (reachable_curr[i]) begin
                                if (step_buffer[step_ptr] == 2'd0) begin  // '+' operation
                                    reachable_next[(i + 1) % 4096] <= 1'b1;
                                    decision[step_ptr][(i + 1) % 4096] <= 1'b1;  // Mark as kept
                                end else if (step_buffer[step_ptr] == 2'd1) begin  // 'x' operation
                                    reachable_next[(i * 2) % 4096] <= 1'b1;
                                    decision[step_ptr][(i * 2) % 4096] <= 1'b1;  // Mark as kept
                                end
                            end
                        end
                        
                        // Move to next step
                        step_ptr <= step_ptr + 4'd1;
                        reachable_curr <= reachable_next;
                    end else begin
                        // Find maximum value
                        integer i;
                        max_value <= 12'd0;
                        for (i = 4095; i >= 0; i = i - 1) begin
                            if (reachable_curr[i]) begin
                                max_value <= i;
                                break;
                            end
                        end
                        
                        next_state <= OUTPUT;
                    end
                    
                    // Safety: prevent infinite loops
                    if (cycle_count >= MAX_CYCLES) begin
                        next_state <= IDLE;
                    end
                end
                
                OUTPUT: begin
                    result <= max_value;
                    done <= 1'b1;
                    next_state <= IDLE;
                end
                
                default: next_state <= IDLE;
            endcase
        end
    end

endmodule