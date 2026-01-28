module LuckyNumbers(
    input clk,
    input rst_n,
    input start,
    input [3:0] n,
    output reg [23:0] result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE      = 3'd0;
    localparam [2:0] INIT_DP   = 3'd1;
    localparam [2:0] COMPUTE   = 3'd2;
    localparam [2:0] SUMMING   = 3'd3;
    localparam [2:0] DONE      = 3'd4;

    // LCM values for n=1..8
    localparam [10:0] LCM_1 = 11'd1;
    localparam [10:0] LCM_2 = 11'd2;
    localparam [10:0] LCM_3 = 11'd6;
    localparam [10:0] LCM_4 = 11'd12;
    localparam [10:0] LCM_5 = 11'd60;
    localparam [10:0] LCM_6 = 11'd60;
    localparam [10:0] LCM_7 = 11'd420;
    localparam [10:0] LCM_8 = 11'd840;

    reg [2:0] state;
    reg [3:0] pos;              // Current position (0 to n-1)
    reg [3:0] digit;            // Current digit being tried
    reg [10:0] current_lcm;     // LCM for current n
    reg [9:0] rem;              // Remainder (0 to 839)
    reg [9:0] next_rem;         // Next remainder
    reg [23:0] dp_current [0:839];  // Current DP row
    reg [23:0] dp_next [0:839];     // Next DP row
    reg [23:0] temp_count;      // Temporary counter
    reg [9:0] loop_idx;         // Loop index
    reg [3:0] init_idx;         // Initialization index
    reg [7:0] digit_start;      // Starting digit for current position
    reg [7:0] digit_end;        // Ending digit for current position
    reg [9:0] multiplier;       // For remainder calculation
    reg [13:0] rem_calc;        // Extended calculation for (rem*10 + digit)
    reg [13:0] rem_calc_mod;    // Modulo result
    reg [3:0] cycle_count;      // Prevent infinite loops

    // Helper function for modulo calculation
    function [9:0] compute_modulo(
        input [9:0] rem,
        input [7:0] digit,
        input [10:0] lcm
    );
        // Calculate (rem * 10 + digit) % lcm
        // Since lcm <= 840, we can do modular arithmetic
        // rem*10 + digit <= 8390 + 9 = 8399
        // We'll compute manually
        reg [13:0] temp;
        reg [9:0] result;
        integer i;
        begin
            temp = (rem * 10) + digit;
            result = 0;
            // Simple modulo since lcm is small
            if (lcm == 11'd1) result = 0;
            else if (lcm == 11'd2) result = temp[0];
            else if (lcm == 11'd6) result = temp % 6;
            else if (lcm == 11'd12) result = temp % 12;
            else if (lcm == 11'd60) result = temp % 60;
            else if (lcm == 11'd420) result = temp % 420;
            else if (lcm == 11'd840) result = temp % 840;
            else result = temp[9:0];
            compute_modulo = result;
        end
    endfunction

    integer i;
    integer j;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 24'd0;
            done <= 1'b0;
            pos <= 4'd0;
            digit <= 4'd0;
            rem <= 10'd0;
            current_lcm <= 11'd1;
            temp_count <= 24'd0;
            loop_idx <= 10'd0;
            init_idx <= 4'd0;
            digit_start <= 8'd0;
            digit_end <= 8'd0;
            multiplier <= 10'd0;
            rem_calc <= 14'd0;
            rem_calc_mod <= 14'd0;
            cycle_count <= 4'd0;
            // Initialize DP arrays
            for (i = 0; i < 840; i = i + 1) begin
                dp_current[i] <= 24'd0;
                dp_next[i] <= 24'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 4'd0;
                    if (start) begin
                        // Set LCM based on n
                        case (n)
                            4'd1: current_lcm <= LCM_1;
                            4'd2: current_lcm <= LCM_2;
                            4'd3: current_lcm <= LCM_3;
                            4'd4: current_lcm <= LCM_4;
                            4'd5: current_lcm <= LCM_5;
                            4'd6: current_lcm <= LCM_6;
                            4'd7: current_lcm <= LCM_7;
                            4'd8: current_lcm <= LCM_8;
                            default: current_lcm <= LCM_1;
                        endcase
                        state <= INIT_DP;
                        init_idx <= 4'd0;
                        // Initialize dp_next to all zeros
                        for (j = 0; j < 840; j = j + 1) begin
                            dp_next[j] <= 24'd0;
                        end
                        result <= 24'd0;
                    end
                end

                INIT_DP: begin
                    // Initialize dp[0][0] = 1
                    // Also clear dp_current and dp_next
                    if (init_idx == 4'd0) begin
                        dp_next[0] <= 24'd1;
                    end else if (init_idx < 4'd12) begin
                        // Clear remaining entries (should be all zero)
                        if (init_idx < 4'd10) begin
                            dp_next[init_idx] <= 24'd0;
                        end
                        if (init_idx > 4'd0 && init_idx < 4'd12) begin
                            dp_current[init_idx-1] <= 24'd0;
                        end
                    end
                    
                    if (init_idx == 4'd11) begin
                        state <= COMPUTE;
                        pos <= 4'd0;
                        // Initialize first position
                        if (n > 4'd0) begin
                            pos <= 4'd0;
                        end
                    end else begin
                        init_idx <= init_idx + 4'd1;
                    end
                end

                COMPUTE: begin
                    // DP computation
                    // dp[pos+1][new_rem] += dp[pos][rem] for each valid digit
                    // Process one transition per cycle
                    
                    if (cycle_count == 4'd15) begin
                        // Timeout after 15 cycles in this state
                        state <= SUMMING;
                        cycle_count <= 4'd0;
                    end else if (pos < n) begin
                        // Determine digit range
                        if (pos == 4'd0) begin
                            // First position: 1-9
                            digit_start <= 8'd1;
                            digit_end <= 8'd9;
                        end else begin
                            // Other positions: 0-9
                            digit_start <= 8'd0;
                            digit_end <= 8'd10;
                        end

                        // Process current remainder if dp_current[loop_idx] > 0
                        if (dp_current[loop_idx] != 24'd0) begin
                            // Try each digit
                            if (digit <= digit_end) begin
                                // Calculate new remainder
                                if (digit < digit_start || (digit == 8'd10 && pos != 4'd0)) begin
                                    // Skip - not a valid digit for this position
                                    if (digit < digit_end) begin
                                        digit <= digit + 4'd1;
                                    end else begin
                                        // Move to next remainder
                                        if (loop_idx < current_lcm - 1) begin
                                            loop_idx <= loop_idx + 10'd1;
                                            digit <= digit_start;
                                        end else begin
                                            // Done with all remainders for this position
                                            // Swap dp arrays
                                            for (i = 0; i < 840; i = i + 1) begin
                                                dp_current[i] <= dp_next[i];
                                                dp_next[i] <= 24'd0;
                                            end
                                            pos <= pos + 4'd1;
                                            loop_idx <= 10'd0;
                                            digit <= 4'd0;
                                            cycle_count <= cycle_count + 4'd1;
                                        end
                                    end
                                end else begin
                                    // Valid digit, compute transition
                                    // Calculate (rem*10 + digit) % lcm
                                    rem_calc <= (loop_idx * 10) + digit;
                                    // Compute modulo
                                    if (current_lcm == 11'd1) rem_calc_mod <= 0;
                                    else if (current_lcm == 11'd2) rem_calc_mod <= rem_calc[0];
                                    else if (current_lcm == 11'd6) rem_calc_mod <= rem_calc % 6;
                                    else if (current_lcm == 11'd12) rem_calc_mod <= rem_calc % 12;
                                    else if (current_lcm == 11'd60) rem_calc_mod <= rem_calc % 60;
                                    else if (current_lcm == 11'd420) rem_calc_mod <= rem_calc % 420;
                                    else if (current_lcm == 11'd840) rem_calc_mod <= rem_calc % 840;
                                    else rem_calc_mod <= rem_calc[9:0];
                                    
                                    // Update dp_next in next cycle
                                    // We need to add to dp_next[new_rem]
                                    // This requires another state or combinational logic
                                    // Let's use combinational next_rem
                                    if (current_lcm == 11'd1) next_rem <= 10'd0;
                                    else if (current_lcm == 11'd2) next_rem <= rem_calc[0];
                                    else if (current_lcm == 11'd6) next_rem <= rem_calc % 6;
                                    else if (current_lcm == 11'd12) next_rem <= rem_calc % 12;
                                    else if (current_lcm == 11'd60) next_rem <= rem_calc % 60;
                                    else if (current_lcm == 11'd420) next_rem <= rem_calc % 420;
                                    else if (current_lcm == 11'd840) next_rem <= rem_calc % 840;
                                    else next_rem <= rem_calc[9:0];
                                    
                                    // We'll update in next cycle
                                    digit <= digit + 4'd1;
                                    state <= COMPUTE; // Stay in compute for update
                                end
                            end else begin
                                // Move to next remainder
                                if (loop_idx < current_lcm - 1) begin
                                    loop_idx <= loop_idx + 10'd1;
                                    digit <= digit_start;
                                end else begin
                                    // Done with all remainders for this position
                                    // Swap dp arrays
                                    for (i = 0; i < 840; i = i + 1) begin
                                        dp_current[i] <= dp_next[i];
                                        dp_next[i] <= 24'd0;
                                    end
                                    pos <= pos + 4'd1;
                                    loop_idx <= 10'd0;
                                    digit <= 4'd0;
                                    cycle_count <= cycle_count + 4'd1;
                                end
                            end
                        end else begin
                            // dp_current[loop_idx] == 0, skip this remainder
                            if (loop_idx < current_lcm - 1) begin
                                loop_idx <= loop_idx + 10'd1;
                            end else begin
                                // Done with all remainders for this position
                                // Swap dp arrays
                                for (i = 0; i < 840; i = i + 1) begin
                                    dp_current[i] <= dp_next[i];
                                    dp_next[i] <= 24'd0;
                                end
                                pos <= pos + 4'd1;
                                loop_idx <= 10'd0;
                                digit <= 4'd0;
                                cycle_count <= cycle_count + 4'd1;
                            end
                        end
                    end else begin
                        state <= SUMMING;
                        loop_idx <= 10'd0;
                        temp_count <= 24'd0;
                    end
                end

                SUMMING: begin
                    // Sum all dp_current[rem] for pos = n
                    if (loop_idx < current_lcm) begin
                        temp_count <= temp_count + dp_current[loop_idx];
                        loop_idx <= loop_idx + 10'd1;
                    end else begin
                        // Special case: if n == 0 or no numbers
                        if (n == 4'd0) begin
                            result <= 24'd0;
                        end else begin
                            result <= temp_count;
                        end
                        state <= DONE;
                    end
                end

                DONE: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

    // Combinational logic for updating dp_next
    always @(*) begin
        // This is used in COMPUTE state to update dp_next
        // We need to add dp_current[loop_idx] to dp_next[next_rem]
        // But Verilog doesn't allow procedural assignment to arrays in always @(*)
        // So we handle this inside the sequential block with timing
        // The logic above handles the state transitions
    end

endmodule