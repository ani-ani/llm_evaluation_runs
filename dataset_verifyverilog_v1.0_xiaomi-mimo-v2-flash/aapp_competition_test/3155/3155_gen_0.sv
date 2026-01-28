module jeopardy_ai (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [31:0] X,
    output reg [5:0] n,
    output reg [5:0] k,
    output reg done,
    output reg valid
);

    // State definitions
    localparam [2:0] IDLE         = 3'd0;
    localparam [2:0] CHECK_X      = 3'd1;
    localparam [2:0] CHECK_SPECIAL= 3'd2;
    localparam [2:0] SETUP_N      = 3'd3;
    localparam [2:0] SETUP_K      = 3'd4;
    localparam [2:0] COMPUTE_C    = 3'd5;
    localparam [2:0] CHECK_C      = 3'd6;
    localparam [2:0] FINISH       = 3'd7;

    // Internal registers
    reg [2:0] state, next_state;
    reg [5:0] best_n_reg, best_k_reg;
    reg [5:0] current_n_reg, current_k_reg;
    reg [63:0] current_C_reg;
    reg [63:0] temp_C;
    reg found_reg;
    reg [31:0] X_reg;
    reg [5:0] max_k_reg;
    reg [6:0] loop_counter; // for up to 65 iterations
    reg [5:0] k_temp;
    
    // Constants
    localparam [63:0] MAX_C = 64'd1832624140942590534; // C(64,32)
    localparam [5:0] MAX_N = 6'd64;

    // Next state logic
    always @(*) begin
        case (state)
            IDLE: next_state = start ? CHECK_X : IDLE;
            
            CHECK_X: begin
                if (X_reg > MAX_C)
                    next_state = FINISH; // invalid
                else
                    next_state = CHECK_SPECIAL;
            end
            
            CHECK_SPECIAL: begin
                if (X_reg == 32'd1)
                    next_state = FINISH; // special case: n=0,k=0
                else
                    next_state = SETUP_N;
            end
            
            SETUP_N: next_state = SETUP_K;
            
            SETUP_K: begin
                if (current_k_reg > max_k_reg)
                    next_state = SETUP_N; // move to next n
                else
                    next_state = COMPUTE_C;
            end
            
            COMPUTE_C: next_state = CHECK_C;
            
            CHECK_C: begin
                if (current_C_reg > X_reg)
                    next_state = SETUP_N; // C too large, next n
                else if (current_C_reg == X_reg)
                    next_state = FINISH; // found
                else
                    next_state = SETUP_K; // try next k
            end
            
            FINISH: next_state = IDLE;
            
            default: next_state = IDLE;
        endcase
    end

    // State transition
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            valid <= 1'b0;
            n <= 6'd0;
            k <= 6'd0;
            best_n_reg <= 6'd0;
            best_k_reg <= 6'd0;
            current_n_reg <= 6'd0;
            current_k_reg <= 6'd0;
            current_C_reg <= 64'd0;
            found_reg <= 1'b0;
            X_reg <= 32'd0;
            max_k_reg <= 6'd0;
            loop_counter <= 7'd0;
        end else begin
            state <= next_state;
            
            // Default values
            done <= 1'b0;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    valid <= 1'b0;
                    n <= 6'd0;
                    k <= 6'd0;
                end
                
                CHECK_X: begin
                    X_reg <= X;
                    found_reg <= 1'b0;
                    best_n_reg <= 6'd0;
                    best_k_reg <= 6'd0;
                end
                
                CHECK_SPECIAL: begin
                    if (X_reg == 32'd1) begin
                        found_reg <= 1'b1;
                        best_n_reg <= 6'd0;
                        best_k_reg <= 6'd0;
                    end
                end
                
                SETUP_N: begin
                    if (found_reg) begin
                        // Already found a solution, we shouldn't be here
                        // But if we are, go to finish
                        // Actually, logic flow should prevent this
                    end
                    // If current_n was 64 and we didn't find, go to finish
                    if (current_n_reg == MAX_N) begin
                        // will transition to finish in next state logic implicitly? 
                        // No, we need to handle here or in CHECK_C
                    end
                end
                
                SETUP_K: begin
                    if (current_k_reg > max_k_reg) begin
                        // increment n
                        current_n_reg <= current_n_reg + 6'd1;
                        current_k_reg <= 6'd0;
                    end else begin
                        // compute C(n,k) iteratively
                        if (current_k_reg == 6'd0) begin
                            current_C_reg <= 64'd1;
                        end else begin
                            // C(n,k) = C(n,k-1) * (n-k+1) / k
                            // We need to do this in one cycle? 
                            // To avoid combinational logic for 64-bit division, 
                            // we will compute in separate state or use next_state logic.
                            // Since we are in SETUP_K, we transition to COMPUTE_C.
                        end
                    end
                end
                
                COMPUTE_C: begin
                    // Compute C(n,k) from C(n,k-1)
                    if (current_k_reg == 6'd0) begin
                        current_C_reg <= 64'd1;
                    end else begin
                        // Optimization: multiply then divide
                        // C(n,k-1) * (n - k + 1) / k
                        // Note: n, k are small (<= 64). 
                        // We can do this with temporary variables if we had more states,
                        // but let's do a safe computation.
                        // Since this is a single cycle state, we rely on combinational calc
                        // assigned to current_C_reg in update logic below (or here if combinational).
                        // But Verilog requires update in procedural block.
                        // Let's use the update block for the calculation.
                        // We need to be careful with 64-bit division. 
                        // Most synthesis tools support 64-bit div.
                        // However, to be safe and explicit, we break it down if needed.
                        // Here we assume synthesis supports 64-bit div.
                        current_C_reg <= ((current_C_reg * (current_n_reg - current_k_reg + 6'd1)) / current_k_reg);
                    end
                end
                
                CHECK_C: begin
                    if (current_C_reg == X_reg) begin
                        found_reg <= 1'b1;
                        best_n_reg <= current_n_reg;
                        best_k_reg <= current_k_reg;
                        // We found the match. 
                        // Since we iterate n from 0 and k from 0, 
                        // the first match IS the smallest n, smallest k.
                        // We can stop searching, but FSM must go to FINISH.
                    end
                    
                    // Prepare for next iteration
                    if (current_C_reg > X_reg || current_C_reg == X_reg) begin
                        // If > X, we are done with this n (since C increases then decreases? 
                        // Wait, C(n,k) increases up to n/2 then decreases.
                        // Since we iterate k=0 to n/2, C(n,k) increases strictly.
                        // So if C > X, no solution for this n. Move to next n.
                        current_k_reg <= 6'd0;
                        current_n_reg <= current_n_reg + 6'd1;
                    end else begin
                        // C < X, try next k
                        current_k_reg <= current_k_reg + 6'd1;
                    end
                    
                    // Check for limit
                    if (current_n_reg > MAX_N && !found_reg) begin
                        // reached end without finding
                        found_reg <= 1'b0; // ensure 0
                    end
                end
                
                FINISH: begin
                    done <= 1'b1;
                    valid <= found_reg;
                    n <= best_n_reg;
                    k <= best_k_reg;
                    // Reset search counters for next start
                    current_n_reg <= 6'd0;
                    current_k_reg <= 6'd0;
                    current_C_reg <= 64'd0;
                end
            endcase
            
            // State-specific setups that don't fit cleanly above
            if (state == SETUP_N) begin
                if (current_n_reg > MAX_N) begin
                    // If we are at SETUP_N and n > 64, we failed to find
                    // Next state is FINISH (handled by next_state logic? No, 
                    // next_state logic sees SETUP_N -> SETUP_K. 
                    // We need to detect end of search here.)
                    // Actually, max n is 64. If current_n_reg becomes 65, we stop.
                    // The CHECK_C state sets current_n to +1. 
                    // If current_n was 64 in CHECK_C, it becomes 65 here.
                    // We should detect this.
                    if (found_reg == 1'b0) begin
                        // Force finish? Or let FSM run.
                        // If current_n > 64, we shouldn't compute K.
                        // We can set a flag or force state.
                    end
                end
                // Adjust max_k for current_n (floor(n/2))
                max_k_reg <= current_n_reg >> 1;
            end
            
            // Logic to handle n > 64 transition
            if (state == SETUP_K && current_n_reg > MAX_N) begin
                // Go to finish
                // We can manipulate next_state logic or do it here.
                // Since next_state is combinational, we can't easily force it.
                // We'll rely on CHECK_C to set found_reg=0 and eventually hit FINISH.
                // Wait, if n=65, we shouldn't compute. 
                // Let's update max_k_reg logic in SETUP_N.
                // If current_n > MAX_N, set max_k to 0 (or -1).
                if (current_n_reg > MAX_N) begin
                    max_k_reg <= 6'd0; // Force immediate exit of k loop
                end
            end
            
            // If we found the solution in CHECK_C, we should ideally skip remaining n.
            // The logic above sets found_reg=1. 
            // In SETUP_K, if found_reg is 1, we might want to jump to finish.
            // But standard first-match logic: we found (n,k) for current n.
            // Any future (n', k') will have n' > n, so we don't care.
            // So if found_reg == 1, we should go to FINISH.
            // We can force next_state to FINISH if found_reg is set during search.
            // Actually, let's add a condition in next_state logic for SETUP_K.
        end
    end
    
    // Correction for next_state logic regarding found_reg and n limit
    always @(*) begin
        if (state == SETUP_K && found_reg)
            next_state = FINISH;
        if (state == SETUP_K && current_n_reg > MAX_N)
            next_state = FINISH; // Reached end without finding
    end

endmodule