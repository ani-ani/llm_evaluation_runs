module PermutationSolver(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] a [0:15],
    input wire [3:0] n,
    output reg [3:0] pi [0:15],
    output reg [3:0] sigma [0:15],
    output reg done,
    output reg valid
);

    // State definitions
    localparam [2:0] IDLE    = 3'd0;
    localparam [2:0] SEARCH  = 3'd1;
    localparam [2:0] VALID   = 3'd2;
    localparam [2:0] INVALID = 3'd3;

    // Internal registers
    reg [2:0] state;
    reg [3:0] current_pos;
    reg [3:0] pi_used [0:15];
    reg [3:0] sigma_used [0:15];
    reg [3:0] pi_temp [0:15];
    reg [3:0] sigma_temp [0:15];
    reg [3:0] pi_try;
    reg [3:0] sigma_try;
    reg [15:0] cycle_count;
    localparam [15:0] MAX_CYCLES = 16'd10000;

    // Initialize arrays
    integer i;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            current_pos <= 4'd0;
            done <= 1'b0;
            valid <= 1'b0;
            cycle_count <= 16'd0;
            
            // Initialize all arrays
            for (i = 0; i < 16; i = i + 1) begin
                pi[i] <= 4'd0;
                sigma[i] <= 4'd0;
                pi_used[i] <= 4'd0;
                sigma_used[i] <= 4'd0;
                pi_temp[i] <= 4'd0;
                sigma_temp[i] <= 4'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    valid <= 1'b0;
                    cycle_count <= 16'd0;
                    
                    // Initialize arrays on start
                    if (start) begin
                        for (i = 0; i < 16; i = i + 1) begin
                            pi_used[i] <= 4'd0;
                            sigma_used[i] <= 4'd0;
                            pi_temp[i] <= 4'd0;
                            sigma_temp[i] <= 4'd0;
                        end
                        current_pos <= 4'd0;
                        state <= SEARCH;
                    end
                end

                SEARCH: begin
                    cycle_count <= cycle_count + 16'd1;
                    
                    // Check for timeout
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= INVALID;
                    end else begin
                        // Try to find valid pi_try value
                        pi_try <= pi_try + 4'd1;
                        
                        // Check if pi_try is valid (1..n and not used)
                        if (pi_try >= 4'd1 && pi_try <= n && !pi_used[pi_try - 4'd1][0]) begin
                            // Compute required sigma value
                            sigma_try <= (a[current_pos] - pi_try + n) % n;
                            
                            // Adjust for 1-based indexing
                            if (sigma_try == 4'd0) begin
                                sigma_try <= n;
                            end
                            
                            // Check if sigma_try is valid (1..n and not used)
                            if (sigma_try >= 4'd1 && sigma_try <= n && 
                                !sigma_used[sigma_try - 4'd1][0]) begin
                                
                                // Store temporary values
                                pi_temp[current_pos] <= pi_try;
                                sigma_temp[current_pos] <= sigma_try;
                                
                                // Mark as used
                                pi_used[pi_try - 4'd1] <= 4'd1;
                                sigma_used[sigma_try - 4'd1] <= 4'd1;
                                
                                // Move to next position or finish
                                if (current_pos == n - 4'd1) begin
                                    state <= VALID;
                                end else begin
                                    current_pos <= current_pos + 4'd1;
                                    pi_try <= 4'd0;
                                end
                            end
                        end else if (pi_try >= n) begin
                            // Backtrack
                            if (current_pos == 4'd0) begin
                                state <= INVALID;
                            end else begin
                                current_pos <= current_pos - 4'd1;
                                
                                // Unmark previous values
                                pi_used[pi_temp[current_pos] - 4'd1] <= 4'd0;
                                sigma_used[sigma_temp[current_pos] - 4'd1] <= 4'd0;
                                
                                pi_try <= pi_temp[current_pos];
                            end
                        end
                    end
                end

                VALID: begin
                    // Copy solution to outputs
                    for (i = 0; i < 16; i = i + 1) begin
                        if (i < n) begin
                            pi[i] <= pi_temp[i];
                            sigma[i] <= sigma_temp[i];
                        end else begin
                            pi[i] <= 4'd0;
                            sigma[i] <= 4'd0;
                        end
                    end
                    valid <= 1'b1;
                    done <= 1'b1;
                    state <= IDLE;
                end

                INVALID: begin
                    valid <= 1'b0;
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule