module SpyIDCounter #(
    parameter MAX_N = 8,
    parameter MAX_M = 6
)(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] n,
    input wire [3:0] pattern_len,
    input wire [MAX_M-1:0] pattern_mask,
    output reg [15:0] result,
    output reg done
);

    // State definitions
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] SETUP = 2'd1;
    localparam [1:0] COMPUTE = 2'd2;
    localparam [1:0] FINISH = 2'd3;

    // DP vector: 2^(MAX_M-1) states * 2 (has_match bits) = 2^MAX_M entries
    // Each entry is 8 bits (count)
    localparam [7:0] DP_SIZE = 8'd1 << MAX_M;
    reg [7:0] dp_vector [0:255]; // Max size for MAX_M=8
    reg [7:0] next_dp_vector [0:255];
    
    reg [1:0] state, next_state;
    reg [3:0] current_pos, next_current_pos;
    reg [15:0] temp_result, next_temp_result;
    reg [7:0] cycle_counter, next_cycle_counter;
    
    // Combinational helpers
    wire [MAX_M-1:0] mask_eff;
    assign mask_eff = pattern_mask & ((1 << pattern_len) - 1);

    integer i, j, k;
    integer state_idx, bit_val;
    
    // Combinational logic for DP transition
    always @(*) begin
        // Default assignments
        for (i = 0; i < 256; i = i + 1) begin
            next_dp_vector[i] = 8'd0;
        end
        next_temp_result = temp_result;
        next_current_pos = current_pos;
        next_state = state;
        next_cycle_counter = cycle_counter;
        
        case (state)
            IDLE: begin
                next_state = SETUP;
                next_cycle_counter = 8'd0;
            end
            
            SETUP: begin
                // Initialize DP vector
                for (i = 0; i < 256; i = i + 1) begin
                    next_dp_vector[i] = 8'd0;
                end
                // Initial state: has_match=0, suffix=0, count=1
                next_dp_vector[0] = 8'd1;
                next_current_pos = 4'd0;
                next_state = COMPUTE;
            end
            
            COMPUTE: begin
                // Perform one iteration of DP
                next_current_pos = current_pos + 1'b1;
                next_cycle_counter = cycle_counter + 1'b1;
                
                // For each current state with count > 0
                for (state_idx = 0; state_idx < (1 << MAX_M); state_idx = state_idx + 1) begin
                    if (dp_vector[state_idx] != 8'd0) begin
                        // Extract has_match and suffix
                        wire has_match = state_idx[MAX_M-1];
                        wire [MAX_M-2:0] suffix = state_idx[MAX_M-2:0];
                        
                        for (bit_val = 0; bit_val < 2; bit_val = bit_val + 1) begin
                            // Compute new suffix
                            wire [MAX_M-2:0] new_suffix = ((suffix << 1) | bit_val) & ((1 << (pattern_len-1)) - 1);
                            
                            // Check for match
                            wire match;
                            if (current_pos >= pattern_len - 1) begin
                                wire [MAX_M-1:0] full_substring = (suffix << 1) | bit_val;
                                match = ((full_substring & mask_eff) == mask_eff);
                            end else begin
                                match = 1'b0;
                            end
                            
                            wire new_has_match = has_match | match;
                            wire [MAX_M-1:0] new_state_idx = {new_has_match, new_suffix};
                            
                            // Add to next vector
                            if (dp_vector[state_idx] + next_dp_vector[new_state_idx] < 256) begin
                                next_dp_vector[new_state_idx] = next_dp_vector[new_state_idx] + dp_vector[state_idx];
                            end
                        end
                    end
                end
                
                // Check completion
                if (current_pos == n) begin
                    next_state = FINISH;
                end
            end
            
            FINISH: begin
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end

    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            current_pos <= 4'd0;
            result <= 16'd0;
            done <= 1'b0;
            temp_result <= 16'd0;
            cycle_counter <= 8'd0;
            for (i = 0; i < 256; i = i + 1) begin
                dp_vector[i] <= 8'd0;
            end
        end else begin
            state <= next_state;
            current_pos <= next_current_pos;
            temp_result <= next_temp_result;
            cycle_counter <= next_cycle_counter;
            
            // Copy next_dp_vector to dp_vector
            for (i = 0; i < 256; i = i + 1) begin
                dp_vector[i] <= next_dp_vector[i];
            end
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        // Check immediate cases
                        if (pattern_len > n) begin
                            result <= 16'd0;
                            done <= 1'b1;
                        end else if (pattern_len == n) begin
                            // Count wildcards
                            integer wc = 0;
                            for (k = 0; k < MAX_M; k = k + 1) begin
                                if (k < pattern_len) begin
                                    if (!mask_eff[k]) wc = wc + 1;
                                end
                            end
                            result <= (16'd1 << wc);
                            done <= 1'b1;
                        end
                    end
                end
                
                COMPUTE: begin
                    if (current_pos == n) begin
                        // Sum counts from states with has_match=1
                        temp_result <= 16'd0;
                        for (j = 0; j < (1 << MAX_M); j = j + 1) begin
                            if (j[MAX_M-1]) begin
                                temp_result <= temp_result + dp_vector[j];
                            end
                        end
                    end
                end
                
                FINISH: begin
                    result <= temp_result;
                    done <= 1'b1;
                end
            endcase
        end
    end

endmodule