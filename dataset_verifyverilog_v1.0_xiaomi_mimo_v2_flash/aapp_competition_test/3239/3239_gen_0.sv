module pokemon_go_cost (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [31:0] N,
    input wire [9:0] P_scaled,
    output reg [63:0] cost,
    output reg done
);

    // Constants
    localparam NUM_STATES = 101;
    localparam STATE_BITS = 7;
    localparam FIXED_BITS = 16;
    
    // State machine states
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;
    localparam [1:0] FINISH = 2'd2;
    
    // Fixed-point arithmetic constants
    localparam [31:0] SCALE = 32'd65536; // 2^16 for Q16.16
    localparam [31:0] FIVE_FIXED = 32'd327680; // 5.0 * 65536
    localparam [31:0] ONE_FIXED = 32'd65536; // 1.0 * 65536
    
    // Registers for state machine
    reg [1:0] state, next_state;
    reg [31:0] n_counter; // Count down from N
    reg [6:0] i_reg, j_reg, k_reg; // Iteration counters
    reg [31:0] P_fixed; // P * 65536
    reg [31:0] q_fixed; // (1 - P) * 65536
    
    // Fixed-point arrays (packed as 101 elements of 32 bits each)
    // Using packed array for better synthesis
    reg [32*101-1:0] prob_reg; // Current probability distribution
    reg [32*101-1:0] prob_next_reg; // Next probability distribution
    reg [32*101-1:0] q_power_reg; // q^i values
    reg [32*101-1:0] C_reg; // C[i] values
    reg [32*101*101-1:0] T_reg; // Transition matrix T[i][j]
    
    reg [63:0] total_cost_fixed;
    reg [63:0] cost_step_fixed;
    reg computing;
    reg [4:0] init_counter;
    reg [6:0] step_counter;
    
    // Temporary registers for calculations
    reg [63:0] mult_temp;
    reg [63:0] sum_temp;
    reg [63:0] temp_reg;
    
    // Helper signals for array indexing
    wire [31:0] prob_i;
    wire [31:0] prob_next_j;
    wire [31:0] q_power_i;
    wire [31:0] C_i;
    wire [31:0] T_ij;
    
    // Extract elements from packed arrays
    assign prob_i = prob_reg[(i_reg * 32) +: 32];
    assign prob_next_j = prob_next_reg[(j_reg * 32) +: 32];
    assign q_power_i = q_power_reg[(i_reg * 32) +: 32];
    assign C_i = C_reg[(i_reg * 32) +: 32];
    assign T_ij = T_reg[(i_reg * 32 * 101) + (j_reg * 32) +: 32];
    
    // State transition logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start && !computing) begin
                    next_state = COMPUTE;
                end else begin
                    next_state = IDLE;
                end
            end
            COMPUTE: begin
                if (n_counter == 32'd0) begin
                    next_state = FINISH;
                end else begin
                    next_state = COMPUTE;
                end
            end
            FINISH: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end
    
    // Main state machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            cost <= 64'd0;
            computing <= 1'b0;
            n_counter <= 32'd0;
            step_counter <= 7'd0;
            init_counter <= 5'd0;
            i_reg <= 7'd0;
            j_reg <= 7'd0;
            k_reg <= 7'd0;
            total_cost_fixed <= 64'd0;
            P_fixed <= 32'd0;
            q_fixed <= 32'd0;
            prob_reg <= {101{32'd0}};
            prob_next_reg <= {101{32'd0}};
            q_power_reg <= {101{32'd0}};
            C_reg <= {101{32'd0}};
            T_reg <= {101{101{32'd0}}};
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start && !computing) begin
                        // Initialize for new computation
                        n_counter <= N;
                        step_counter <= 7'd0;
                        init_counter <= 5'd0;
                        computing <= 1'b1;
                        total_cost_fixed <= 64'd0;
                        
                        // Convert P to fixed-point: P * 65536
                        P_fixed <= {P_scaled, 22'd0}; // Scale to Q16.16
                        q_fixed <= ONE_FIXED - {P_scaled, 22'd0};
                        
                        // Initialize arrays
                        prob_reg <= {101{32'd0}};
                        prob_next_reg <= {101{32'd0}};
                        q_power_reg <= {101{32'd0}};
                        C_reg <= {101{32'd0}};
                        T_reg <= {101{101{32'd0}}};
                    end
                end
                
                COMPUTE: begin
                    if (init_counter < 5'd21) begin
                        // Initialization phase (21 cycles)
                        case (init_counter)
                            5'd0: begin
                                // prob[100] = 1.0
                                prob_reg[(100 * 32) +: 32] <= ONE_FIXED;
                            end
                            5'd1: begin
                                // q_power[0] = 1.0
                                q_power_reg[31:0] <= ONE_FIXED;
                            end
                            5'd2, 5'd3, 5'd4, 5'd5, 5'd6, 5'd7, 5'd8, 5'd9,
                            5'd10, 5'd11, 5'd12, 5'd13, 5'd14, 5'd15, 5'd16,
                            5'd17, 5'd18, 5'd19: begin
                                // Compute q_power[i] = q_power[i-1] * q
                                i_reg <= init_counter - 5'd1;
                                // Multiplication in next cycle
                            end
                            5'd20: begin
                                // Start C and T computation
                                i_reg <= 7'd0;
                            end
                        endcase
                        
                        // Multiplication for q_power (cycles 3-20)
                        if (init_counter >= 5'd2 && init_counter <= 5'd19) begin
                            // q_power[i] = q_power[i-1] * q
                            mult_temp <= q_power_i * q_fixed;
                            q_power_reg[(init_counter * 32) +: 32] <= mult_temp[31:0];
                        end
                        
                        init_counter <= init_counter + 5'd1;
                    end else if (init_counter < 5'd22) begin
                        // C[0] = 5.0
                        C_reg[31:0] <= FIVE_FIXED;
                        init_counter <= init_counter + 5'd1;
                    end else if (init_counter < 5'd23) begin
                        // Start C[i] for i > 0
                        i_reg <= 7'd1;
                        init_counter <= init_counter + 5'd1;
                    end else if (i_reg < 7'd101) begin
                        // Compute C[i] = 5.0 * q_power[i] for i > 0
                        mult_temp <= FIVE_FIXED * q_power_i;
                        C_reg[(i_reg * 32) +: 32] <= mult_temp[31:0];
                        i_reg <= i_reg + 7'd1;
                    end else if (init_counter < 5'd24) begin
                        // Start T computation
                        i_reg <= 7'd0;
                        j_reg <= 7'd0;
                        init_counter <= init_counter + 5'd1;
                    end else if (i_reg < 7'd101) begin
                        // Compute T[i][j] for all i,j
                        if (j_reg < 7'd101) begin
                            // T[i][j] = 0 for all initially
                            // We'll set specific values below
                            if (i_reg == 7'd0 && j_reg == 7'd100) begin
                                T_reg[(i_reg * 32 * 101) + (j_reg * 32) +: 32] <= ONE_FIXED;
                            end else if (i_reg > 7'd0) begin
                                if (j_reg > 7'd0 && j_reg < i_reg) begin
                                    // T[i][j] for j from 1 to i-1
                                    reg [6:0] k_temp;
                                    k_temp = i_reg - j_reg;
                                    // T[i][i-k] = P * q^(k-1)
                                    // For k = i-j, k-1 = i-j-1
                                    if (k_temp > 7'd0) begin
                                        mult_temp <= P_fixed * q_power_reg[((k_temp - 7'd1) * 32) +: 32];
                                        T_reg[(i_reg * 32 * 101) + (j_reg * 32) +: 32] <= mult_temp[31:0];
                                    end
                                end else if (j_reg == 7'd0) begin
                                    // T[i][0] = P * q^(i-1)
                                    if (i_reg > 7'd0) begin
                                        mult_temp <= P_fixed * q_power_reg[((i_reg - 7'd1) * 32) +: 32];
                                        T_reg[(i_reg * 32 * 101) + (j_reg * 32) +: 32] <= mult_temp[31:0];
                                    end
                                end else if (j_reg == 7'd100) begin
                                    // T[i][100] = q^i
                                    T_reg[(i_reg * 32 * 101) + (j_reg * 32) +: 32] <= q_power_i;
                                end
                            end
                            j_reg <= j_reg + 7'd1;
                        end else begin
                            j_reg <= 7'd0;
                            i_reg <= i_reg + 7'd1;
                        end
                    end else if (init_counter < 5'd25) begin
                        init_counter <= init_counter + 5'd1;
                        i_reg <= 7'd0;
                    end else if (n_counter > 32'd0) begin
                        // Main computation loop
                        // Step 1: Compute immediate cost
                        if (step_counter == 7'd0) begin
                            // cost_step = sum(prob[i] * C[i])
                            if (i_reg < 7'd101) begin
                                mult_temp <= prob_i * C_i;
                                temp_reg <= mult_temp[47:16]; // Q16.16 to Q32.32 for accumulation
                                i_reg <= i_reg + 7'd1;
                                // Accumulate in sum_temp
                                if (i_reg == 7'd0) begin
                                    sum_temp <= mult_temp[47:16];
                                end else begin
                                    sum_temp <= sum_temp + mult_temp[47:16];
                                end
                            end else begin
                                cost_step_fixed <= sum_temp;
                                total_cost_fixed <= total_cost_fixed + sum_temp;
                                step_counter <= 7'd1;
                                i_reg <= 7'd0;
                                j_reg <= 7'd0;
                            end
                        end
                        // Step 2: Compute prob_next[j] = sum(prob[i] * T[i][j])
                        else if (step_counter == 7'd1) begin
                            if (j_reg < 7'd101) begin
                                if (i_reg < 7'd101) begin
                                    mult_temp <= prob_i * T_ij;
                                    i_reg <= i_reg + 7'd1;
                                    // Accumulate for this j
                                    if (i_reg == 7'd0) begin
                                        temp_reg <= mult_temp[47:16];
                                    end else begin
                                        temp_reg <= temp_reg + mult_temp[47:16];
                                    end
                                end else begin
                                    prob_next_reg[(j_reg * 32) +: 32] <= temp_reg[31:0];
                                    j_reg <= j_reg + 7'd1;
                                    i_reg <= 7'd0;
                                end
                            end else begin
                                step_counter <= 7'd2;
                                i_reg <= 7'd0;
                            end
                        end
                        // Step 3: Copy prob_next to prob
                        else if (step_counter == 7'd2) begin
                            if (i_reg < 7'd101) begin
                                prob_reg[(i_reg * 32) +: 32] <= prob_next_reg[(i_reg * 32) +: 32];
                                i_reg <= i_reg + 7'd1;
                            end else begin
                                n_counter <= n_counter - 32'd1;
                                step_counter <= 7'd0;
                            end
                        end
                    end
                end
                
                FINISH: begin
                    done <= 1'b1;
                    cost <= total_cost_fixed;
                    computing <= 1'b0;
                end
            endcase
        end
    end

endmodule