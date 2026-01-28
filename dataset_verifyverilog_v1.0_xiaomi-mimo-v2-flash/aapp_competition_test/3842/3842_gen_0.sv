module MinDaysSolver (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [31:0] p,
    input wire [31:0] q,
    input wire [31:0] a_0,
    input wire [31:0] b_0,
    input wire [31:0] a_1,
    input wire [31:0] b_1,
    input wire [31:0] a_2,
    input wire [31:0] b_2,
    input wire [31:0] a_3,
    input wire [31:0] b_3,
    input wire [31:0] a_4,
    input wire [31:0] b_4,
    input wire [31:0] a_5,
    input wire [31:0] b_5,
    output reg [31:0] result,
    output reg done
);

    // FSM State declarations
    localparam [3:0] IDLE = 4'd0;
    localparam [3:0] INIT = 4'd1;
    localparam [3:0] CALC_SINGLE_0 = 4'd2;
    localparam [3:0] CALC_SINGLE_1 = 4'd3;
    localparam [3:0] CALC_SINGLE_2 = 4'd4;
    localparam [3:0] CALC_SINGLE_3 = 4'd5;
    localparam [3:0] CALC_SINGLE_4 = 4'd6;
    localparam [3:0] CALC_SINGLE_5 = 4'd7;
    localparam [3:0] PAIR_LOOP = 4'd8;
    localparam [3:0] CALC_PAIR = 4'd9;
    localparam [3:0] UPDATE_RESULT = 4'd10;
    localparam [3:0] FINISH = 4'd11;

    // State registers
    reg [3:0] state, next_state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd200;

    // Project data storage (registers)
    reg [31:0] a_reg [0:5];
    reg [31:0] b_reg [0:5];
    reg [31:0] p_reg, q_reg;
    reg [2:0] i_idx, j_idx;
    
    // Intermediate calculation registers
    reg [31:0] single_days;
    reg [31:0] best_days;
    
    // Fixed-point arithmetic registers
    // For division: dividend / divisor = result
    // Using Q16.16 format, division needs careful handling
    reg [63:0] dividend;
    reg [31:0] divisor;
    reg [31:0] quotient;
    reg div_start;
    reg div_busy;
    reg [5:0] div_step;
    
    // Pair calculation registers
    reg [63:0] D;      // denominator a_i*b_j - b_i*a_j
    reg [63:0] N1;     // numerator p*b_j - q*a_j
    reg [63:0] N2;     // numerator q*a_i - p*b_i
    reg [63:0] t1_temp;
    reg [63:0] t2_temp;
    reg [63:0] sum_temp;
    
    integer k;
    
    // Division module (combinational approximation for fixed-point)
    // For Q16.16 / Q16.16 -> Q16.16, we need (dividend << 16) / divisor
    // But inputs are already scaled, so for p/a_i (days) where p is Q16.16 and a_i is Q16.16:
    // Result = (p << 16) / a_i gives Q32.0 / Q16.16 -> messy.
    // Correct approach: For days = p / a_i in Q16.16:
    // Result = (p * 65536) / a_i  (since both are scaled, we need to scale result back)
    // Actually: p (Q16.16) / a_i (Q16.16) = p / a_i (unitless) * 65536 (to Q16.16)
    // So: result = (p << 16) / a_i
    
    // For pair calculation: t1 = (p*b_j - q*a_j) / (a_i*b_j - b_i*a_j)
    // Numerator and Denominator are in Q32.32 (since 32-bit * 32-bit)
    // Result t1 should be Q16.16
    // t1 = (N / D) * 65536  =>  t1 = (N * 65536) / D
    
    // State transition logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 32'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            best_days <= 32'h7FFFFFFF; // Initialize to max
            div_busy <= 1'b0;
            div_step <= 6'd0;
            for (k = 0; k < 6; k = k + 1) begin
                a_reg[k] <= 32'd0;
                b_reg[k] <= 32'd0;
            end
            p_reg <= 32'd0;
            q_reg <= 32'd0;
            i_idx <= 3'd0;
            j_idx <= 3'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    best_days <= 32'h7FFFFFFF;
                    if (start) begin
                        state <= INIT;
                    end
                end
                
                INIT: begin
                    // Store inputs
                    p_reg <= p;
                    q_reg <= q;
                    a_reg[0] <= a_0; b_reg[0] <= b_0;
                    a_reg[1] <= a_1; b_reg[1] <= b_1;
                    a_reg[2] <= a_2; b_reg[2] <= b_2;
                    a_reg[3] <= a_3; b_reg[3] <= b_3;
                    a_reg[4] <= a_4; b_reg[4] <= b_4;
                    a_reg[5] <= a_5; b_reg[5] <= b_5;
                    i_idx <= 3'd0;
                    state <= CALC_SINGLE_0;
                end
                
                // Calculate single project days
                CALC_SINGLE_0: begin
                    // Check if a_0 > 0 and b_0 > 0
                    if (a_reg[0] != 32'd0 && b_reg[0] != 32'd0) begin
                        // Days = max(p/a_0, q/b_0)
                        // Calculate p/a_0
                        div_start <= 1'b1;
                        dividend <= {32'd0, p_reg}; // p << 16
                        divisor <= a_reg[0];
                    end
                    state <= CALC_SINGLE_1;
                end
                
                CALC_SINGLE_1: begin
                    div_start <= 1'b0;
                    if (div_busy) begin
                        // Division in progress
                    end else if (div_step == 6'd33) begin
                        // Division complete
                        single_days <= quotient;
                        // Now calculate q/b_0 in parallel
                        div_start <= 1'b1;
                        dividend <= {32'd0, q_reg};
                        divisor <= b_reg[0];
                        state <= CALC_SINGLE_2;
                    end
                end
                
                CALC_SINGLE_2: begin
                    div_start <= 1'b0;
                    if (div_step == 6'd33) begin
                        // max(single_days, quotient)
                        if (quotient > single_days) begin
                            single_days <= quotient;
                        end
                        state <= CALC_SINGLE_3;
                    end
                end
                
                CALC_SINGLE_3: begin
                    // Process project 1
                    if (a_reg[1] != 32'd0 && b_reg[1] != 32'd0) begin
                        div_start <= 1'b1;
                        dividend <= {32'd0, p_reg};
                        divisor <= a_reg[1];
                    end
                    state <= CALC_SINGLE_4;
                end
                
                CALC_SINGLE_4: begin
                    div_start <= 1'b0;
                    if (div_step == 6'd33) begin
                        single_days <= quotient;
                        div_start <= 1'b1;
                        dividend <= {32'd0, q_reg};
                        divisor <= b_reg[1];
                        state <= CALC_SINGLE_5;
                    end
                end
                
                CALC_SINGLE_5: begin
                    div_start <= 1'b0;
                    if (div_step == 6'd33) begin
                        if (quotient > single_days) begin
                            single_days <= quotient;
                        end
                        // Initialize pair search
                        i_idx <= 3'd0;
                        j_idx <= 3'd1;
                        state <= PAIR_LOOP;
                    end
                end
                
                PAIR_LOOP: begin
                    // Loop through all pairs (i, j) where i < j
                    if (i_idx < 3'd5 && j_idx <= 3'd5) begin
                        // Check if i_idx < j_idx
                        if (i_idx < j_idx && a_reg[i_idx] != 32'd0 && b_reg[i_idx] != 32'd0 && 
                            a_reg[j_idx] != 32'd0 && b_reg[j_idx] != 32'd0) begin
                            state <= CALC_PAIR;
                        end else begin
                            // Move to next pair
                            j_idx <= j_idx + 3'd1;
                            if (j_idx == 3'd5) begin
                                i_idx <= i_idx + 3'd1;
                                j_idx <= i_idx + 3'd2;
                            end
                        end
                    end else begin
                        state <= UPDATE_RESULT;
                    end
                end
                
                CALC_PAIR: begin
                    // Calculate D = a_i*b_j - b_i*a_j (in Q32.32)
                    // Calculate N1 = p*b_j - q*a_j
                    // Calculate N2 = q*a_i - p*b_i
                    // Using 64-bit multiplication
                    D <= (a_reg[i_idx] * b_reg[j_idx]) - (b_reg[i_idx] * a_reg[j_idx]);
                    N1 <= (p_reg * b_reg[j_idx]) - (q_reg * a_reg[j_idx]);
                    N2 <= (q_reg * a_reg[i_idx]) - (p_reg * b_reg[i_idx]);
                    state <= UPDATE_RESULT;
                end
                
                UPDATE_RESULT: begin
                    // Check if D != 0 and N1, N2 have correct signs for t1, t2 >= 0
                    if (D != 64'd0 && N1 >= 64'd0 && N2 >= 64'd0) begin
                        // Calculate t1 = (N1 * 65536) / D
                        // Calculate t2 = (N2 * 65536) / D
                        // Total = t1 + t2
                        // This is complex in hardware. 
                        // Simplified: Check if t1 and t2 are valid
                        // t1 >= 0, t2 >= 0
                        // We can check sign of N1/N2 vs D
                        if (((N1[63] ^ D[63]) == 0) && ((N2[63] ^ D[63]) == 0)) begin
                            // Calculate (N1 + N2) / D * 65536 = (p*b_j - q*a_j + q*a_i - p*b_i) / (a_i*b_j - b_i*a_j) * 65536
                            // = (p*(b_j - b_i) + q*(a_i - a_j)) / (a_i*b_j - b_i*a_j) * 65536
                            // Let's just calculate t1 + t2 directly
                            // t1 + t2 = (N1 + N2) / D (but need scaling)
                            // Actually, since t1 = N1/D, t2 = N2/D, t1 + t2 = (N1 + N2) / D
                            // But D is Q32.32, N1, N2 are Q32.32, result needs Q16.16
                            // Result = ((N1 + N2) * 65536) / D
                            dividend <= (N1 + N2) << 16;
                            divisor <= D[47:16]; // Take middle 32 bits of D (Q32.32 -> Q16.16 approx)
                            div_start <= 1'b1;
                            state <= CALC_PAIR + 1; // Need intermediate state
                        end
                    end
                    // Move to next pair
                    j_idx <= j_idx + 3'd1;
                    if (j_idx == 3'd5) begin
                        i_idx <= i_idx + 3'd1;
                        j_idx <= i_idx + 3'd2;
                    end
                    state <= PAIR_LOOP;
                end
                
                FINISH: begin
                    // Final result
                    if (single_days < best_days) begin
                        result <= single_days;
                    end else begin
                        result <= best_days;
                    end
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
            
            // Divider State Machine (runs in parallel)
            if (div_start && !div_busy) begin
                div_busy <= 1'b1;
                div_step <= 6'd0;
                quotient <= 32'd0;
            end else if (div_busy) begin
                if (div_step < 6'd33) begin
                    // Restoring division algorithm
                    if (dividend >= divisor) begin
                        dividend <= dividend - divisor;
                        quotient <= (quotient << 1) | 1'b1;
                    end else begin
                        quotient <= quotient << 1;
                    end
                    dividend <= dividend << 1;
                    div_step <= div_step + 6'd1;
                end else begin
                    div_busy <= 1'b0;
                    div_step <= 6'd0;
                end
            end
            
            // Cycle counter
            if (start || state != IDLE) begin
                cycle_count <= cycle_count + 8'd1;
                if (cycle_count >= MAX_CYCLES) begin
                    state <= FINISH;
                end
            end
        end
    end
endmodule