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

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;
    localparam [1:0] FINISH = 2'd2;
    
    reg [1:0] state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd200;
    
    // DP vector: 2^(pattern_len) states, each 8 bits
    reg [7:0] dp_vector [0:(2**(MAX_M))-1];
    reg [3:0] current_pos;
    reg [MAX_M-1:0] mask_eff;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            current_pos <= 4'd0;
            
            // Initialize DP vector
            for (integer i = 0; i < (2**(MAX_M)); i = i + 1) begin
                dp_vector[i] <= 8'd0;
            end
        end else begin
            done <= 1'b0;
            mask_eff = pattern_mask & ((1 << pattern_len) - 1);
            
            case (state)
                IDLE: begin
                    if (start) begin
                        if (pattern_len > n) begin
                            // Case 1: pattern longer than ID
                            result <= 16'd0;
                            done <= 1'b1;
                            state <= IDLE;
                        end else if (pattern_len == n) begin
                            // Case 2: pattern length equals ID length
                            integer wildcards = n - popcount(mask_eff);
                            result <= (wildcards >= 0 && wildcards <= 16) ? (16'd1 << wildcards) : 16'd0;
                            done <= 1'b1;
                            state <= IDLE;
                        end else begin
                            // Case 3: pattern length < ID length
                            // Initialize DP vector
                            for (integer i = 0; i < (2**(MAX_M)); i = i + 1) begin
                                dp_vector[i] <= 8'd0;
                            end
                            dp_vector[0] <= 8'd1; // Initial state: no match, suffix 0
                            current_pos <= 4'd0;
                            cycle_count <= 8'd0;
                            state <= COMPUTE;
                        end
                    end
                end
                
                COMPUTE: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    if (current_pos < n) begin
                        // Perform DP transition
                        reg [7:0] next_dp_vector [0:(2**(MAX_M))-1];
                        
                        // Initialize next_dp_vector
                        for (integer i = 0; i < (2**(MAX_M)); i = i + 1) begin
                            next_dp_vector[i] <= 8'd0;
                        end
                        
                        // For each state in dp_vector
                        for (integer state_idx = 0; state_idx < (2**(MAX_M)); state_idx = state_idx + 1) begin
                            if (dp_vector[state_idx] != 8'd0) begin
                                // Extract has_match and suffix
                                wire has_match = state_idx[pattern_len];
                                wire [MAX_M-1:0] suffix = state_idx[pattern_len-1:0];
                                
                                // For bit = 0 and 1
                                for (integer bit_val = 0; bit_val < 2; bit_val = bit_val + 1) begin
                                    // Compute new suffix
                                    wire [MAX_M-1:0] new_suffix = ((suffix << 1) | bit_val) & ((1 << pattern_len) - 1);
                                    
                                    // Check for match
                                    wire match = 1'b0;
                                    if (current_pos >= pattern_len - 1) begin
                                        wire [MAX_M-1:0] full_substring = (suffix << 1) | bit_val;
                                        match = ((full_substring & mask_eff) == mask_eff);
                                    end
                                    
                                    wire new_has_match = has_match | match;
                                    wire [MAX_M:0] new_state_idx = {new_has_match, new_suffix};
                                    
                                    // Add count to next_dp_vector
                                    if (next_dp_vector[new_state_idx] + dp_vector[state_idx] < 256) begin
                                        next_dp_vector[new_state_idx] <= next_dp_vector[new_state_idx] + dp_vector[state_idx];
                                    end
                                end
                            end
                        end
                        
                        // Update dp_vector
                        for (integer i = 0; i < (2**(MAX_M)); i = i + 1) begin
                            dp_vector[i] <= next_dp_vector[i];
                        end
                        
                        current_pos <= current_pos + 1'b1;
                        
                        // Exit conditions
                        if (current_pos >= n || cycle_count >= MAX_CYCLES) begin
                            state <= FINISH;
                        end
                    end else begin
                        state <= FINISH;
                    end
                end
                
                FINISH: begin
                    // Sum all states where has_match = 1
                    result <= 16'd0;
                    for (integer state_idx = 0; state_idx < (2**(MAX_M)); state_idx = state_idx + 1) begin
                        if (state_idx[pattern_len] == 1'b1) begin
                            result <= result + dp_vector[state_idx];
                        end
                    end
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end

    // Helper function to count set bits (popcount)
    function integer popcount(input [MAX_M-1:0] val);
        integer i;
        popcount = 0;
        for (i = 0; i < MAX_M; i = i + 1) begin
            if (val[i]) popcount = popcount + 1;
        end
    endfunction

endmodule