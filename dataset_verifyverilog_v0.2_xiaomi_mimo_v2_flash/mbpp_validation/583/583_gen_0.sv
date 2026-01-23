module catalan_number(
    input clk,
    input rst_n,
    input start,
    input [4:0] n,
    output reg [31:0] result,
    output reg done
);

    // State encoding
    localparam IDLE = 2'b00;
    localparam INIT = 2'b01;
    localparam COMPUTE = 2'b10;
    localparam FINISH = 2'b11;

    // Registers for state machine
    reg [1:0] state, next_state;
    
    // Registers for computation
    reg [4:0] i_reg, j_reg;           // Loop counters
    reg [31:0] dp [0:15];             // DP table for Catalan numbers
    reg [4:0] n_reg;                  // Stored n value
    reg [31:0] sum_temp;              // Temporary sum accumulator
    reg first_term;                   // Flag for first term in summation
    
    // Combinational next state logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start)
                    next_state = INIT;
                else
                    next_state = IDLE;
            end
            INIT: begin
                next_state = COMPUTE;
            end
            COMPUTE: begin
                if (i_reg > n_reg)
                    next_state = FINISH;
                else
                    next_state = COMPUTE;
            end
            FINISH: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

    // Sequential state and data logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 32'd0;
            done <= 1'b0;
            i_reg <= 5'd0;
            j_reg <= 5'd0;
            sum_temp <= 32'd0;
            first_term <= 1'b1;
            n_reg <= 5'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        n_reg <= n;
                        i_reg <= 5'd2;      // Start computing from C[2]
                        j_reg <= 5'd0;
                        dp[0] <= 32'd1;     // Base case
                        dp[1] <= 32'd1;     // Base case
                    end
                end
                
                INIT: begin
                    // Initialize for computation
                    j_reg <= 5'd0;
                    sum_temp <= 32'd0;
                    first_term <= 1'b1;
                    // Handle special case: if n < 2
                    if (n_reg < 2) begin
                        result <= (n_reg == 0) ? 32'd1 : 32'd1;
                        done <= 1'b1;
                    end
                end
                
                COMPUTE: begin
                    if (i_reg <= n_reg) begin
                        // Compute C[i] = sum_{j=0}^{i-1} C[j] * C[i-1-j]
                        if (j_reg < i_reg) begin
                            // Accumulate product
                            if (first_term) begin
                                sum_temp <= dp[j_reg] * dp[i_reg - 1 - j_reg];
                                first_term <= 1'b0;
                            end else begin
                                sum_temp <= sum_temp + (dp[j_reg] * dp[i_reg - 1 - j_reg]);
                            end
                            j_reg <= j_reg + 1'b1;
                        end else begin
                            // Done with current i, store result
                            dp[i_reg] <= sum_temp;
                            
                            // Check if we computed up to n
                            if (i_reg == n_reg) begin
                                result <= sum_temp;
                            end
                            
                            // Reset for next i
                            i_reg <= i_reg + 1'b1;
                            j_reg <= 5'd0;
                            sum_temp <= 32'd0;
                            first_term <= 1'b1;
                        end
                    end
                end
                
                FINISH: begin
                    done <= 1'b1;
                end
            endcase
        end
    end

endmodule