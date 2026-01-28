module magic_spell_optimize(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [1:0] step_type,
    input wire step_valid,
    input wire step_end,
    output reg [11:0] result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE      = 3'd0;
    localparam [2:0] REC_INPUT = 3'd1;
    localparam [2:0] COMPUTE   = 3'd2;
    localparam [2:0] BACKTRACE = 3'd3;
    localparam [2:0] FINISH    = 3'd4;
    
    // Internal registers and state variables
    reg [2:0] state, next_state;
    reg [3:0] step_count;        // Current step index (0 to 15)
    reg [3:0] total_steps;       // Total number of steps received
    reg [11:0] counter;          // General purpose counter for loops
    reg [3:0] trace_step;        // Step index for backtrace
    reg [11:0] trace_val;        // Value for backtrace
    reg found_max;               // Flag for finding max value
    reg [11:0] temp_val;         // Temporary storage
    reg [11:0] max_val;          // Current maximum value found
    
    // Memory for storing step types (16 steps x 2 bits = 32 bits)
    reg [1:0] steps [0:15];
    
    // Memory for DP: reachable states (4096 bits for S=12)
    // Use 128 x 32-bit registers for reachable_curr
    // reachable_curr[val] indicates if value 'val' is reachable
    reg reachable_curr [0:4095];
    reg reachable_next [0:4095];
    
    // Memory for backtrace decisions: 16 steps x 4096 bits
    // decisions[step][val] = 1 if value 'val' was achieved by keeping the step
    reg decisions [0:15][0:4095];
    
    // Temporary variables for combinational logic
    reg [11:0] new_val_add;
    reg [11:0] new_val_mul;
    integer i;
    
    // Sequential state transition and register updates
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            step_count <= 4'd0;
            total_steps <= 4'd0;
            counter <= 12'd0;
            trace_step <= 4'd0;
            trace_val <= 12'd0;
            found_max <= 1'b0;
            temp_val <= 12'd0;
            max_val <= 12'd0;
            result <= 12'd0;
            done <= 1'b0;
            // Initialize memory arrays
            for (i = 0; i < 16; i = i + 1) begin
                steps[i] <= 2'b00;
            end
            for (i = 0; i < 4096; i = i + 1) begin
                reachable_curr[i] <= 1'b0;
                reachable_next[i] <= 1'b0;
            end
            for (int j = 0; j < 16; j = j + 1) begin
                for (i = 0; i < 4096; i = i + 1) begin
                    decisions[j][i] <= 1'b0;
                end
            end
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    step_count <= 4'd0;
                    total_steps <= 4'd0;
                    counter <= 12'd0;
                    trace_step <= 4'd0;
                    trace_val <= 12'd0;
                    found_max <= 1'b0;
                    max_val <= 12'd0;
                    result <= 12'd0;
                    // Clear reachable array (except index 0 which will be set in REC_INPUT)
                    for (i = 0; i < 4096; i = i + 1) begin
                        reachable_curr[i] <= 1'b0;
                        reachable_next[i] <= 1'b0;
                    end
                    // Clear decisions array
                    for (int j = 0; j < 16; j = j + 1) begin
                        for (i = 0; i < 4096; i = i + 1) begin
                            decisions[j][i] <= 1'b0;
                        end
                    end
                end
                
                REC_INPUT: begin
                    if (step_valid && step_count < 15) begin
                        steps[step_count] <= step_type;
                        step_count <= step_count + 4'd1;
                    end
                    if (step_end) begin
                        total_steps <= step_count;
                    end
                end
                
                COMPUTE: begin
                    // Loop through steps and update reachable states
                    // This block handles the logic for one step per clock cycle
                    // Using counter to iterate through values (0 to 4095)
                    // and step_count to track current step index
                    
                    if (counter == 12'd0) begin
                        // Initialize for new step
                        if (step_count == 0) begin
                            // First step: start with power 1
                            reachable_curr[12'd1] <= 1'b1;
                        end
                    end
                    
                    if (counter < 4096) begin
                        // Process current value
                        if (reachable_curr[counter]) begin
                            // Keep step (skip 'o' operation means keeping original)
                            // Transition based on step type
                            if (steps[step_count] == 2'b00) begin // '+'
                                new_val_add = (counter + 1) & 12'hFFF;
                                reachable_next[new_val_add] <= 1'b1;
                                decisions[step_count][new_val_add] <= 1'b1;
                            end else if (steps[step_count] == 2'b01) begin // 'x'
                                new_val_mul = (counter << 1) & 12'hFFF;
                                reachable_next[new_val_mul] <= 1'b1;
                                decisions[step_count][new_val_mul] <= 1'b1;
                            end
                            // Skip step: value remains reachable
                            reachable_next[counter] <= 1'b1;
                        end
                        counter <= counter + 12'd1;
                    end else if (counter == 4096) begin
                        // Copy next to curr and reset for next step
                        for (i = 0; i < 4096; i = i + 1) begin
                            reachable_curr[i] <= reachable_next[i];
                            reachable_next[i] <= 1'b0;
                        end
                        step_count <= step_count + 4'd1;
                        counter <= 12'd0;
                    end
                end
                
                BACKTRACE: begin
                    if (!found_max) begin
                        // Find maximum reachable value
                        if (reachable_curr[counter]) begin
                            max_val <= counter;
                            found_max <= 1'b1;
                        end
                        counter <= counter + 12'd1;
                    end else begin
                        // Reconstruct path
                        if (trace_step > 0) begin
                            trace_step <= trace_step - 4'd1;
                            // Check if value was achieved by keeping the step
                            if (decisions[trace_step][trace_val]) begin
                                // Kept step: reverse operation
                                if (steps[trace_step] == 2'b00) begin // '+'
                                    trace_val <= (trace_val - 1) & 12'hFFF;
                                end else if (steps[trace_step] == 2'b01) begin // 'x'
                                    trace_val <= (trace_val >> 1) & 12'hFFF;
                                end
                            end
                            // If not kept, trace_val remains same
                        end else begin
                            result <= trace_val;
                        end
                    end
                end
                
                FINISH: begin
                    done <= 1'b1;
                end
                
                default: begin
                    state <= IDLE;
                    done <= 1'b0;
                end
            endcase
        end
    end
    
    // Combinational next_state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start)
                    next_state = REC_INPUT;
            end
            REC_INPUT: begin
                if (step_end)
                    next_state = COMPUTE;
            end
            COMPUTE: begin
                // Wait for all steps to be processed
                if (step_count >= total_steps && counter == 4096)
                    next_state = BACKTRACE;
            end
            BACKTRACE: begin
                if (found_max && trace_step == 0 && counter >= 4096)
                    next_state = FINISH;
            end
            FINISH: begin
                if (!start)
                    next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end
endmodule