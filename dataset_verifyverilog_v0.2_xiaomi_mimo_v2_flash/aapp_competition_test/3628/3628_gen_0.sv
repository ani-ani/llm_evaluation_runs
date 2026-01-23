module permutation_solver(
    input clk,
    input rst_n,
    input start,
    input [7:0] a_i,
    input [2:0] index,
    output reg [7:0] pi_out,
    output reg [7:0] sigma_out,
    output reg [2:0] out_index,
    output reg found,
    output reg done
);

// State encoding
localparam IDLE = 5'b00000;
localparam SEARCH_0 = 5'b00001;
localparam SEARCH_1 = 5'b00010;
localparam SEARCH_2 = 5'b00011;
localparam SEARCH_3 = 5'b00100;
localparam SEARCH_4 = 5'b00101;
localparam SEARCH_5 = 5'b00110;
localparam SEARCH_6 = 5'b00111;
localparam SEARCH_7 = 5'b01000;
localparam CHECK = 5'b01001;
localparam FOUND = 5'b01010;
localparam IMPOSSIBLE = 5'b01011;
localparam OUTPUT = 5'b01100;
localparam DONE = 5'b01101;
localparam BACKTRACK = 5'b01110;

reg [4:0] state, next_state;

// Arrays for permutations
reg [7:0] pi [0:7];
reg [7:0] sigma [0:7];

// Used flags for numbers 1-8 (index 1-8, index 0 unused)
reg used_pi [0:8];
reg used_sigma [0:8];

// Current position in search
reg [2:0] pos;

// Candidate value for current position
reg [3:0] candidate; // 1-8

// Store target modulus for each position
reg [2:0] target_mod [0:7];

// Counter for output
reg [2:0] out_cnt;

