module reconstruct_binary_string(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [31:0] a00,
    input wire [31:0] a01,
    input wire [31:0] a10,
    input wire [31:0] a11,
    output reg done,
    output reg valid,
    output reg [7:0] result_char,
    output reg is_impossible
);

    // State definitions
    localparam [2:0] IDLE     = 3'd0;
    localparam [2:0] CHECK    = 3'd1;
    localparam [2:0] FIND_N0  = 3'd2;
    localparam [2:0] FIND_N1  = 3'd3;
    localparam [2:0] VALIDATE = 3'd4;
    localparam [2:0] OUTPUT_CHAR = 3'd5;
    localparam [2:0] DONE_STATE = 3'd6;

    reg [2:0] state, next_state;
    
    // Internal registers
    reg [10:0] n0, n1;           // Max 1024 chars, so max 1024 of each
    reg [10:0] rem_n0, rem_n1;   // Remaining counts during output
    reg [31:0] rem_a01, rem_a10; // Remaining transitions
    reg [31:0] temp_rem_a01, temp_rem_a10;
    reg [31:0] n0_val, n1_val;   // Candidate values for search
    reg [31:0] test_val;         // For triangular number calculation
    reg [31:0] calc_result;      // For triangular calculation
    reg [31:0] cycle_count;      // Prevent infinite loops
    reg [31:0] max_cycles;       // 5000 cycles
    
    // Triangular calculation state
    localparam [1:0] TRIG_IDLE = 2'd0;
    localparam [1:0] TRIG_CALC = 2'd1;
    localparam [1:0] TRIG_DONE = 2'd2;
    reg [1:0] trig_state;
    reg [31:0] trig_i;
    reg [31:0] trig_target;
    
    // For finding n0/n1
    reg found_n0, found_n1;
    reg searching_n0, searching_n1;
    
    // Initialize all registers
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            valid <= 1'b0;
            result_char <= 8'd0;
            is_impossible <= 1'b0;
            n0 <= 11'd0;
            n1 <= 11'd0;
            rem_n0 <= 11'd0;
            rem_n1 <= 11'd0;
            rem_a01 <= 32'd0;
            rem_a10 <= 32'd0;
            temp_rem_a01 <= 32'd0;
            temp_rem_a10 <= 32'd0;
            n0_val <= 32'd0;
            n1_val <= 32'd0;
            test_val <= 32'd0;
            calc_result <= 32'd0;
            cycle_count <= 32'd0;
            max_cycles <= 32'd5000;
            trig_state <= TRIG_IDLE;
            trig_i <= 32'd0;
            trig_target <= 32'd0;
            found_n0 <= 1'b0;
            found_n1 <= 1'b0;
            searching_n0 <= 1'b0;
            searching_n1 <= 1'b0;
        end
    end

    // Triangular number calculation: result = x*(x-1)/2
    // Uses iterative addition to avoid 64-bit requirement
    // Computes: 0 + 1 + 2 + ... + (x-1) = x*(x-1)/2
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            trig_state <= TRIG_IDLE;
            trig_i <= 32'd0;
            calc_result <= 32'd0;
        end else begin
            case (trig_state)
                TRIG_IDLE: begin
                    trig_i <= 32'd1;
                    calc_result <= 32'd0;
                    if (searching_n0 || searching_n1) begin
                        trig_state <= TRIG_CALC;
                    end
                end
                TRIG_CALC: begin
                    if (trig_i < trig_target) begin
                        calc_result <= calc_result + trig_i;
                        trig_i <= trig_i + 32'd1;
                    end else begin
                        trig_state <= TRIG_DONE;
                    end
                end
                TRIG_DONE: begin
                    if (!searching_n0 && !searching_n1) begin
                        trig_state <= TRIG_IDLE;
                    end
                end
                default: trig_state <= TRIG_IDLE;
            endcase
        end
    end

    // Main state machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end

    always @(*) begin
        next_state = state;
        
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = CHECK;
                end
            end
            
            CHECK: begin
                // Start searching for n0
                next_state = FIND_N0;
            end
            
            FIND_N0: begin
                if (found_n0) begin
                    next_state = FIND_N1;
                end else if (cycle_count >= max_cycles) begin
                    next_state = DONE_STATE;
                end
            end
            
            FIND_N1: begin
                if (found_n1) begin
                    next_state = VALIDATE;
                end else if (cycle_count >= max_cycles) begin
                    next_state = DONE_STATE;
                end
            end
            
            VALIDATE: begin
                if (is_impossible) begin
                    next_state = DONE_STATE;
                end else begin
                    next_state = OUTPUT_CHAR;
                end
            end
            
            OUTPUT_CHAR: begin
                if (rem_n0 == 11'd0 && rem_n1 == 11'd0) begin
                    next_state = DONE_STATE;
                end
            end
            
            DONE_STATE: begin
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            done <= 1'b0;
            valid <= 1'b0;
            result_char <= 8'd0;
            is_impossible <= 1'b0;
            n0 <= 11'd0;
            n1 <= 11'd0;
            rem_n0 <= 11'd0;
            rem_n1 <= 11'd0;
            rem_a01 <= 32'd0;
            rem_a10 <= 32'd0;
            temp_rem_a01 <= 32'd0;
            temp_rem_a10 <= 32'd0;
            n0_val <= 32'd0;
            n1_val <= 32'd0;
            test_val <= 32'd0;
            cycle_count <= 32'd0;
            found_n0 <= 1'b0;
            found_n1 <= 1'b0;
            searching_n0 <= 1'b0;
            searching_n1 <= 1'b0;
            trig_target <= 32'd0;
        end else begin
            done <= 1'b0;
            valid <= 1'b0;
            
            case (state)
                IDLE: begin
                    // Clear all on idle
                    found_n0 <= 1'b0;
                    found_n1 <= 1'b0;
                    searching_n0 <= 1'b0;
                    searching_n1 <= 1'b0;
                    is_impossible <= 1'b0;
                    cycle_count <= 32'd0;
                end
                
                CHECK: begin
                    cycle_count <= 32'd0;
                    // Start searching for n0
                    searching_n0 <= 1'b1;
                    searching_n1 <= 1'b0;
                    n0_val <= 32'd0;
                    found_n0 <= 1'b0;
                    trig_target <= 32'd0;
                    // Special case: if a00=0, n0 can be 0 or 1
                    // We'll start searching from 0
                end
                
                FIND_N0: begin
                    cycle_count <= cycle_count + 32'd1;
                    
                    if (trig_state == TRIG_DONE && !found_n0) begin
                        // Check if calc_result matches a00
                        if (calc_result == a00) begin
                            found_n0 <= 1'b1;
                            n0 <= n0_val[10:0]; // Convert to 11-bit
                            searching_n0 <= 1'b0;
                        end else begin
                            // Continue searching
                            if (n0_val < 32'd1024) begin
                                n0_val <= n0_val + 32'd1;
                                trig_target <= n0_val + 32'd1;
                            end else begin
                                // Exhausted search
                                is_impossible <= 1'b1;
                                found_n0 <= 1'b1; // Stop searching
                                searching_n0 <= 1'b0;
                            end
                        end
                    end else if (trig_state == TRIG_IDLE && searching_n0) begin
                        // Start calculation for current n0_val
                        trig_target <= n0_val + 32'd1;
                    end
                end
                
                FIND_N1: begin
                    cycle_count <= cycle_count + 32'd1;
                    
                    if (trig_state == TRIG_DONE && !found_n1 && found_n0 && !is_impossible) begin
                        // Check if calc_result matches a11
                        if (calc_result == a11) begin
                            // Also need to check n0*n1 == a01 + a10
                            if (n0_val[10:0] * n1_val[10:0] == (a01 + a10)) begin
                                found_n1 <= 1'b1;
                                n1 <= n1_val[10:0];
                                searching_n1 <= 1'b0;
                            end else begin
                                // Continue searching for next n1
                                if (n1_val < 32'd1024) begin
                                    n1_val <= n1_val + 32'd1;
                                    trig_target <= n1_val + 32'd1;
                                end else begin
                                    is_impossible <= 1'b1;
                                    found_n1 <= 1'b1;
                                    searching_n1 <= 1'b0;
                                end
                            end
                        end else begin
                            // Continue searching
                            if (n1_val < 32'd1024) begin
                                n1_val <= n1_val + 32'd1;
                                trig_target <= n1_val + 32'd1;
                            end else begin
                                is_impossible <= 1'b1;
                                found_n1 <= 1'b1;
                                searching_n1 <= 1'b0;
                            end
                        end
                    end else if (trig_state == TRIG_IDLE && found_n0 && !is_impossible) begin
                        // Start searching for n1
                        searching_n1 <= 1'b1;
                        searching_n0 <= 1'b0;
                        n1_val <= 32'd0;
                        found_n1 <= 1'b0;
                    end else if (trig_state == TRIG_DONE && !found_n1 && !is_impossible) begin
                        // Ready for next n1 value
                        if (n1_val < 32'd1024) begin
                            n1_val <= n1_val + 32'd1;
                            trig_target <= n1_val + 32'd1;
                        end else begin
                            is_impossible <= 1'b1;
                            found_n1 <= 1'b1;
                            searching_n1 <= 1'b0;
                        end
                    end
                end
                
                VALIDATE: begin
                    // Initialize output registers
                    if (!is_impossible) begin
                        rem_n0 <= n0;
                        rem_n1 <= n1;
                        rem_a01 <= a01;
                        rem_a10 <= a10;
                        temp_rem_a01 <= a01;
                        temp_rem_a10 <= a10;
                    end
                end
                
                OUTPUT_CHAR: begin
                    if (rem_n0 > 0) begin
                        // Check if we can output '0'
                        // Need rem_a01 >= rem_n1 (remaining 1s)
                        if (rem_a01 >= rem_n1) begin
                            result_char <= 8'd48; // '0'
                            valid <= 1'b1;
                            rem_n0 <= rem_n0 - 11'd1;
                            rem_a01 <= rem_a01 - rem_n1;
                            temp_rem_a01 <= rem_a01 - rem_n1;
                        end else begin
                            // Output '1'
                            result_char <= 8'd49; // '1'
                            valid <= 1'b1;
                            rem_n1 <= rem_n1 - 11'd1;
                            rem_a10 <= rem_a10 - rem_n0;
                            temp_rem_a10 <= rem_a10 - rem_n0;
                        end
                    end else if (rem_n1 > 0) begin
                        // Output remaining '1's
                        result_char <= 8'd49; // '1'
                        valid <= 1'b1;
                        rem_n1 <= rem_n1 - 11'd1;
                    end
                end
                
                DONE_STATE: begin
                    done <= 1'b1;
                end
            endcase
        end
    end

endmodule