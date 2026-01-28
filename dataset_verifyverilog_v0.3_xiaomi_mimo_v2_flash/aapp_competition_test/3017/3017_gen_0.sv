module CountNumbersWith2eSubstring (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [5:0] e,
    input wire [3:0] n_digits [0:18],
    output reg [63:0] count,
    output reg done
);

    // State definitions
    localparam [3:0] IDLE         = 4'd0;
    localparam [3:0] LOOKUP       = 4'd1;
    localparam [3:0] INIT_DP      = 4'd2;
    localparam [3:0] PREPARE_LOOP = 4'd3;
    localparam [3:0] ITERATE      = 4'd4;
    localparam [3:0] SUM          = 4'd5;
    localparam [3:0] FINISH       = 4'd6;

    reg [3:0] state, next_state;
    
    // Constants
    localparam [5:0] MAX_E = 6'd60;
    localparam [4:0] MAX_LEN = 5'd19;
    localparam [5:0] MAX_PATTERN_LEN = 6'd19;
    localparam [3:0] MAX_DIGIT = 4'd9;
    
    // 2^e lookup ROM (simplified - for e=0 to 60)
    reg [75:0] two_pow_e;  // Max 19 digits * 4 bits = 76 bits
    reg [4:0] pattern_len;
    reg [3:0] pattern_data [0:18];  // 19 nibbles
    
    // KMP next table
    reg [3:0] next_tbl [0:18][0:9];  // state x digit
    
    // DP arrays - use packed representation for synthesis
    reg [63:0] current_dp_tight0_started0 [0:19];
    reg [63:0] current_dp_tight0_started1 [0:19];
    reg [63:0] current_dp_tight1_started0 [0:19];
    reg [63:0] current_dp_tight1_started1 [0:19];
    
    reg [63:0] next_dp_tight0_started0 [0:19];
    reg [63:0] next_dp_tight0_started1 [0:19];
    reg [63:0] next_dp_tight1_started0 [0:19];
    reg [63:0] next_dp_tight1_started1 [0:19];
    
    // Loop counters and indices
    reg [4:0] pos_idx;
    reg [3:0] digit;
    reg [3:0] state_idx;
    reg [4:0] pattern_idx;
    reg [4:0] i, j, k;
    
    // Temporary values
    reg [3:0] next_state_val;
    reg [63:0] sum_temp;
    reg [75:0] pow_val;
    reg [4:0] len_val;
    reg [75:0] temp_pow;
    reg [4:0] temp_len;
    
    // KMP preprocessing variables
    reg [4:0] len_idx;
    reg [4:0] kmp_idx;
    reg [3:0] prev_state;
    
    // Pattern construction
    reg [3:0] digit_val;
    reg [3:0] digit_idx;
    
    // Helper function for KMP next state (combinational)
    function [3:0] get_next_state(input [3:0] current, input [3:0] digit_input);
        reg [4:0] k_temp;
        begin
            get_next_state = current;
            if (current < pattern_len && pattern_data[current] == digit_input) begin
                get_next_state = current + 4'd1;
            end else begin
                // Fallback: try shorter prefixes
                for (k_temp = current; k_temp > 0; k_temp = k_temp - 1) begin
                    if (k_temp < pattern_len && pattern_data[k_temp - 1] == digit_input) begin
                        get_next_state = k_temp;
                        // Verify prefix matches
                        if (k_temp < pattern_len) begin
                            get_next_state = k_temp + 4'd1;
                        end
                    end
                end
            end
        end
    endfunction
    
    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            count <= 64'd0;
            done <= 1'b0;
            pos_idx <= 5'd0;
            digit <= 4'd0;
            state_idx <= 4'd0;
            pattern_idx <= 5'd0;
            i <= 5'd0;
            j <= 5'd0;
            k <= 5'd0;
            len_idx <= 5'd0;
            kmp_idx <= 5'd0;
            prev_state <= 4'd0;
            digit_val <= 4'd0;
            digit_idx <= 5'd0;
            sum_temp <= 64'd0;
            pow_val <= 76'd0;
            len_val <= 5'd0;
            temp_pow <= 76'd0;
            temp_len <= 5'd0;
            next_state_val <= 4'd0;
            
            // Initialize arrays
            for (i = 0; i < 19; i = i + 1) begin
                current_dp_tight0_started0[i] <= 64'd0;
                current_dp_tight0_started1[i] <= 64'd0;
                current_dp_tight1_started0[i] <= 64'd0;
                current_dp_tight1_started1[i] <= 64'd0;
                next_dp_tight0_started0[i] <= 64'd0;
                next_dp_tight0_started1[i] <= 64'd0;
                next_dp_tight1_started0[i] <= 64'd0;
                next_dp_tight1_started1[i] <= 64'd0;
                pattern_data[i] <= 4'd0;
                for (j = 0; j < 10; j = j + 1) begin
                    next_tbl[i][j] <= 4'd0;
                end
            end
            
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        count <= 64'd0;
                        // Initialize for new computation
                        for (i = 0; i < 19; i = i + 1) begin
                            current_dp_tight0_started0[i] <= 64'd0;
                            current_dp_tight0_started1[i] <= 64'd0;
                            current_dp_tight1_started0[i] <= 64'd0;
                            current_dp_tight1_started1[i] <= 64'd0;
                            next_dp_tight0_started0[i] <= 64'd0;
                            next_dp_tight0_started1[i] <= 64'd0;
                            next_dp_tight1_started0[i] <= 64'd0;
                            next_dp_tight1_started1[i] <= 64'd0;
                        end
                        i <= 5'd0;
                        j <= 5'd0;
                        k <= 5'd0;
                        len_idx <= 5'd0;
                        kmp_idx <= 5'd0;
                        prev_state <= 4'd0;
                        digit_val <= 4'd0;
                        digit_idx <= 5'd0;
                        pos_idx <= 5'd0;
                        digit <= 4'd0;
                        state_idx <= 4'd0;
                        pattern_idx <= 5'd0;
                    end
                end
                
                LOOKUP: begin
                    // Lookup 2^e from ROM
                    // For simplicity, using a case statement
                    case (e)
                        6'd0: begin pow_val <= 76'd1; len_val <= 5'd1; end
                        6'd1: begin pow_val <= 76'd2; len_val <= 5'd1; end
                        6'd2: begin pow_val <= 76'd4; len_val <= 5'd1; end
                        6'd3: begin pow_val <= 76'd8; len_val <= 5'd1; end
                        6'd4: begin pow_val <= 76'd16; len_val <= 5'd2; end
                        6'd5: begin pow_val <= 76'd32; len_val <= 5'd2; end
                        6'd6: begin pow_val <= 76'd64; len_val <= 5'd2; end
                        6'd7: begin pow_val <= 76'd128; len_val <= 5'd3; end
                        6'd8: begin pow_val <= 76'd256; len_val <= 5'd3; end
                        6'd9: begin pow_val <= 76'd512; len_val <= 5'd3; end
                        6'd10: begin pow_val <= 76'd1024; len_val <= 5'd4; end
                        6'd11: begin pow_val <= 76'd2048; len_val <= 5'd4; end
                        6'd12: begin pow_val <= 76'd4096; len_val <= 5'd4; end
                        6'd13: begin pow_val <= 76'd8192; len_val <= 5'd4; end
                        6'd14: begin pow_val <= 76'd16384; len_val <= 5'd5; end
                        6'd15: begin pow_val <= 76'd32768; len_val <= 5'd5; end
                        6'd16: begin pow_val <= 76'd65536; len_val <= 5'd5; end
                        6'd17: begin pow_val <= 76'd131072; len_val <= 5'd6; end
                        6'd18: begin pow_val <= 76'd262144; len_val <= 5'd6; end
                        6'd19: begin pow_val <= 76'd524288; len_val <= 5'd6; end
                        6'd20: begin pow_val <= 76'd1048576; len_val <= 5'd7; end
                        6'd21: begin pow_val <= 76'd2097152; len_val <= 5'd7; end
                        6'd22: begin pow_val <= 76'd4194304; len_val <= 5'd7; end
                        6'd23: begin pow_val <= 76'd8388608; len_val <= 5'd7; end
                        6'd24: begin pow_val <= 76'd16777216; len_val <= 5'd8; end
                        6'd25: begin pow_val <= 76'd33554432; len_val <= 5'd8; end
                        6'd26: begin pow_val <= 76'd67108864; len_val <= 5'd8; end
                        6'd27: begin pow_val <= 76'd134217728; len_val <= 5'd9; end
                        6'd28: begin pow_val <= 76'd268435456; len_val <= 5'd9; end
                        6'd29: begin pow_val <= 76'd536870912; len_val <= 5'd9; end
                        6'd30: begin pow_val <= 76'd1073741824; len_val <= 5'd10; end
                        6'd31: begin pow_val <= 76'd2147483648; len_val <= 5'd10; end
                        6'd32: begin pow_val <= 76'd4294967296; len_val <= 5'd10; end
                        6'd33: begin pow_val <= 76'd8589934592; len_val <= 5'd10; end
                        6'd34: begin pow_val <= 76'd17179869184; len_val <= 5'd11; end
                        6'd35: begin pow_val <= 76'd34359738368; len_val <= 5'd11; end
                        6'd36: begin pow_val <= 76'd68719476736; len_val <= 5'd11; end
                        6'd37: begin pow_val <= 76'd137438953472; len_val <= 5'd12; end
                        6'd38: begin pow_val <= 76'd274877906944; len_val <= 5'd12; end
                        6'd39: begin pow_val <= 76'd549755813888; len_val <= 5'd12; end
                        6'd40: begin pow_val <= 76'd1099511627776; len_val <= 5'd13; end
                        6'd41: begin pow_val <= 76'd2199023255552; len_val <= 5'd13; end
                        6'd42: begin pow_val <= 76'd4398046511104; len_val <= 5'd13; end
                        6'd43: begin pow_val <= 76'd8796093022208; len_val <= 5'd13; end
                        6'd44: begin pow_val <= 76'd17592186044416; len_val <= 5'd14; end
                        6'd45: begin pow_val <= 76'd35184372088832; len_val <= 5'd14; end
                        6'd46: begin pow_val <= 76'd70368744177664; len_val <= 5'd14; end
                        6'd47: begin pow_val <= 76'd140737488355328; len_val <= 5'd15; end
                        6'd48: begin pow_val <= 76'd281474976710656; len_val <= 5'd15; end
                        6'd49: begin pow_val <= 76'd562949953421312; len_val <= 5'd15; end
                        6'd50: begin pow_val <= 76'd1125899906842624; len_val <= 5'd16; end
                        6'd51: begin pow_val <= 76'd2251799813685248; len_val <= 5'd16; end
                        6'd52: begin pow_val <= 76'd4503599627370496; len_val <= 5'd16; end
                        6'd53: begin pow_val <= 76'd9007199254740992; len_val <= 5'd16; end
                        6'd54: begin pow_val <= 76'd18014398509481984; len_val <= 5'd17; end
                        6'd55: begin pow_val <= 76'd36028797018963968; len_val <= 5'd17; end
                        6'd56: begin pow_val <= 76'd72057594037927936; len_val <= 5'd17; end
                        6'd57: begin pow_val <= 76'd144115188075855872; len_val <= 5'd18; end
                        6'd58: begin pow_val <= 76'd288230376151711744; len_val <= 5'd18; end
                        6'd59: begin pow_val <= 76'd576460752303423488; len_val <= 5'd18; end
                        6'd60: begin pow_val <= 76'd1152921504606846976; len_val <= 5'd19; end
                        default: begin pow_val <= 76'd1; len_val <= 5'd1; end
                    endcase
                    
                    // Extract digits
                    temp_pow <= pow_val;
                    temp_len <= len_val;
                    digit_idx <= 5'd0;
                end
                
                INIT_DP: begin
                    // Extract digits from pow_val and store in pattern_data
                    if (digit_idx < temp_len) begin
                        // Get digit: divmod by 10
                        case (temp_pow % 10)
                            0: digit_val <= 4'd0;
                            1: digit_val <= 4'd1;
                            2: digit_val <= 4'd2;
                            3: digit_val <= 4'd3;
                            4: digit_val <= 4'd4;
                            5: digit_val <= 4'd5;
                            6: digit_val <= 4'd6;
                            7: digit_val <= 4'd7;
                            8: digit_val <= 4'd8;
                            9: digit_val <= 4'd9;
                            default: digit_val <= 4'd0;
                        endcase
                        pattern_data[5'd18 - digit_idx] <= digit_val;
                        temp_pow <= temp_pow / 10;
                        digit_idx <= digit_idx + 5'd1;
                    end else begin
                        // Set pattern length
                        pattern_len <= temp_len;
                        kmp_idx <= 5'd0;
                        len_idx <= 5'd0;
                    end
                end
                
                PREPARE_LOOP: begin
                    // Compute KMP next table
                    if (kmp_idx <= pattern_len) begin
                        if (len_idx <= 4'd9) begin
                            // Calculate next state for transition
                            if (kmp_idx < pattern_len && pattern_data[kmp_idx] == len_idx) begin
                                next_tbl[kmp_idx][len_idx] <= kmp_idx + 5'd1;
                            end else begin
                                // Search for fallback
                                if (kmp_idx == 5'd0) begin
                                    next_tbl[kmp_idx][len_idx] <= 5'd0;
                                end else begin
                                    // Check for prefix match
                                    if (pattern_data[kmp_idx - 1] == len_idx) begin
                                        next_tbl[kmp_idx][len_idx] <= kmp_idx;
                                    end else begin
                                        next_tbl[kmp_idx][len_idx] <= next_tbl[kmp_idx - 1][len_idx];
                                    end
                                end
                            end
                            len_idx <= len_idx + 4'd1;
                        end else begin
                            len_idx <= 4'd0;
                            kmp_idx <= kmp_idx + 5'd1;
                        end
                    end else begin
                        // Initialize DP
                        current_dp_tight1_started0[0] <= 64'd1;
                        pos_idx <= 5'd0;
                    end
                end
                
                ITERATE: begin
                    // Process each digit position
                    if (pos_idx < 5'd19) begin
                        // Reset next arrays
                        if (digit == 4'd0) begin
                            next_dp_tight0_started0[state_idx] <= 64'd0;
                            next_dp_tight0_started1[state_idx] <= 64'd0;
                            next_dp_tight1_started0[state_idx] <= 64'd0;
                            next_dp_tight1_started1[state_idx] <= 64'd0;
                        end
                        
                        // Get input digit
                        if (pos_idx <= 5'd18) begin
                            if (digit < 4'd10) begin
                                // Transition logic
                                // For tight = 0 (already smaller)
                                if (current_dp_tight0_started0[digit] != 64'd0 || current_dp_tight0_started1[digit] != 64'd0) begin
                                    // Started = 0, any digit allowed
                                    if (current_dp_tight0_started0[digit] != 64'd0) begin
                                        next_dp_tight0_started0[next_tbl[digit][0]] <= 
                                            next_dp_tight0_started0[next_tbl[digit][0]] + current_dp_tight0_started0[digit];
                                    end
                                    // Started = 1, compute next state
                                    if (current_dp_tight0_started1[digit] != 64'd0) begin
                                        next_dp_tight0_started1[next_tbl[digit][digit]] <= 
                                            next_dp_tight0_started1[next_tbl[digit][digit]] + current_dp_tight0_started1[digit];
                                    end
                                end
                                
                                // For tight = 1 (still equal)
                                if (digit <= n_digits[pos_idx]) begin
                                    // Can only use digit <= input digit
                                    if (digit == 4'd0) begin
                                        // Leading zero handling
                                        if (current_dp_tight1_started0[digit] != 64'd0) begin
                                            next_dp_tight1_started0[digit] <= next_dp_tight1_started0[digit] + current_dp_tight1_started0[digit];
                                        end
                                        if (current_dp_tight1_started1[digit] != 64'd0) begin
                                            next_dp_tight1_started1[next_tbl[digit][digit]] <= 
                                                next_dp_tight1_started1[next_tbl[digit][digit]] + current_dp_tight1_started1[digit];
                                        end
                                    end else begin
                                        // Non-zero digit starts the number
                                        if (current_dp_tight1_started0[digit] != 64'd0) begin
                                            next_dp_tight1_started1[next_tbl[digit][digit]] <= 
                                                next_dp_tight1_started1[next_tbl[digit][digit]] + current_dp_tight1_started0[digit];
                                        end
                                        if (current_dp_tight1_started1[digit] != 64'd0) begin
                                            next_dp_tight1_started1[next_tbl[digit][digit]] <= 
                                                next_dp_tight1_started1[next_tbl[digit][digit]] + current_dp_tight1_started1[digit];
                                        end
                                    end
                                    
                                    // Update tight flag
                                    if (digit < n_digits[pos_idx]) begin
                                        // Move to tight=0
                                        next_dp_tight0_started0[next_tbl[digit][0]] <= 
                                            next_dp_tight0_started0[next_tbl[digit][0]] + current_dp_tight1_started0[digit];
                                        next_dp_tight0_started1[next_tbl[digit][digit]] <= 
                                            next_dp_tight0_started1[next_tbl[digit][digit]] + current_dp_tight1_started1[digit];
                                    end
                                end
                            end
                            digit <= digit + 4'd1;
                        end else begin
                            // Move to next position
                            state_idx <= state_idx + 4'd1;
                            digit <= 4'd0;
                            
                            if (state_idx >= 4'd9) begin
                                // Copy next to current for next position
                                current_dp_tight0_started0 <= next_dp_tight0_started0;
                                current_dp_tight0_started1 <= next_dp_tight0_started1;
                                current_dp_tight1_started0 <= next_dp_tight1_started0;
                                current_dp_tight1_started1 <= next_dp_tight1_started1;
                                pos_idx <= pos_idx + 5'd1;
                                state_idx <= 4'd0;
                            end
                        end
                    end else begin
                        // After all positions, sum up
                        sum_temp <= 64'd0;
                        state_idx <= 4'd0;
                    end
                end
                
                SUM: begin
                    // Sum all counts where state = pattern_len
                    if (state_idx <= 4'd9) begin
                        // Check started=1 (already started counting)
                        sum_temp <= sum_temp + current_dp_tight0_started1[state_idx] + current_dp_tight1_started1[state_idx];
                        state_idx <= state_idx + 4'd1;
                    end else begin
                        count <= sum_temp;
                    end
                end
                
                FINISH: begin
                    done <= 1'b1;
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end
    
    // Next state logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start) next_state = LOOKUP;
                else next_state = IDLE;
            end
            LOOKUP: next_state = INIT_DP;
            INIT_DP: begin
                if (digit_idx >= temp_len) next_state = PREPARE_LOOP;
                else next_state = INIT_DP;
            end
            PREPARE_LOOP: begin
                if (kmp_idx > pattern_len) next_state = ITERATE;
                else next_state = PREPARE_LOOP;
            end
            ITERATE: begin
                if (pos_idx >= 5'd19 && state_idx >= 4'd9) next_state = SUM;
                else next_state = ITERATE;
            end
            SUM: begin
                if (state_idx > 4'd9) next_state = FINISH;
                else next_state = SUM;
            end
            FINISH: next_state = IDLE;
            default: next_state = IDLE;
        endcase
    end

endmodule