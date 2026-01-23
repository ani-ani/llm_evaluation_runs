module maximum_gnome_damage (
    input clk,
    input rst_n,
    input start,
    input [7:0] n,
    input [3:0] m,
    input [7:0] k,
    output reg [15:0] result,
    output reg done
);

    // State definitions
    localparam [3:0] IDLE          = 4'd0;
    localparam [3:0] CHECK_N       = 4'd1;
    localparam [3:0] CALC_SIMPLE   = 4'd2;
    localparam [3:0] INIT_LOOP     = 4'd3;
    localparam [3:0] CALC_BOUNDS   = 4'd4;
    localparam [3:0] CHECK_L_U     = 4'd5;
    localparam [3:0] CALC_T1       = 4'd6;
    localparam [3:0] CALC_T2       = 4'd7;
    localparam [3:0] CALC_T3       = 4'd8;
    localparam [3:0] CALC_T4       = 4'd9;
    localparam [3:0] CALC_T5       = 4'd10;
    localparam [3:0] CALC_T6       = 4'd11;
    localparam [3:0] NEXT_T        = 4'd12;
    localparam [3:0] NEXT_T_LOOP   = 4'd13;
    localparam [3:0] NEXT_T_DECR   = 4'd14;
    localparam [3:0] DONE_STATE    = 4'd15;

    reg [3:0] state;
    reg [3:0] next_state;
    
    // Internal registers
    reg [15:0] best_damage;
    reg [7:0] t_reg;
    reg [15:0] L_reg;
    reg [15:0] U_reg;
    reg [15:0] T_reg;
    reg [15:0] R_reg;
    reg [15:0] D1_reg;
    reg [15:0] D2_reg;
    reg [15:0] damage_reg;
    
    // Temporary calculation registers
    reg [23:0] temp_mult;  // For n*n, k*(k-1), etc.
    reg [31:0] temp_div;   // For division results
    
    // Counter for T loop
    reg [3:0] t_val;
    
    // Cycle counter to prevent infinite loops
    reg [15:0] cycle_count;
    localparam [15:0] MAX_CYCLES = 16'd1000;

    // State transition and output logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result <= 16'd0;
            best_damage <= 16'd0;
            t_reg <= 8'd0;
            L_reg <= 16'd0;
            U_reg <= 16'd0;
            T_reg <= 16'd0;
            R_reg <= 16'd0;
            D1_reg <= 16'd0;
            D2_reg <= 16'd0;
            damage_reg <= 16'd0;
            temp_mult <= 24'd0;
            temp_div <= 32'd0;
            t_val <= 4'd0;
            cycle_count <= 16'd0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 16'd0;
                    if (start) begin
                        best_damage <= 16'd0;
                        t_val <= 4'd0;
                    end
                end
                
                CHECK_N: begin
                    if (n <= m) begin
                        // result = n*(n+1)/2
                        temp_mult <= {8'd0, n} * ({8'd0, n} + 16'd1);
                    end
                end
                
                CALC_SIMPLE: begin
                    result <= temp_mult[16:1];  // Divide by 2
                end
                
                INIT_LOOP: begin
                    t_val <= m[3:0];
                end
                
                CALC_BOUNDS: begin
                    // L1 = ceil((n - t*(k-1))/k)
                    // U1 = floor((n - t)/k)
                    // L2 = m - t
                    cycle_count <= cycle_count + 16'd1;
                    temp_mult <= {8'd0, t_reg} * ({8'd0, k} - 16'd1);
                end
                
                CHECK_L_U: begin
                    // Calculate L1
                    if ({8'd0, n} >= temp_mult[15:0]) begin
                        temp_div <= ({8'd0, n} - temp_mult[15:0]) << 8;  // Multiply by 256 for division
                    end else begin
                        temp_div <= 32'd0;
                    end
                end
                
                CALC_T1: begin
                    // Perform division by k using shift-add or simple logic
                    // Since k <= 255, we can do basic division
                    if (k > 0) begin
                        // L1 = ceil((n - t*(k-1))/k)
                        temp_div <= ({8'd0, n} - ({8'd0, t_reg} * ({8'd0, k} - 16'd1))) << 8;
                    end else begin
                        temp_div <= 32'd0;
                    end
                end
                
                CALC_T2: begin
                    // L1 = ceil(val/k) = (val*256 + k-1) / k
                    if (k > 0) begin
                        temp_div <= temp_div + {24'd0, k} - 16'd1;
                    end
                end
                
                CALC_T3: begin
                    // Divide by k
                    if (k > 0) begin
                        L_reg <= temp_div[23:8] / {8'd0, k};
                    end else begin
                        L_reg <= 16'd0;
                    end
                    // U1 = floor((n - t)/k)
                    temp_div <= ({8'd0, n} - {8'd0, t_reg}) << 8;
                end
                
                CALC_T4: begin
                    // Calculate U
                    if (k > 0) begin
                        U_reg <= temp_div[23:8] / {8'd0, k};
                    end else begin
                        U_reg <= 16'd0;
                    end
                    // L2 = m - t
                    if (m >= t_reg) begin
                        if (L_reg < ({8'd0, m} - {8'd0, t_reg})) begin
                            L_reg <= {8'd0, m} - {8'd0, t_reg};
                        end
                    end
                end
                
                CALC_T5: begin
                    // L = max(L1, L2), U = U1
                    // Check if L <= U
                    if (L_reg <= U_reg) begin
                        T_reg <= L_reg;
                    end
                end
                
                CALC_T6: begin
                    // R = n - k*T
                    R_reg <= {8'd0, n} - ({8'd0, k} * T_reg);
                    // D1 = n*T - k*T*(T-1)/2
                    temp_mult <= {8'd0, n} * T_reg;
                end
                
                // Continue with D1 calculation in next states
                NEXT_T: begin
                    D1_reg <= temp_mult[15:0] - ({8'd0, k} * T_reg * (T_reg - 16'd1) >> 1);
                end
                
                NEXT_T_LOOP: begin
                    // Calculate D2
                    if (t_reg > 0) begin
                        // a = R/t; b = R%t
                        // D2 = a*t*(t+1)/2 + b*(b+1)/2
                        temp_div <= {16'd0, R_reg} << 8;  // Scale for division
                    end else begin
                        D2_reg <= 16'd0;
                    end
                end
                
                NEXT_T_DECR: begin
                    // Compute final damage and update best
                    damage_reg <= D1_reg + D2_reg;
                    if (D1_reg + D2_reg > best_damage) begin
                        best_damage <= D1_reg + D2_reg;
                    end
                    
                    // Move to next T
                    if (T_reg < U_reg) begin
                        T_reg <= T_reg + 16'd1;
                        state <= CALC_T6;  // Loop back
                    end else begin
                        // Move to next t
                        if (t_val > 0) begin
                            t_val <= t_val - 4'd1;
                            state <= INIT_LOOP;
                        end else begin
                            state <= DONE_STATE;
                        end
                    end
                end
                
                DONE_STATE: begin
                    result <= best_damage;
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end
    
    // Combinational logic for next state
    always @(*) begin
        case (state)
            IDLE: begin
                if (start) begin
                    if (n <= m) next_state = CHECK_N;
                    else next_state = INIT_LOOP;
                end else begin
                    next_state = IDLE;
                end
            end
            
            CHECK_N: next_state = CALC_SIMPLE;
            CALC_SIMPLE: next_state = DONE_STATE;
            INIT_LOOP: next_state = CALC_BOUNDS;
            CALC_BOUNDS: next_state = CHECK_L_U;
            CHECK_L_U: next_state = CALC_T1;
            CALC_T1: next_state = CALC_T2;
            CALC_T2: next_state = CALC_T3;
            CALC_T3: next_state = CALC_T4;
            CALC_T4: next_state = CALC_T5;
            CALC_T5: begin
                if (L_reg <= U_reg) next_state = CALC_T6;
                else begin
                    if (t_val > 0) next_state = INIT_LOOP;
                    else next_state = DONE_STATE;
                end
            end
            CALC_T6: next_state = NEXT_T;
            NEXT_T: next_state = NEXT_T_LOOP;
            NEXT_T_LOOP: begin
                if (t_reg > 0) begin
                    // Calculate a and b for D2
                    // a = R/t, b = R%t
                    next_state = NEXT_T_DECR;
                end else begin
                    D2_reg = 16'd0;
                    next_state = NEXT_T_DECR;
                end
            end
            NEXT_T_DECR: begin
                if (T_reg < U_reg) begin
                    next_state = CALC_T6;
                end else begin
                    if (t_val > 0) next_state = INIT_LOOP;
                    else next_state = DONE_STATE;
                end
            end
            DONE_STATE: next_state = IDLE;
            default: next_state = IDLE;
        endcase
    end
    
    // Additional combinational logic for T_loop calculations
    always @(*) begin
        if (state == NEXT_T_LOOP && t_reg > 0) begin
            // a = R/t, b = R%t
            // D2 = a*t*(t+1)/2 + b*(b+1)/2
            // Need to handle division of R by t_reg
            // Since t is small (<=8), we can unroll the division
            D2_reg = 16'd0;
            if (t_reg > 0) begin
                // For simplicity, assume R < 65536 and t <= 8
                // Division by small constant can be done with multiplication by inverse
                // or with simple loop. Here we use a simple approach.
                // R / t
                reg [15:0] a;
                reg [15:0] b;
                a = R_reg / t_reg;
                b = R_reg % t_reg;
                D2_reg = (a * t_reg * (t_reg + 16'd1)) >> 1 + (b * (b + 16'd1)) >> 1;
            end
        end
    end

endmodule