// Helper to compute target modulus
wire [2:0] current_target_mod;
assign current_target_mod = (a_i == 8'd8) ? 3'd0 : a_i[2:0];

// Helper: check if (p + s) % 8 == target_mod
function automatic logic check_pair;
    input [3:0] p;
    input [3:0] s;
    input [2:0] target;
    begin
        logic [4:0] sum;
        sum = p + s;
        check_pair = (sum[2:0] == target);
    end
endfunction

// State transition
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
    end else begin
        state <= next_state;
    end
end

// Next state logic and outputs
always @(*) begin
    next_state = state;
    done = 1'b0;
    found = 1'b0;
    pi_out = 8'd0;
    sigma_out = 8'd0;
    out_index = 3'd0;
    
    case (state)
        IDLE: begin
            done = 1'b0;
            found = 1'b0;
            if (start) begin
                next_state = SEARCH_0;
            end
        end
        
        SEARCH_0, SEARCH_1, SEARCH_2, SEARCH_3, 
        SEARCH_4, SEARCH_5, SEARCH_6, SEARCH_7: begin
            // Check if we have a valid candidate
            if (candidate <= 8) begin
                // Check if this candidate pair is valid
                if (check_pair(pos + 1, candidate[3:0], target_mod[pos]) && 
                    !used_sigma[candidate[2:0]] && !used_pi[pos + 1]) begin
                    next_state = state + 1;
                    if (state == SEARCH_7) begin
                        next_state = CHECK;
                    end
                end else begin
                    // Try next candidate
                    next_state = state;
                end
            end else begin
                // No more candidates, backtrack
                next_state = BACKTRACK;
            end
        end
        
        BACKTRACK: begin
            if (pos == 3'd0) begin
                next_state = IMPOSSIBLE;
            end else begin
                // Go back to previous SEARCH state
                case (pos)
                    3'd1: next_state = SEARCH_0;
                    3'd2: next_state = SEARCH_1;
                    3'd3: next_state = SEARCH_2;
                    3'd4: next_state = SEARCH_3;
                    3'd5: next_state = SEARCH_4;
                    3'd6: next_state = SEARCH_5;
                    3'd7: next_state = SEARCH_6;
                    default: next_state = IMPOSSIBLE;
                endcase
            end
        end
        
        CHECK: begin
            // Verify solution (should already be valid)
            next_state = FOUND;
        end
        
        FOUND: begin
            found = 1'b1;
            next_state = OUTPUT;
        end
        
        OUTPUT: begin
            pi_out = pi[out_cnt];
            sigma_out = sigma[out_cnt];
            out_index = out_cnt;
            if (out_cnt == 3'd7) begin
                next_state = DONE;
            end else begin
                next_state = OUTPUT;
            end
        end
        
        DONE: begin
            done = 1'b1;
            found = 1'b1;
            next_state = DONE;
        end
        
        IMPOSSIBLE: begin
            done = 1'b1;
            found = 1'b0;
            next_state = DONE;
        end
        
        default: next_state = IDLE;
    endcase
end

// Sequential logic for search and output
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        // Reset all state
        pos <= 3'd0;
        candidate <= 4'd1;
        out_cnt <= 3'd0;
        // Clear arrays
        for (integer i = 0; i < 8; i = i + 1) begin
            pi[i] <= 8'd0;
            sigma[i] <= 8'd0;
        end
        // Clear used flags
        for (integer i = 0; i < 9; i = i + 1) begin
            used_pi[i] <= 1'b0;
            used_sigma[i] <= 1'b0;
        end
        // Store target mods from current a_i (update on start)
        // We'll update on the fly
    end else begin
        case (state)
            IDLE: begin
                if (start) begin
                    // Store target mod for position 0
                    target_mod[0] <= current_target_mod;
                    pos <= 3'd0;
                    candidate <= 4'd1;
                    out_cnt <= 3'd0;
                end
            end
            
            SEARCH_0, SEARCH_1, SEARCH_2, SEARCH_3, 
            SEARCH_4, SEARCH_5, SEARCH_6, SEARCH_7: begin
                if (next_state != state) begin
                    // Valid assignment found, move to next position
                    if (next_state != BACKTRACK && next_state != CHECK) begin
                        pi[pos] <= pos + 1;
                        sigma[pos] <= candidate[3:0];
                        used_pi[pos + 1] <= 1'b1;
                        used_sigma[candidate[2:0]] <= 1'b1;
                        pos <= pos + 1;
                        if (pos < 3'd7) begin
                            target_mod[pos + 1] <= current_target_mod;
                        end
                        candidate <= 4'd1;
                    end else if (next_state == BACKTRACK) begin
                        // Remove current assignment and reset
                        if (pos != 3'd0) begin
                            used_pi[pos + 1] <= 1'b0;
                            used_sigma[sigma[pos][2:0]] <= 1'b0;
                        end
                        candidate <= 4'd1;
                        if (pos > 3'd0) begin
                            pos <= pos - 1;
                        end
                    end else if (next_state == CHECK) begin
                        // Store last assignment
                        pi[pos] <= pos + 1;
                        sigma[pos] <= candidate[3:0];
                        used_pi[pos + 1] <= 1'b1;
                        used_sigma[candidate[2:0]] <= 1'b1;
                    end
                end else begin
                    // Same state, try next candidate
                    candidate <= candidate + 1;
                end
            end
            
            BACKTRACK: begin
                if (next_state != BACKTRACK && next_state != IMPOSSIBLE) begin
                    // Moving back to previous search state
                    // Keep pos decremented, candidate reset
                end
            end
            
            CHECK: begin
                // Just a verification state
                out_cnt <= 3'd0;
            end
            
            OUTPUT: begin
                if (next_state == DONE) begin
                    out_cnt <= 3'd0;
                end else begin
                    out_cnt <= out_cnt + 1;
                end
            end
            
            FOUND: begin
                // Transition to output
                out_cnt <= 3'd0;
            end
            
            IMPOSSIBLE: begin
                // Transition to done
                out_cnt <= 3'd0;
            end
            
            DONE: begin
                // Keep done high
                if (!start) begin
                    // If start goes low, we could reset, but spec says wait for external read
                end
            end
        endcase
    end
end

endmodule
