module paper_puzzler (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [31:0] p_scaled,
    output reg [7:0] n1, n2, n3, n4, n5,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE     = 3'd0;
    localparam [2:0] INIT_N   = 3'd1;
    localparam [2:0] INIT_N5  = 3'd2;
    localparam [2:0] INIT_N4  = 3'd3;
    localparam [2:0] INIT_N3  = 3'd4;
    localparam [2:0] CHECK    = 3'd5;
    localparam [2:0] INCREMENT = 3'd6;
    localparam [2:0] FINISH   = 3'd7;

    reg [2:0] state;
    reg [2:0] next_state;

    // Internal registers and variables
    reg [7:0] N;               // Current total papers
    reg [7:0] n5, n4, n3, n2;  // Counts (n1 derived)
    reg [7:0] N_reg;           // Stored N for comparison
    reg [7:0] n5_reg, n4_reg, n3_reg, n2_reg; // Stored counts for output
    reg found;                 // Flag for solution found

    // 64-bit intermediate for multiplication
    reg [63:0] left_sum_scaled;
    reg [63:0] right_sum_scaled;

    // Combinational logic for sum calculation
    reg [11:0] weighted_sum;   // Max: 1280 (5*256)
    reg [7:0] n1_calc;

    always @(*) begin
        n1_calc = N - (n5 + n4 + n3 + n2);
        weighted_sum = (n5 * 8'd5) + (n4 * 8'd4) + (n3 * 8'd3) + (n2 * 8'd2) + n1_calc;
    end

    // State transition logic
    always @(*) begin
        case (state)
            IDLE:       next_state = start ? INIT_N : IDLE;
            INIT_N:     next_state = INIT_N5;
            INIT_N5:    next_state = INIT_N4;
            INIT_N4:    next_state = INIT_N3;
            INIT_N3:    next_state = CHECK;
            CHECK: begin
                if (found) begin
                    next_state = FINISH;
                end else begin
                    next_state = INCREMENT;
                end
            end
            INCREMENT: begin
                if (n2 > 8'd0) begin
                    next_state = CHECK;
                end else if (n3 > 8'd0) begin
                    next_state = CHECK;
                end else if (n4 > 8'd0) begin
                    next_state = CHECK;
                end else if (n5 > 8'd0) begin
                    next_state = CHECK;
                end else begin
                    next_state = CHECK;
                end
            end
            FINISH:     next_state = IDLE;
            default:    next_state = IDLE;
        endcase
    end

    // State update and sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            n1 <= 8'd0;
            n2 <= 8'd0;
            n3 <= 8'd0;
            n4 <= 8'd0;
            n5 <= 8'd0;
            done <= 1'b0;
            N <= 8'd0;
            n5_reg <= 8'd0;
            n4_reg <= 8'd0;
            n3_reg <= 8'd0;
            n2_reg <= 8'd0;
            N_reg <= 8'd0;
            found <= 1'b0;
            left_sum_scaled <= 64'd0;
            right_sum_scaled <= 64'd0;
        end else begin
            state <= next_state;
            done <= 1'b0;

            case (state)
                IDLE: begin
                    // Clear outputs and found flag
                    found <= 1'b0;
                end

                INIT_N: begin
                    N <= 8'd1; // Start search from N=1
                end

                INIT_N5: begin
                    // Initialize counts for current N
                    n5 <= N;
                end

                INIT_N4: begin
                    n4 <= 8'd0;
                end

                INIT_N3: begin
                    n3 <= 8'd0;
                end

                CHECK: begin
                    // Calculate weighted sum and scaled values
                    // left_sum * 10^9 == p_scaled * N
                    // left_sum_scaled = weighted_sum * 1000000000
                    // right_sum_scaled = p_scaled * N
                    
                    // Multiplication: weighted_sum * 1000000000
                    // 1280 * 10^9 = 1.28e12 < 2^40
                    // Use 64-bit for safety
                    left_sum_scaled <= weighted_sum * 32'd1000000000;
                    right_sum_scaled <= p_scaled * N;
                end

                INCREMENT: begin
                    // Check if we found a match in previous CHECK state
                    if (left_sum_scaled == right_sum_scaled && (n5 + n4 + n3 + n2) <= N) begin
                        found <= 1'b1;
                        n5_reg <= n5;
                        n4_reg <= n4;
                        n3_reg <= n3;
                        n2_reg <= n2;
                        N_reg <= N;
                    end else begin
                        // If not found, increment counts
                        if (n2 > 8'd0) begin
                            n2 <= n2 - 8'd1;
                        end else if (n3 > 8'd0) begin
                            n3 <= n3 - 8'd1;
                            n2 <= N - n5 - n4 - n3;
                        end else if (n4 > 8'd0) begin
                            n4 <= n4 - 8'd1;
                            n3 <= N - n5 - n4;
                            n2 <= 8'd0;
                        end else if (n5 > 8'd0) begin
                            n5 <= n5 - 8'd1;
                            n4 <= N - n5;
                            n3 <= 8'd0;
                            n2 <= 8'd0;
                        end else begin
                            // All combinations for current N exhausted
                            if (N < 8'd256) begin
                                N <= N + 8'd1;
                            end
                            n5 <= N + 8'd1; // Will be decremented to N in next cycle
                            n4 <= 8'd0;
                            n3 <= 8'd0;
                            n2 <= 8'd0;
                        end
                    end
                end

                FINISH: begin
                    if (found) begin
                        n1 <= N_reg - (n5_reg + n4_reg + n3_reg + n2_reg);
                        n2 <= n2_reg;
                        n3 <= n3_reg;
                        n4 <= n4_reg;
                        n5 <= n5_reg;
                    end else begin
                        // No solution found (edge case)
                        n1 <= 8'd0;
                        n2 <= 8'd0;
                        n3 <= 8'd0;
                        n4 <= 8'd0;
                        n5 <= 8'd0;
                    end
                    done <= 1'b1;
                    found <= 1'b0;
                end
            endcase
        end
    end

endmodule