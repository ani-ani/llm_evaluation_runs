module PaperCounter(
    input clk,
    input rst_n,
    input start,
    input [12:0] P_scaled,
    output reg [7:0] a1,
    output reg [7:0] a2,
    output reg [7:0] a3,
    output reg [7:0] a4,
    output reg [7:0] a5,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] SEARCH_N = 3'd1;
    localparam [2:0] FIND_A = 3'd2;
    localparam [2:0] DONE_STATE = 3'd3;

    reg [2:0] state, next_state;

    // Counters and registers
    reg [7:0] n;           // Current n value (1-256)
    reg [7:0] a5_reg;      // Loop counters for a5, a4, a3, a2
    reg [7:0] a4_reg;
    reg [7:0] a3_reg;
    reg [7:0] a2_reg;
    reg [7:0] a1_reg;

    // Multiplication and division registers
    reg [23:0] product;    // P_scaled * n (24 bits)
    reg [15:0] S;          // S = (P_scaled * n) / 1000
    reg [9:0] remainder;   // Remainder for divisibility check

    // Flags
    reg found_n;
    reg found_solution;

    // Cycle counter for safety
    reg [9:0] cycle_count;
    localparam [9:0] MAX_CYCLES = 10'd1000;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all state
            state <= IDLE;
            next_state <= IDLE;
            n <= 8'd0;
            a5_reg <= 8'd0;
            a4_reg <= 8'd0;
            a3_reg <= 8'd0;
            a2_reg <= 8'd0;
            a1_reg <= 8'd0;
            product <= 24'd0;
            S <= 16'd0;
            remainder <= 10'd0;
            found_n <= 1'b0;
            found_solution <= 1'b0;
            cycle_count <= 10'd0;
            done <= 1'b0;
            a1 <= 8'd0;
            a2 <= 8'd0;
            a3 <= 8'd0;
            a4 <= 8'd0;
            a5 <= 8'd0;
        end else begin
            state <= next_state;

            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 10'd0;
                    if (start) begin
                        next_state <= SEARCH_N;
                        n <= 8'd1;
                        found_n <= 1'b0;
                        found_solution <= 1'b0;
                    end
                end

                SEARCH_N: begin
                    cycle_count <= cycle_count + 10'd1;
                    
                    // Compute product = P_scaled * n
                    product <= P_scaled * n;
                    
                    // Check divisibility by 1000
                    remainder <= product % 1000;
                    
                    if (remainder == 10'd0) begin
                        // Divisible by 1000
                        S <= product / 1000;
                        
                        // Check if S is within valid range
                        if (n <= S && S <= 5 * n) begin
                            found_n <= 1'b1;
                            next_state <= FIND_A;
                            a5_reg <= 8'd0;
                            a4_reg <= 8'd0;
                            a3_reg <= 8'd0;
                            a2_reg <= 8'd0;
                        end
                    end
                    
                    // Increment n or finish search
                    if (!found_n && n < 8'd256) begin
                        n <= n + 8'd1;
                    end else if (!found_n && n == 8'd256) begin
                        // No solution found
                        next_state <= DONE_STATE;
                    end
                end

                FIND_A: begin
                    cycle_count <= cycle_count + 10'd1;
                    
                    // Nested loops to find a1..a5
                    // Loop through a5
                    if (!found_solution) begin
                        if (a5_reg <= n && 5 * a5_reg <= S) begin
                            // Loop through a4
                            if (a4_reg <= n - a5_reg && 4 * a4_reg <= S - 5 * a5_reg) begin
                                // Loop through a3
                                if (a3_reg <= n - a5_reg - a4_reg && 3 * a3_reg <= S - 5 * a5_reg - 4 * a4_reg) begin
                                    // Loop through a2
                                    if (a2_reg <= n - a5_reg - a4_reg - a3_reg && 2 * a2_reg <= S - 5 * a5_reg - 4 * a4_reg - 3 * a3_reg) begin
                                        // Compute a1
                                        a1_reg <= n - a5_reg - a4_reg - a3_reg - a2_reg;
                                        
                                        // Check if sum matches
                                        if (a1_reg + 2 * a2_reg + 3 * a3_reg + 4 * a4_reg + 5 * a5_reg == S) begin
                                            found_solution <= 1'b1;
                                            next_state <= DONE_STATE;
                                        end
                                        
                                        // Increment a2
                                        a2_reg <= a2_reg + 8'd1;
                                    end else begin
                                        a2_reg <= 8'd0;
                                        a3_reg <= a3_reg + 8'd1;
                                    end
                                end else begin
                                    a3_reg <= 8'd0;
                                    a4_reg <= a4_reg + 8'd1;
                                end
                            end else begin
                                a4_reg <= 8'd0;
                                a5_reg <= a5_reg + 8'd1;
                            end
                        end else begin
                            // No solution found for this n
                            next_state <= SEARCH_N;
                            n <= n + 8'd1;
                            found_n <= 1'b0;
                        end
                    end
                end

                DONE_STATE: begin
                    if (found_solution) begin
                        a1 <= a1_reg;
                        a2 <= a2_reg;
                        a3 <= a3_reg;
                        a4 <= a4_reg;
                        a5 <= a5_reg;
                    end else begin
                        a1 <= 8'd0;
                        a2 <= 8'd0;
                        a3 <= 8'd0;
                        a4 <= 8'd0;
                        a5 <= 8'd0;
                    end
                    done <= 1'b1;
                    next_state <= IDLE;
                end

                default: begin
                    next_state <= IDLE;
                    done <= 1'b0;
                end
            endcase
            
            // Safety check for cycle count
            if (cycle_count >= MAX_CYCLES) begin
                next_state <= DONE_STATE;
                a1 <= 8'd0;
                a2 <= 8'd0;
                a3 <= 8'd0;
                a4 <= 8'd0;
                a5 <= 8'd0;
            end
        end
    end

endmodule