module GradeMaximizer(
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

    // State declarations
    localparam [2:0] IDLE      = 3'd0;
    localparam [2:0] INIT      = 3'd1;
    localparam [2:0] ALLOCATE  = 3'd2;
    localparam [2:0] CALC      = 3'd3;
    localparam [2:0] FINISH    = 3'd4;

    reg [2:0] state, next_state;

    // Coefficient registers
    reg signed [31:0] a_reg [0:9];
    reg signed [31:0] b_reg [0:9];
    reg signed [31:0] c_reg [0:9];

    // Time counters (Q0.16 format - integer steps)
    reg [15:0] time_count [0:9];

    // Allocation loop counters
    reg [15:0] step_counter;
    reg [3:0] subject_counter;

    // Marginal gain calculation
    reg signed [31:0] delta [0:9];
    reg signed [31:0] max_delta;
    reg [3:0] max_index;

    // Final grade calculation
    reg signed [31:0] grade_sum;
    reg signed [31:0] current_grade;

    // Precomputed 1/N values (Q16.16)
    reg signed [31:0] inv_N [0:10];

    // Cycle counter for timeout
    reg [15:0] cycle_count;
    localparam [15:0] MAX_CYCLES = 16'd30000;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            done <= 1'b0;
            result <= 32'd0;
            cycle_count <= 16'd0;

            // Initialize all registers
            integer i;
            for (i = 0; i < 10; i = i + 1) begin
                a_reg[i] <= 32'd0;
                b_reg[i] <= 32'd0;
                c_reg[i] <= 32'd0;
                time_count[i] <= 16'd0;
            end
            step_counter <= 16'd0;
            subject_counter <= 4'd0;
            grade_sum <= 32'd0;
            current_grade <= 32'd0;
        end else begin
            state <= next_state;
            cycle_count <= cycle_count + 16'd1;

            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        next_state <= INIT;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                INIT: begin
                    // Store coefficients
                    integer i;
                    for (i = 0; i < 10; i = i + 1) begin
                        a_reg[i] <= a[i];
                        b_reg[i] <= b[i];
                        c_reg[i] <= c[i];
                    end

                    // Initialize time counters
                    for (i = 0; i < 10; i = i + 1) begin
                        time_count[i] <= 16'd0;
                    end

                    // Precompute 1/N values
                    inv_N[1] = 32'd65536;  // 1/1 = 1.0
                    inv_N[2] = 32'd32768;  // 1/2 = 0.5
                    inv_N[3] = 32'd21845;  // 1/3 ≈ 0.3333
                    inv_N[4] = 32'd16384;  // 1/4 = 0.25
                    inv_N[5] = 32'd13107;  // 1/5 = 0.2
                    inv_N[6] = 32'd10922;  // 1/6 ≈ 0.1667
                    inv_N[7] = 32'd9362;   // 1/7 ≈ 0.1429
                    inv_N[8] = 32'd8192;   // 1/8 = 0.125
                    inv_N[9] = 32'd7281;   // 1/9 ≈ 0.1111
                    inv_N[10] = 32'd6553;  // 1/10 = 0.1

                    step_counter <= 16'd0;
                    next_state <= ALLOCATE;
                end

                ALLOCATE: begin
                    // Calculate marginal gains for all subjects
                    integer i;
                    for (i = 0; i < N; i = i + 1) begin
                        // delta_i = a_i*(2*t+1)/10000 + b_i/100
                        // = (a_i*(2*t+1) + 100*b_i) / 10000
                        // In Q16.16: multiply by 65536/10000 = 6.5536
                        // But we'll do it as: (a_i*(2*t+1) << 16) / 10000 + (b_i << 16) / 100
                        
                        reg signed [63:0] temp1;
                        reg signed [63:0] temp2;
                        
                        // Calculate 2*t+1 (Q0.16)
                        reg [15:0] two_t_plus_one = (time_count[i] << 1) + 16'd1;
                        
                        // a_i * (2*t+1) in Q32.32
                        temp1 = $signed(a_reg[i]) * $signed(two_t_plus_one);
                        
                        // 100 * b_i in Q32.32
                        temp2 = $signed(b_reg[i]) * 32'd100;
                        
                        // Sum and divide by 10000 (shift right 13 + 1)
                        // (since 10000 = 100 * 100, and we have Q32.32)
                        delta[i] = (temp1 + temp2) >> 14;
                    end

                    // Find subject with maximum delta
                    max_delta = delta[0];
                    max_index = 4'd0;
                    for (i = 1; i < N; i = i + 1) begin
                        if (delta[i] > max_delta) begin
                            max_delta = delta[i];
                            max_index = i;
                        end
                    end

                    // Increment time for selected subject
                    time_count[max_index] <= time_count[max_index] + 16'd1;

                    // Increment step counter
                    step_counter <= step_counter + 16'd1;

                    // Check if all steps completed
                    if (step_counter == (T * 100) || cycle_count >= MAX_CYCLES) begin
                        next_state <= CALC;
                        subject_counter <= 4'd0;
                        grade_sum <= 32'd0;
                    end else begin
                        next_state <= ALLOCATE;
                    end
                end

                CALC: begin
                    // Calculate grade for current subject
                    integer i = subject_counter;
                    
                    // f_i(t) = a_i*t^2 + b_i*t + c_i
                    // t is in steps (Q0.16), so t/100 is Q0.16 / 100 = Q0.24
                    // We'll calculate in Q16.16:
                    // t_scaled = t / 100 (Q0.16 -> Q0.24, but we'll use Q16.16)
                    // Actually: t in steps (0-24000), so t/100 is hours (0-240)
                    // We'll represent t_hours = t_steps / 100 as Q8.8 (8 integer, 8 fractional)
                    // But for simplicity, we'll use Q16.16 throughout
                    
                    reg [15:0] t_steps = time_count[i];
                    reg signed [31:0] t_hours = {16'd0, t_steps} >> 7;  // Divide by 128 (approx 100)
                    
                    reg signed [63:0] term1;
                    reg signed [63:0] term2;
                    reg signed [63:0] term3;
                    
                    // a_i * t^2
                    term1 = $signed(a_reg[i]) * $signed(t_hours) * $signed(t_hours);
                    term1 = term1 >> 16;  // Scale back to Q16.16
                    
                    // b_i * t
                    term2 = $signed(b_reg[i]) * $signed(t_hours);
                    term2 = term2 >> 16;  // Scale back to Q16.16
                    
                    // c_i
                    term3 = c_reg[i];
                    
                    current_grade = term1 + term2 + term3;
                    grade_sum = grade_sum + current_grade;
                    
                    // Move to next subject
                    subject_counter <= subject_counter + 4'd1;
                    
                    if (subject_counter == N) begin
                        // Calculate average
                        result <= grade_sum * inv_N[N];
                        next_state <= FINISH;
                    end else begin
                        next_state <= CALC;
                    end
                end

                FINISH: begin
                    done <= 1'b1;
                    next_state <= IDLE;
                end

                default: begin
                    next_state <= IDLE;
                    done <= 1'b0;
                end
            endcase
        end
    end

endmodule