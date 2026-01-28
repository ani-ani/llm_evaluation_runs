module bid_checker (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] len,
    input wire [31:0] data_in,
    input wire [3:0] idx_in,
    input wire we,
    output reg [31:0] result,
    output reg done,
    output reg valid
);

    // --- Internal Memory (Register File) ---
    reg [31:0] ram [0:15];
    integer i;
    
    // --- FSM States ---
    localparam [2:0] IDLE        = 3'd0;
    localparam [2:0] LOAD        = 3'd1;
    localparam [2:0] FETCH_REF   = 3'd2;
    localparam [2:0] NORMALIZE   = 3'd3;
    localparam [2:0] COMPARE     = 3'd4;
    localparam [2:0] FINISH      = 3'd5;
    
    // --- Normalization Sub-State ---
    localparam [1:0] NORM_IDLE   = 2'd0;
    localparam [1:0] NORM_CHECK  = 2'd1;
    localparam [1:0] NORM_DIV3   = 2'd2;
    localparam [1:0] NORM_DONE   = 2'd3;

    // --- Registers ---
    reg [2:0] state;
    reg [2:0] next_state;
    reg [1:0] norm_state;
    reg [1:0] next_norm_state;
    
    reg [3:0] idx;
    reg [31:0] current_val;
    reg [31:0] ref_core;
    reg fail_flag;
    
    // --- Divider Registers (for /3) ---
    reg [31:0] div_a;
    reg [31:0] div_b;
    reg [31:0] div_rem;
    reg [4:0] div_bits;
    reg div_busy;

    // --- Main FSM ---
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            norm_state <= NORM_IDLE;
            done <= 1'b0;
            valid <= 1'b0;
            result <= 32'd0;
            fail_flag <= 1'b0;
            idx <= 4'd0;
            current_val <= 32'd0;
            ref_core <= 32'd0;
            div_busy <= 1'b0;
            div_a <= 32'd0;
            div_b <= 32'd0;
            div_rem <= 32'd0;
            div_bits <= 5'd0;
        end else begin
            state <= next_state;
            norm_state <= next_norm_state;
            
            // --- Memory Write ---
            if (we) begin
                ram[idx_in] <= data_in;
            end
            
            // --- Logic Based on State ---
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    valid <= 1'b0;
                    fail_flag <= 1'b0;
                    idx <= 4'd0;
                end
                
                FETCH_REF: begin
                    // Read first element to establish reference
                    current_val <= ram[idx];
                    ref_core <= 32'd0; // Will hold result
                end
                
                NORMALIZE: begin
                    // Sub-FSM for division logic
                    case (norm_state)
                        NORM_IDLE: begin
                            // Check for Div by 2
                            if (current_val[0] == 1'b0 && current_val > 32'd0) begin
                                current_val <= {1'b0, current_val[31:1]}; // Shift right
                            end
                        end
                        NORM_CHECK: begin
                            // Check if divisible by 3
                            if (current_val >= 32'd3 && div_rem == 32'd0 && !div_busy) begin
                                // Start Divider
                                div_a <= current_val;
                                div_b <= 32'd3;
                                div_bits <= 5'd32;
                                div_rem <= 32'd0;
                                div_busy <= 1'b1;
                            end
                        end
                        NORM_DIV3: begin
                            // Restoring division step
                            if (div_bits > 0) begin
                                {div_rem, div_a} <= {div_rem[30:0], div_a, 1'b1} << 1;
                                if (div_rem[31:0] >= div_b) begin
                                    div_rem <= div_rem - div_b;
                                    div_a[0] <= 1'b1;
                                end
                                div_bits <= div_bits - 5'd1;
                            end else begin
                                // Division complete
                                div_busy <= 1'b0;
                                if (div_rem == 32'd0) begin
                                    current_val <= div_a; // Quotient
                                end
                            end
                        end
                    endcase
                end
                
                COMPARE: begin
                    if (idx == 4'd0) begin
                        ref_core <= current_val;
                    end else begin
                        if (current_val != ref_core) begin
                            fail_flag <= 1'b1;
                        end
                    end
                end
                
                FINISH: begin
                    done <= 1'b1;
                    result <= ref_core;
                    valid <= ~fail_flag;
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

    // --- Next State Logic ---
    always @(*) begin
        next_state = state;
        next_norm_state = norm_state;
        
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = LOAD;
                end
            end
            
            LOAD: begin
                // Wait for manual loading phase to finish (indicated by start falling or external trigger)
                // Since start is a pulse, we rely on it being handled in the testbench.
                // We transition immediately to process if data is ready.
                // Assuming testbench sets up data before asserting start again, or uses `we` during IDLE.
                // Here we use 'start' as the trigger to begin processing the already loaded data.
                if (len > 4'd0) begin
                    next_state = FETCH_REF;
                end else begin
                    next_state = FINISH; // Empty array check
                end
            end
            
            FETCH_REF: begin
                next_state = NORMALIZE;
                next_norm_state = NORM_IDLE;
            end
            
            NORMALIZE: begin
                // Logic driven by norm_state
                // 1. Handle Div by 2 (fast)
                if (norm_state == NORM_IDLE) begin
                    if (current_val[0] == 1'b0 && current_val > 32'd0) begin
                        next_norm_state = NORM_IDLE; // Keep looping for 2s
                    end else begin
                        next_norm_state = NORM_CHECK;
                    end
                end
                // 2. Check for Div by 3
                else if (norm_state == NORM_CHECK) begin
                    if (current_val >= 32'd3) begin
                        // We need to calculate modulo 3. 
                        // Ideally we check (val % 3 == 0). 
                        // Using a modulo check function or logic.
                        // Here we assume we invoke a divider check.
                        // To keep it simple and synthesizeable without a huge combinational path:
                        // We will just try to divide by 3.
                        // But we need a check first to avoid wasting cycles.
                        // Let's use a simple heuristic: sum of digits in base 2 mod 3? No, that's for 5.
                        // For mod 3: bits with even weight (0,2,4...) minus bits with odd weight (1,3,5...)
                        // Hard to do in one cycle comb logic for 32 bits in FPGA logic grid lightly.
                        // We will skip the check and just run the divider. If remainder != 0, we reject the division.
                        // Since this is a sub-module, we need a divider logic.
                        // Let's invoke the divider state here.
                        next_norm_state = NORM_DIV3;
                        // We need a flag to know if we should apply the quotient or discard it.
                        // We will check `div_rem` at the end of NORM_DIV3.
                    end else begin
                        next_norm_state = NORM_DONE;
                    end
                end
                // 3. Divider Iteration
                else if (norm_state == NORM_DIV3) begin
                    if (div_busy) begin
                        next_norm_state = NORM_DIV3; // Wait for 32 cycles
                    end else begin
                        // Division complete, check remainder
                        if (div_rem == 32'd0 && current_val > 32'd3) begin
                            // Divisible, repeat process
                            next_norm_state = NORM_IDLE;
                        end else begin
                            // Not divisible or done
                            next_norm_state = NORM_DONE;
                        end
                    end
                end
                // 4. Normalization Complete
                else if (norm_state == NORM_DONE) begin
                    next_state = COMPARE;
                end
            end
            
            COMPARE: begin
                // Check if we processed all elements
                if (idx < len - 1) begin
                    idx = idx + 1; // Increment index (blocking for next cycle logic)
                    current_val = ram[idx + 1]; // Fetch next
                    next_state = NORMALIZE;
                    next_norm_state = NORM_IDLE;
                end else begin
                    next_state = FINISH;
                end
            end
            
            FINISH: begin
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end

endmodule