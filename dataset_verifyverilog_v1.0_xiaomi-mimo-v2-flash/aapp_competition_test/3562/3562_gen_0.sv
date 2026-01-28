module GradeOptimizer (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] N,
    input wire [8:0] T,
    input wire signed [31:0] a [0:9],
    input wire signed [31:0] b [0:9],
    input wire signed [31:0] c [0:9],
    output reg signed [31:0] result,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE     = 3'd0;
    localparam [2:0] INIT     = 3'd1;
    localparam [2:0] ALLOCATE = 3'd2;
    localparam [2:0] CALC_SUM = 3'd3;
    localparam [2:0] CALC_AVG = 3'd4;
    localparam [2:0] FINISH   = 3'd5;

    // Registers
    reg [2:0] state, next_state;
    reg [8:0] total_steps;           // T * 100
    reg [8:0] step_counter;          // Current step (0 to total_steps-1)
    reg [15:0] time_t [0:9];         // Time allocated per subject (in steps)
    reg [3:0] subject_idx;           // Current subject index for allocation
    reg [3:0] max_idx;               // Subject with max marginal gain
    reg signed [31:0] max_delta;     // Max marginal gain value
    reg signed [31:0] current_delta; // Delta for current subject
    reg signed [63:0] sum_grades;    // Sum of all grades
    reg [3:0] calc_idx;              // Index for final grade calculation
    reg signed [31:0] inv_N;         // 1/N in Q16.16
    reg [8:0] max_steps_reg;         // Store max steps
    reg [3:0] N_reg;                 // Store N

    // Temporary calculation registers
    reg signed [63:0] mult_temp;
    reg signed [31:0] mult_result;
    reg signed [63:0] div_temp;
    reg signed [31:0] div_result;
    reg signed [63:0] sum_temp;
    reg [15:0] t_plus_1;
    reg signed [63:0] a_reg, b_reg, t_reg;
    
    // Loop counters
    integer i;

    // State transition logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 32'sd0;
            done <= 1'b0;
            step_counter <= 9'd0;
            subject_idx <= 4'd0;
            max_idx <= 4'd0;
            max_delta <= 32'sd0;
            current_delta <= 32'sd0;
            sum_grades <= 64'sd0;
            calc_idx <= 4'd0;
            inv_N <= 32'sd0;
            total_steps <= 9'd0;
            max_steps_reg <= 9'd0;
            N_reg <= 4'd0;
            for (i = 0; i < 10; i = i + 1) begin
                time_t[i] <= 16'd0;
            end
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    step_counter <= 9'd0;
                    subject_idx <= 4'd0;
                    for (i = 0; i < 10; i = i + 1) begin
                        time_t[i] <= 16'd0;
                    end
                    if (start) begin
                        N_reg <= N;
                        max_steps_reg <= T * 9'd100;
                        total_steps <= T * 9'd100;
                        // Precompute 1/N in Q16.16
                        case (N)
                            4'd1: inv_N <= 32'sd65536;      // 1.0
                            4'd2: inv_N <= 32'sd32768;      // 0.5
                            4'd3: inv_N <= 32'sd21845;      // 0.3333 (approx)
                            4'd4: inv_N <= 32'sd16384;      // 0.25
                            4'd5: inv_N <= 32'sd13107;      // 0.2
                            4'd6: inv_N <= 32'sd10923;      // 0.1667
                            4'd7: inv_N <= 32'sd9362;       // 0.1429
                            4'd8: inv_N <= 32'sd8192;       // 0.125
                            4'd9: inv_N <= 32'sd7282;       // 0.1111
                            4'd10: inv_N <= 32'sd6554;      // 0.1
                            default: inv_N <= 32'sd65536;
                        endcase
                    end
                end
                
                INIT: begin
                    // Initialize for allocation loop
                    step_counter <= 9'd0;
                    subject_idx <= 4'd0;
                end
                
                ALLOCATE: begin
                    if (step_counter < total_steps) begin
                        // Find subject with max marginal gain
                        if (subject_idx < N_reg) begin
                            // Calculate delta for current subject
                            // delta = 2*a*t/10000 + b/100 + a/10000
                            // t is in steps, convert to hours: t/100
                            // delta_i(t) = a_i*(2t+1)/10000 + b_i/100
                            // t is 16-bit, needs 64-bit for multiplication
                            a_reg <= { {32{a[subject_idx][31]}}, a[subject_idx] };
                            t_reg <= { {48{1'b0}}, time_t[subject_idx] };
                            b_reg <= { {32{b[subject_idx][31]}}, b[subject_idx] };
                            
                            subject_idx <= subject_idx + 4'd1;
                            
                            // Check if current is max
                            if (subject_idx == 4'd0) begin
                                max_delta <= current_delta;
                                max_idx <= 4'd0;
                            end else if (current_delta > max_delta) begin
                                max_delta <= current_delta;
                                max_idx <= subject_idx - 4'd1;
                            end
                        end else begin
                            // Done checking all subjects, allocate to max_idx
                            time_t[max_idx] <= time_t[max_idx] + 16'd1;
                            step_counter <= step_counter + 9'd1;
                            subject_idx <= 4'd0;
                        end
                    end
                end
                
                CALC_SUM: begin
                    if (calc_idx < N_reg) begin
                        // Calculate f_i(t) = a*t^2 + b*t + c
                        // t in hours = time_t[calc_idx] / 100
                        // f = a*t^2 + b*t + c
                        // t^2 = (time_t^2) / 10000
                        // t^2 needs 32-bit * 32-bit = 64-bit
                        // time_t is 16-bit, time_t^2 is 32-bit
                        // Then multiply by a (32-bit) -> 64-bit
                        // Keep Q16.16 format: shift right 16 bits
                        
                        sum_grades <= sum_grades + mult_result;
                        calc_idx <= calc_idx + 4'd1;
                    end
                end
                
                CALC_AVG: begin
                    // sum_grades is in Q16.16, divide by N (multiply by inv_N)
                    mult_temp <= sum_grades * inv_N;
                end
                
                FINISH: begin
                    result <= mult_temp[47:16];  // Q32.32 -> Q16.16
                    done <= 1'b1;
                end
            endcase
            
            // Continuous assignments for delta calculation
            // delta = a*(2t+1)/10000 + b/100
            // Compute: 2t+1 first
            t_plus_1 = (time_t[subject_idx] << 1) + 16'd1;
            // a*(2t+1) / 10000
            // a is Q16.16, (2t+1) is Q0.16 -> result Q16.32
            // Divide by 10000 (Q0.16) -> result Q16.16
            // We'll compute a*(2t+1) first (64-bit)
            mult_temp = a[subject_idx] * t_plus_1;
            // Divide by 10000 (shift right 13.322 bits, use approximation)
            // 10000 = 0x2710
            // For Q16.16 / Q0.16 = Q16.0, then shift left 16 for Q16.16
            // Actually: result = (a*(2t+1)) / 10000
            // a*(2t+1) is Q16.32, divide by 10000 (Q0.16) = Q16.16
            mult_result = mult_temp[47:16] / 10000;  // Integer division
            
            // Add b/100
            // b is Q16.16, /100 = Q16.16 * 0.01
            // 0.01 in Q16.16 = 655 (approx)
            // Better: b / 100 = b >> 6 + b >> 10 + ...
            // For now, use integer division
            div_temp = b[subject_idx] / 100;
            div_result = div_temp[31:0];
            
            current_delta = mult_result + div_result;
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: if (start) next_state = INIT;
            INIT: next_state = ALLOCATE;
            ALLOCATE: begin
                if (step_counter < total_steps) begin
                    if (subject_idx >= N_reg) next_state = ALLOCATE;
                    else next_state = ALLOCATE;
                end else begin
                    next_state = CALC_SUM;
                end
            end
            CALC_SUM: begin
                if (calc_idx < N_reg) next_state = CALC_SUM;
                else next_state = CALC_AVG;
            end
            CALC_AVG: next_state = FINISH;
            FINISH: next_state = IDLE;
            default: next_state = IDLE;
        endcase
    end

endmodule