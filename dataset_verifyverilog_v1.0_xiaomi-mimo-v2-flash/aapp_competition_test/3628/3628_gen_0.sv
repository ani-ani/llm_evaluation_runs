module PermutationSolver (
    input clk,
    input rst_n,
    input start,
    input [3:0] n,
    input [3:0] a [0:15],
    output reg [3:0] pi [0:15],
    output reg [3:0] sigma [0:15],
    output reg done,
    output reg valid
);

    // State definitions
    localparam [2:0] IDLE    = 3'd0;
    localparam [2:0] SEARCH  = 3'd1;
    localparam [2:0] CHECK   = 3'd2;
    localparam [2:0] VALID_S = 3'd3;
    localparam [2:0] INVALID = 3'd4;
    localparam [2:0] DONE_S  = 3'd5;

    // Registers and arrays
    reg [2:0] state, next_state;
    reg [3:0] current_pos;
    reg [3:0] pi_val_try;
    reg [3:0] sigma_val;
    reg pi_used [0:15];
    reg sigma_used [0:15];
    reg [15:0] cycle_count;
    localparam [15:0] MAX_CYCLES = 16'd10000;
    
    // Loop counter for initialization
    integer i;

    // Computation logic for sigma value
    reg [3:0] temp_sub;
    reg [3:0] temp_mod;
    
    // Next state logic
    always @(*) begin
        case (state)
            IDLE: next_state = start ? SEARCH : IDLE;
            
            SEARCH: begin
                if (pi_val_try > n) begin
                    next_state = INVALID;
                end else if (pi_used[pi_val_try] == 1'b0) begin
                    // Compute sigma candidate
                    temp_sub = (a[current_pos] >= pi_val_try) ? (a[current_pos] - pi_val_try) : (a[current_pos] + n - pi_val_try);
                    temp_mod = (temp_sub == 4'd0) ? n : temp_sub;
                    
                    if (temp_mod >= 4'd1 && temp_mod <= n && sigma_used[temp_mod] == 1'b0) begin
                        next_state = CHECK;
                    end else begin
                        next_state = SEARCH;
                    end
                end else begin
                    next_state = SEARCH;
                end
            end
            
            CHECK: begin
                if (current_pos == n - 4'd1) begin
                    next_state = VALID_S;
                end else begin
                    next_state = SEARCH;
                end
            end
            
            VALID_S: next_state = DONE_S;
            INVALID: next_state = DONE_S;
            DONE_S:  next_state = IDLE;
            
            default: next_state = IDLE;
        endcase
    end

    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            valid <= 1'b0;
            current_pos <= 4'd0;
            pi_val_try <= 4'd1;
            cycle_count <= 16'd0;
            
            for (i = 0; i < 16; i = i + 1) begin
                pi[i] <= 4'd0;
                sigma[i] <= 4'd0;
                pi_used[i] <= 1'b0;
                sigma_used[i] <= 1'b0;
            end
            
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    valid <= 1'b0;
                    cycle_count <= 16'd0;
                    current_pos <= 4'd0;
                    pi_val_try <= 4'd1;
                    
                    if (start) begin
                        for (i = 0; i < 16; i = i + 1) begin
                            pi[i] <= 4'd0;
                            sigma[i] <= 4'd0;
                            pi_used[i] <= 1'b0;
                            sigma_used[i] <= 1'b0;
                        end
                    end
                end
                
                SEARCH: begin
                    cycle_count <= cycle_count + 16'd1;
                    
                    if (pi_val_try > n) begin
                        // Backtrack
                        if (current_pos > 4'd0) begin
                            current_pos <= current_pos - 4'd1;
                            pi_val_try <= pi[current_pos - 4'd1] + 4'd1;
                            pi_used[pi[current_pos - 4'd1]] <= 1'b0;
                            sigma_used[sigma[current_pos - 4'd1]] <= 1'b0;
                        end
                    end else if (pi_used[pi_val_try] == 1'b0) begin
                        temp_sub = (a[current_pos] >= pi_val_try) ? (a[current_pos] - pi_val_try) : (a[current_pos] + n - pi_val_try);
                        temp_mod = (temp_sub == 4'd0) ? n : temp_sub;
                        
                        if (temp_mod >= 4'd1 && temp_mod <= n && sigma_used[temp_mod] == 1'b0) begin
                            pi[current_pos] <= pi_val_try;
                            sigma[current_pos] <= temp_mod;
                            pi_used[pi_val_try] <= 1'b1;
                            sigma_used[temp_mod] <= 1'b1;
                            pi_val_try <= pi_val_try + 4'd1;
                        end else begin
                            pi_val_try <= pi_val_try + 4'd1;
                        end
                    end else begin
                        pi_val_try <= pi_val_try + 4'd1;
                    end
                end
                
                CHECK: begin
                    current_pos <= current_pos + 4'd1;
                    pi_val_try <= 4'd1;
                end
                
                VALID_S: begin
                    valid <= 1'b1;
                end
                
                INVALID: begin
                    valid <= 1'b0;
                end
                
                DONE_S: begin
                    done <= 1'b1;
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
            
            state <= next_state;
            
            // Timeout protection
            if (cycle_count >= MAX_CYCLES && state == SEARCH) begin
                state <= INVALID;
            end
        end
    end
endmodule