module max_path_average (
    input clk,
    input rst_n,
    input start,
    input [7:0] cost_0_0, cost_0_1, cost_0_2,
    input [7:0] cost_1_0, cost_1_1, cost_1_2,
    input [7:0] cost_2_0, cost_2_1, cost_2_2,
    output reg [31:0] result,
    output reg done
);

    // State Encoding
    localparam IDLE = 5'b00001;
    localparam ROW0 = 5'b00010;
    localparam ROW1 = 5'b00100;
    localparam ROW2 = 5'b01000;
    localparam DIVIDE = 5'b10000;
    localparam DONE = 5'b11111; // Distinct state for completion

    reg [4:0] state;
    reg [4:0] next_state;
    
    // Internal Registers
    reg [7:0] cost_reg [0:2][0:2];
    reg [11:0] dp [0:2][0:2]; // Max total 2295 fits in 12 bits
    reg [2:0] ptr; // Cell pointer within rows
    
    // Division Registers (Shift-Subtract)
    reg [31:0] div_numer; // dividend shifted left 16
    reg [4:0] div_cnt;    // 17 cycles needed for 16-bit result + 1 for init
    wire [11:0] div_quotient;
    wire [31:0] div_remainder;
    
    // --- Combinational Logic ---
    
    // Next State Logic
    always @(*) begin
        case (state)
            IDLE:       next_state = start ? ROW0 : IDLE;
            ROW0:       next_state = (ptr == 3'd2) ? ROW1 : ROW0;
            ROW1:       next_state = (ptr == 3'd2) ? ROW2 : ROW1;
            ROW2:       next_state = (ptr == 3'd2) ? DIVIDE : ROW2;
            DIVIDE:     next_state = (div_cnt == 5'd17) ? DONE : DIVIDE;
            DONE:       next_state = start ? IDLE : DONE; // Restart on start if needed, or stay
            default:    next_state = IDLE;
        endcase
    end

    // --- Sequential Logic ---
    
    // State Register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) state <= IDLE;
        else state <= next_state;
    end
    
    // Main DP and Control Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset
            done <= 1'b0;
            result <= 32'd0;
            ptr <= 3'd0;
            div_cnt <= 5'd0;
            div_numer <= 32'd0;
            // Reset DP array (optional for logic, good for clean slate)
            integer i, j;
            for (i = 0; i < 3; i = i + 1) begin
                for (j = 0; j < 3; j = j + 1) begin
                    dp[i][j] <= 12'd0;
                    cost_reg[i][j] <= 8'd0;
                end
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    ptr <= 3'd0;
                    if (start) begin
                        // Store costs
                        cost_reg[0][0] <= cost_0_0; cost_reg[0][1] <= cost_0_1; cost_reg[0][2] <= cost_0_2;
                        cost_reg[1][0] <= cost_1_0; cost_reg[1][1] <= cost_1_1; cost_reg[1][2] <= cost_1_2;
                        cost_reg[2][0] <= cost_2_0; cost_reg[2][1] <= cost_2_1; cost_reg[2][2] <= cost_2_2;
                    end
                end

                ROW0: begin
                    ptr <= ptr + 1;
                    if (ptr == 3'd0) begin
                        dp[0][0] <= {4'b0, cost_reg[0][0]};
                    end else if (ptr == 3'd1) begin
                        dp[0][1] <= dp[0][0] + {4'b0, cost_reg[0][1]};
                    end else if (ptr == 3'd2) begin
                        dp[0][2] <= dp[0][1] + {4'b0, cost_reg[0][2]};
                    end
                end

                ROW1: begin
                    ptr <= ptr + 1;
                    if (ptr == 3'd0) begin
                        dp[1][0] <= dp[0][0] + {4'b0, cost_reg[1][0]};
                    end else if (ptr == 3'd1) begin
                        // max(dp[0][1], dp[1][0])
                        if (dp[0][1] > dp[1][0]) 
                            dp[1][1] <= dp[0][1] + {4'b0, cost_reg[1][1]};
                        else 
                            dp[1][1] <= dp[1][0] + {4'b0, cost_reg[1][1]};
                    end else if (ptr == 3'd2) begin
                        // max(dp[0][2], dp[1][1])
                        if (dp[0][2] > dp[1][1]) 
                            dp[1][2] <= dp[0][2] + {4'b0, cost_reg[1][2]};
                        else 
                            dp[1][2] <= dp[1][1] + {4'b0, cost_reg[1][2]};
                    end
                end

                ROW2: begin
                    ptr <= ptr + 1;
                    if (ptr == 3'd0) begin
                        dp[2][0] <= dp[1][0] + {4'b0, cost_reg[2][0]};
                    end else if (ptr == 3'd1) begin
                        // max(dp[1][1], dp[2][0])
                        if (dp[1][1] > dp[2][0]) 
                            dp[2][1] <= dp[1][1] + {4'b0, cost_reg[2][1]};
                        else 
                            dp[2][1] <= dp[2][0] + {4'b0, cost_reg[2][1]};
                    end else if (ptr == 3'd2) begin
                        // max(dp[1][2], dp[2][1])
                        if (dp[1][2] > dp[2][1]) 
                            dp[2][2] <= dp[1][2] + {4'b0, cost_reg[2][2]};
                        else 
                            dp[2][2] <= dp[2][1] + {4'b0, cost_reg[2][2]};
                        
                        // Initialize Division: (dp << 16) / 5
                        // Note: dp is 12 bits, shifting 16 makes it 28 bits in 32-bit vector
                        div_numer <= {12'd0, dp[1][2] > dp[2][1] ? dp[1][2] : dp[2][1], 8'd0, 8'd0}; // Pre-calc max logic again or use dp[2][2]? Wait, dp[2][2] is calculated in this same cycle. 
                        // Actually, let's use dp[2][2] which is updated this cycle. 
                        // Since it is non-blocking, dp[2][2] in this line is the OLD value. 
                        // To avoid combinational loop, we calculate the max explicitly or register the result.
                        // Let's fix: The logic inside ROW2 ptr==2 updates dp[2][2]. 
                        // To use it for division init in the same cycle is unsafe (cycle 0 of division).
                        // The DIVIDE state will handle initialization on its first cycle (cnt==0).
                        // So we defer initialization.
                        div_cnt <= 5'd0; 
                    end
                end

                DIVIDE: begin
                    if (div_cnt == 5'd0) begin
                        // Initialization cycle 1
                        // Get the max path cost (final dp value)
                        // We must re-evaluate the max since we are in next cycle and dp[2][2] is now valid.
                        // However, to be safe and clean, we can use the already stored dp[2][2] which was updated in ROW2 state (previous clock cycle).
                        div_numer <= {12'd0, dp[2][2], 8'd0, 8'd0}; // Shift left 16 for Q16.16 denominator 5
                        div_cnt <= 5'd1;
                        result[31:16] <= 16'd0; // Reset quotient high part
                        result[15:0] <= 16'd0;  // Reset quotient low part
                    end else if (div_cnt < 5'd17) begin
                        // 16 iterations for 16-bit result
                        // Shift-Subtract Algorithm
                        // Shift result left
                        result <= {result[30:0], 1'b0};
                        // Shift numerator left
                        div_numer <= div_numer << 1;
                        
                        // Check if div_numer (high part) >= 5
                        // div_numer is 32-bit. The shifted value is effectively 28-bit valid.
                        // We look at the top bits where the value is.
                        // Actually, simpler: compare {div_numer[31:0]} with 5 << 16?
                        // No, we shifted div_numer. So we check div_numer[31:16] (or relevant window).
                        // Since max value is ~2300. 2300 << 16 fits in 28 bits.
                        // We need to check top 16 bits of the shifted register vs 5.
                        if (div_numer[31:16] >= 5'd5) begin
                            result[0] <= 1'b1; // Set bit
                            div_numer[31:16] <= div_numer[31:16] - 5'd5;
                        end
                        div_cnt <= div_cnt + 1;
                    end
                end

                DONE: begin
                    done <= 1'b1;
                    // Result is already set in DIVIDE state
                end
            endcase
        end
    end

endmodule
