module avg_operations(
    input clk,
    input rst_n,
    input start,
    input [7:0] char_mask,
    input [7:0] head_mask,
    output reg [31:0] result_num,
    output reg [31:0] result_den,
    output reg done
);

    // States
    localparam IDLE = 3'd0;
    localparam GENERATE_CONFIGS = 3'd1;
    localparam CALCULATE_LENGTH = 3'd2;
    localparam ACCUMULATE = 3'd3;
    localparam DIVIDE = 3'd4;

    reg [2:0] state;
    
    // Combinational logic for state transition and next values
    reg [2:0] next_state;
    reg [31:0] next_result_num;
    reg [31:0] next_result_den;
    reg next_done;
    
    // Internal registers
    reg [7:0] config_current;
    reg [7:0] next_config_current;
    reg [7:0] working_bits;
    reg [7:0] next_working_bits;
    reg [31:0] total_sum;
    reg [31:0] next_total_sum;
    reg [31:0] length_count;
    reg [31:0] next_length_count;
    
    // Mask for unknown bits
    wire [7:0] unknown_mask;
    assign unknown_mask = char_mask & ~head_mask;
    
    // Count ones in working_bits
    function [3:0] count_ones;
        input [7:0] val;
        begin
            count_ones = 0;
            if (val[0]) count_ones = count_ones + 1;
            if (val[1]) count_ones = count_ones + 1;
            if (val[2]) count_ones = count_ones + 1;
            if (val[3]) count_ones = count_ones + 1;
            if (val[4]) count_ones = count_ones + 1;
            if (val[5]) count_ones = count_ones + 1;
            if (val[6]) count_ones = count_ones + 1;
            if (val[7]) count_ones = count_ones + 1;
        end
    endfunction

    wire [3:0] ones_count;
    assign ones_count = count_ones(working_bits);

    // Find k-th set bit (0-based index)
    function [7:0] find_kth_bit;
        input [7:0] val;
        input [3:0] k;
        integer i;
        integer count;
        begin
            count = 0;
            find_kth_bit = 8'h00;
            for (i = 7; i >= 0; i = i - 1) begin
                if (val[i]) begin
                    if (count == k) begin
                        find_kth_bit = 8'h01 << i;
                    end
                    count = count + 1;
                end
            end
        end
    endfunction

    wire [7:0] kth_bit_mask;
    assign kth_bit_mask = find_kth_bit(working_bits, ones_count - 1);

    // Generate next configuration for '?'
    function [7:0] next_config_gen;
        input [7:0] current;
        input [7:0] mask;
        reg [7:0] temp;
        begin
            // Simple increment, skip bits not in mask
            temp = current | (~mask); // Set fixed bits to 1 temporarily
            temp = temp + 1'b1;
            // Clear bits not in mask
            next_config_gen = temp & mask;
            // Handle overflow by checking if we wrapped past the mask
            // If (next_config_gen == 0 && temp != 0) means overflow? 
            // Actually, if mask is 0, we should just stay at 0 or handle separately.
            // Since mask has at least 1 bit for valid configs, this works.
        end
    endfunction

    // --- State Machine Logic ---
    always @(*) begin
        next_state = state;
        next_result_num = result_num;
        next_result_den = result_den;
        next_done = done;
        next_config_current = config_current;
        next_working_bits = working_bits;
        next_total_sum = total_sum;
        next_length_count = length_count;

        case (state)
            IDLE: begin
                if (start) begin
                    next_state = GENERATE_CONFIGS;
                    next_total_sum = 0;
                    next_result_num = 0;
                    next_result_den = 0;
                    next_done = 0;
                    // Initial config: just the known heads, unknowns 0
                    next_config_current = head_mask;
                    // If no unknowns, we might need to handle immediately
                    // But GENERATE_CONFIGS will check validity
                end
            end

            GENERATE_CONFIGS: begin
                // Check if current config is valid (within mask)
                // We iterate all 256 possibilities, but only process those that match char_mask
                // effectively: config_current bits must be subset of char_mask or equal to head_mask at least?
                // Actually, for unknown bits, they can be 0 or 1. Known heads are fixed 1. Known tails fixed 0.
                // So full config = (config_current & char_mask) | head_mask? 
                // Wait, config_current represents the *current guess* for unknown bits.
                // We iterate 0 to 255. If (current_guess & ~char_mask) != 0, it's invalid (trying to set a T bit).
                // Actually, the problem says char_mask is 1 for H or ?. So T is 0 in char_mask.
                // We need to generate numbers where bits are 0 or 1, but only if char_mask bit is 1.
                // If char_mask bit is 0, that bit is T, so must be 0.
                
                // Let's refine iteration:
                // We iterate through all values of 'unknown_mask' bits.
                // The 'config_current' will represent the bits to OR with head_mask.
                // Or simpler: state variable 'current_try' goes from 0 to 255.
                // If (current_try & ~char_mask) == 0, it's a valid assignment for the H/T/? string.
                
                if (config_current == 8'hFF && (unknown_mask != 0)) begin 
                     // Just finished last config
                     next_state = DIVIDE;
                end else if (unknown_mask == 0) begin
                    // No unknowns, just one config
                    next_state = CALCULATE_LENGTH;
                    next_working_bits = head_mask; // Only one config: the known heads
                end else begin
                    // Generate next
                    reg [7:0] next_try;
                    // We use config_current to store the current trial number (0..255)
                    next_try = config_current + 1'b1;
                    
                    // Check validity: (next_try & ~char_mask) must be 0
                    // Note: char_mask has 1 for H and ?, 0 for T.
                    // So ~char_mask is 1 for T. next_try must have 0 at T positions.
                    
                    if ((next_try & ~char_mask) == 0) begin
                        // Valid config found
                        next_state = CALCULATE_LENGTH;
                        next_config_current = next_try;
                        // Actual bits = (next_try & unknown_mask) | head_mask
                        next_working_bits = (next_try & unknown_mask) | head_mask;
                    end else begin
                        // Invalid, stay in GENERATE and try next
                        next_config_current = next_try;
                        if (next_try == 8'hFF) begin
                            // Reached end, go to divide
                            next_state = DIVIDE;
                        end else begin
                            next_state = GENERATE_CONFIGS;
                        end
                    end
                end
            end

            CALCULATE_LENGTH: begin
                // Simulation loop: count ones, if > 0, flip k-th, increment length
                if (ones_count == 0) begin
                    // Done with this config
                    next_state = ACCUMULATE;
                end else begin
                    // Flip k-th bit
                    next_working_bits = working_bits ^ kth_bit_mask;
                    next_length_count = length_count + 1;
                    next_state = CALCULATE_LENGTH; // Stay in this state to loop
                end
            end

            ACCUMULATE: begin
                next_total_sum = total_sum + length_count;
                next_length_count = 0;
                
                // Check if we are done with all configs
                // If unknowns exist, check if we just processed the last valid one (0xFF)
                // or if we need to generate next.
                
                if (unknown_mask == 0) begin
                    next_state = DIVIDE;
                end else begin
                    if (config_current == 8'hFF) begin
                        next_state = DIVIDE;
                    end else begin
                        next_state = GENERATE_CONFIGS;
                        next_config_current = config_current + 1'b1; // Try next number
                    end
                end
            end

            DIVIDE: begin
                // result_num = total_sum
                // result_den = number of configs
                // We need to compute denominator. 
                // Number of configs = 2^(number of '?' bits)
                // Since we summed over valid configs, total_sum is sum of lengths.
                // Denominator is 2^(popcount(unknown_mask)).
                
                next_result_num = total_sum;
                
                // Count question marks
                // We can calculate denominator in comb logic or just output sum and let TB divide?
                // Requirement: output numerator and denominator. Denominator is power of 2.
                // Let's calculate denominator.
                // popcount(unknown_mask):
                reg [3:0] q_count;
                q_count = 0;
                if (unknown_mask[0]) q_count = q_count + 1;
                if (unknown_mask[1]) q_count = q_count + 1;
                if (unknown_mask[2]) q_count = q_count + 1;
                if (unknown_mask[3]) q_count = q_count + 1;
                if (unknown_mask[4]) q_count = q_count + 1;
                if (unknown_mask[5]) q_count = q_count + 1;
                if (unknown_mask[6]) q_count = q_count + 1;
                if (unknown_mask[7]) q_count = q_count + 1;
                
                next_result_den = 32'd1 << q_count;
                
                if (unknown_mask == 0) next_result_den = 32'd1;
                
                next_done = 1'b1;
                next_state = IDLE; // Return to idle after done? Or stay DONE? 
                // Usually stays DONE until reset or new start. 
                // Let's stay in IDLE (or a DONE state) but for simplicity, IDLE resets done on entry.
                // If we go to IDLE, done will be high for 1 cycle then low.
                // Better to stay in DIVIDE or a DONE state.
                // Let's go to IDLE but 'done' stays high until start is asserted again?
                // The prompt says "High when computation complete".
                // If I go to IDLE, done goes low immediately (unless we are in start). 
                // Let's add a quick latch or go to a state where done is held.
                // Actually, standard practice: next_state = IDLE, but done output is registered.
                // If next_state is IDLE, next_done is 0 (unless we are in start). 
                // So let's go to IDLE. Done will be 1 for this cycle, then 0 next cycle.
                // If the user wants it held, they usually need a clear or start pulse.
            end
            
            default: next_state = IDLE;
        endcase
    end

    // --- Sequential Logic ---
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result_num <= 0;
            result_den <= 0;
            done <= 0;
            config_current <= 0;
            working_bits <= 0;
            total_sum <= 0;
            length_count <= 0;
        end else begin
            state <= next_state;
            result_num <= next_result_num;
            result_den <= next_result_den;
            done <= next_done;
            config_current <= next_config_current;
            working_bits <= next_working_bits;
            total_sum <= next_total_sum;
            length_count <= next_length_count;
        end
    end

endmodule