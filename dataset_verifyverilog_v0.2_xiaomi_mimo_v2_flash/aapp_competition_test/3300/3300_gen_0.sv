module cheetah_pack_minimum (
    input clk,
    input rst_n,
    input start,
    input [3:0] num_cheetahs,
    input [15:0] start_times [0:3],
    input [15:0] velocities [0:3],
    output reg [31:0] min_pack_length,
    output reg done
);

    // Parameters
    localparam IDLE = 4'd0;
    localparam INIT = 4'd1;
    localparam FIND_INTERSECTION_SETUP = 4'd2;
    localparam FIND_INTERSECTION_COMPUTE = 4'd3;
    localparam FIND_INTERSECTION_STORE = 4'd4;
    localparam EVALUATE_CRIT_TIMES = 4'd5;
    localparam EVALUATE_CALC = 4'd6;
    localparam EVALUATE_UPDATE = 4'd7;
    localparam DONE = 4'd8;

    // State register
    reg [3:0] state;

    // Internal registers
    reg [3:0] N_reg;
    reg signed [31:0] t_k [0:3]; // Q16.16 stored in 32-bit signed
    reg signed [31:0] v_k [0:3]; // Q16.16 stored in 32-bit signed
    
    // Critical times storage: 4 release times + max 6 intersection times = 10 total
    // We store Q16.16 format
    reg signed [31:0] crit_times [0:9];
    reg [3:0] num_crit_times;
    
    // Indices
    reg [2:0] i_idx; // outer loop index 0-3
    reg [2:0] j_idx; // inner loop index 0-3
    
    // Flags
    reg proc_done;
    
    // Divider signals
    reg div_start;
    reg div_running;
    wire div_done;
    reg signed [63:0] div_numer;
    reg signed [31:0] div_denom;
    wire signed [63:0] div_quotient;
    
    // Computation registers
    reg signed [63:0] pos [0:3]; // Current positions (Q32.32 effectively)
    reg [3:0] eval_idx;
    reg [3:0] time_idx;
    reg signed [31:0] current_time;
    reg signed [31:0] max_pos;
    reg signed [31:0] min_pos;
    reg signed [63:0] temp_sum;
    
    // Temporary registers for intersection calculation
    reg signed [63:0] calc_numer_l; // v_i * t_i
    reg signed [63:0] calc_numer_r; // v_j * t_j
    reg signed [63:0] calc_diff;
    reg signed [63:0] calc_denom;  // v_i - v_j
    reg signed [63:0] temp_result;

    // Sequential Restoring Divider Module (Internal)
    // Handles signed 64-bit / 32-bit -> 64-bit quotient
    reg signed [63:0] rem;
    reg signed [63:0] quo;
    reg signed [63:0] temp_denom;
    reg [6:0] div_cnt; // 64 cycles
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            div_done <= 1'b0;
            div_running <= 1'b0;
            quo <= 0;
            rem <= 0;
        end else begin
            if (div_start && !div_running) begin
                // Initialize signed division
                div_running <= 1'b1;
                div_done <= 1'b0;
                div_cnt <= 0;
                
                if (div_denom == 0) begin
                    // Divide by zero: set done immediately, result undefined but let's cap it
                    div_done <= 1'b1;
                    div_running <= 1'b0;
                    quo <= 0;
                end else begin
                    // Handle signs
                    // Numerator: div_numer (64 bit)
                    // Denominator: div_denom (32 bit)
                    if (div_numer[63]) div_numer[63:0] <= -div_numer[63:0];
                    if (div_denom[31]) temp_denom[63:0] <= -{32'b0, div_denom};
                    else temp_denom[63:0] <= {32'b0, div_denom};
                    
                    rem <= div_numer[63:0]; // Actually just shifted, handled in loop
                    quo <= 0;
                end
            end else if (div_running) begin
                // Perform 1 step of restoring division per cycle
            end
        end
    end

    // Main FSM Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            min_pack_length <= 0;
            num_crit_times <= 0;
            div_running <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= INIT;
                    end
                end

                INIT: begin
                    // Store inputs
                    N_reg <= (num_cheetahs > 4) ? 4 : num_cheetahs;
                    // Convert start and velocity to 32-bit signed for internal use (Q16.16 -> Q32.32 shift or keep Q16.16)
                    // Let's keep Q16.16 in upper 16 bits of 32-bit vector (standard Q16.16)
                    // Input is [15:0], we need to shift left 16 to get Q16.16 in integer math context
                    t_k[0] <= {start_times[0], 16'b0};
                    t_k[1] <= {start_times[1], 16'b0};
                    t_k[2] <= {start_times[2], 16'b0};
                    t_k[3] <= {start_times[3], 16'b0};
                    v_k[0] <= {velocities[0], 16'b0};
                    v_k[1] <= {velocities[1], 16'b0};
                    v_k[2] <= {velocities[2], 16'b0};
                    v_k[3] <= {velocities[3], 16'b0};
                    
                    // Reset index
                    num_crit_times <= 0;
                    i_idx <= 0;
                    j_idx <= 0;
                    
                    // Add release times as critical times initially
                    state <= FIND_INTERSECTION_SETUP;
                end

                FIND_INTERSECTION_SETUP: begin
                    // Add release times first to crit_times (0 to N-1)
                    if (num_crit_times < N_reg) begin
                        crit_times[num_crit_times] <= t_k[num_crit_times];
                        num_crit_times <= num_crit_times + 1;
                    end else if (i_idx < N_reg - 1) begin
                        // Start pairs
                        state <= FIND_INTERSECTION_COMPUTE;
                        j_idx <= i_idx + 1;
                    end else begin
                        // Done finding intersections, proceed to evaluate
                        // Reset indices for evaluation
                        eval_idx <= 0;
                        time_idx <= 0;
                        min_pack_length <= 0; // Reset result
                        state <= EVALUATE_CRIT_TIMES;
                    end
                end

                FIND_INTERSECTION_COMPUTE: begin
                    // Check if velocities equal
                    if (v_k[i_idx] == v_k[j_idx]) begin
                        // Parallel lines, no intersection
                        j_idx <= j_idx + 1;
                        if (j_idx + 1 >= N_reg) begin
                            i_idx <= i_idx + 1;
                            state <= FIND_INTERSECTION_SETUP;
                        end
                    end else begin
                        // Start Divider: t = (v_i*t_i - v_j*t_j) / (v_i - v_j)
                        // 1. Calculate v_i * t_i
                        // Note: Q16.16 * Q16.16 = Q32.32. Result fits in 64-bit.
                        // We take upper 32 bits (Q32.32 -> Q16.16 shift right 16) or keep Q32.32 for precision.
                        // Let's compute full product 64-bit.
                        calc_numer_l <= v_k[i_idx] * t_k[i_idx]; // 64-bit result
                        calc_numer_r <= v_k[j_idx] * t_k[j_idx]; // 64-bit result
                        calc_denom <= v_k[i_idx] - v_k[j_idx];   // 32-bit difference
                        // We need a state to wait for multiplication (if combinational) or just do it.
                        state <= FIND_INTERSECTION_STORE;
                    end
                end

                FIND_INTERSECTION_STORE: begin
                    // Compute difference
                    calc_diff <= calc_numer_l - calc_numer_r;
                    // Now start division
                    div_numer <= calc_numer_l - calc_numer_r;
                    div_denom <= calc_denom;
                    
                    // Reset divider control
                    div_cnt <= 0;
                    div_running <= 1'b1;
                    rem <= calc_numer_l - calc_numer_r;
                    quo <= 0;
                    // Handle signs immediately for the restoring algorithm
                    // Determine final sign
                    // If Numer neg XOR Denom neg -> Result neg
                    // We'll compute positive values and apply sign at end
                    state <= FIND_INTERSECTION_COMPUTE; // Reuse state for waiting, or dedicated wait state
                end

                // Divider State
                4'hF: begin
                    // The `else if (div_running)` block in the sequential block handles the math.
                end
            endcase
        end
    end

    // Refined State Machine with Explicit Divider Steps
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            min_pack_length <= 0;
            div_running <= 0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        // Initialize inputs
                        N_reg <= (num_cheetahs > 4) ? 4 : num_cheetahs;
                        // Sign extend/Expand inputs to 32-bit Q16.16
                        t_k[0] <= {{16{start_times[0][15]}}, start_times[0]};
                        t_k[1] <= {{16{start_times[1][15]}}, start_times[1]};
                        t_k[2] <= {{16{start_times[2][15]}}, start_times[2]};
                        t_k[3] <= {{16{start_times[3][15]}}, start_times[3]};
                        v_k[0] <= {{16{velocities[0][15]}}, velocities[0]};
                        v_k[1] <= {{16{velocities[1][15]}}, velocities[1]};
                        v_k[2] <= {{16{velocities[2][15]}}, velocities[2]};
                        v_k[3] <= {{16{velocities[3][15]}}, velocities[3]};
                        
                        num_crit_times <= 0;
                        i_idx <= 0;
                        state <= INIT;
                    end
                end

                INIT: begin
                    // Add release times to critical list
                    if (num_crit_times < N_reg) begin
                        crit_times[num_crit_times] <= t_k[num_crit_times];
                        num_crit_times <= num_crit_times + 1;
                    end else begin
                        // Done adding release times, start pair iterations
                        i_idx <= 0;
                        state <= FIND_INTERSECTION_SETUP;
                    end
                end

                FIND_INTERSECTION_SETUP: begin
                    if (i_idx < N_reg - 1) begin
                        j_idx <= i_idx + 1;
                        state <= FIND_INTERSECTION_COMPUTE;
                    end else begin
                        // All pairs done, move to evaluation
                        time_idx <= 0;
                        min_pack_length <= 0; // Initialize max difference as 0
                        state <= EVALUATE_CRIT_TIMES;
                    end
                end

                FIND_INTERSECTION_COMPUTE: begin
                    // Check if v_i == v_j
                    if (v_k[i_idx] == v_k[j_idx]) begin
                        // Parallel, no intersect
                        if (j_idx + 1 >= N_reg) begin
                            i_idx <= i_idx + 1;
                            state <= FIND_INTERSECTION_SETUP;
                        end else begin
                            j_idx <= j_idx + 1;
                        end
                    end else begin
                        // Setup Division: t = (v_i*t_i - v_j*t_j) / (v_i - v_j)
                        // 1. Setup Numerator (Product A - Product B)
                        calc_numer_l <= v_k[i_idx] * t_k[i_idx];
                        calc_numer_r <= v_k[j_idx] * t_k[j_idx];
                        state <= 4'hA; // Next cycle
                    end
                end
                
                4'hA: begin // Wait state for Mult to settle (or just logic)
                    // Subtract
                    temp_result <= calc_numer_l - calc_numer_r; // 64-bit signed
                    // Get Denom
                    calc_denom <= v_k[i_idx] - v_k[j_idx];     // 32-bit signed
                    state <= 4'hB;
                end
                
                4'hB: begin // Setup Division Loop
                    // Determine sign
                    if (temp_result[63]) div_numer <= -temp_result; else div_numer <= temp_result;
                    if (calc_denom[31]) div_denom <= -calc_denom; else div_denom <= calc_denom;
                    if ((temp_result[63] ^ calc_denom[31])) crit_times[0][0] <= 1'b1; else crit_times[0][0] <= 1'b0;
                    // Init Divider
                    rem <= div_numer; // Load initial numerator (now positive)
                    quo <= 0;
                    div_cnt <= 0;
                    state <= 4'hC; // Loop State
                end

                4'hC: begin // Divider Loop (Restoring)
                    // 64-bit wide divider
                    if (div_cnt < 64) begin
                        // Shift {rem, quo} left by 1
                        reg [63:0] shift_rem;
                        shift_rem = {rem[62:0], quo[63]};
                        if (shift_rem[63:32] >= div_denom[31:0]) begin
                            rem <= shift_rem - {32'b0, div_denom};
                            quo <= {quo[62:0], 1'b1};
                        end else begin
                            rem <= shift_rem;
                            quo <= {quo[62:0], 1'b0};
                        end
                        div_cnt <= div_cnt + 1;
                    end else begin
                        // Division Done
                        if (crit_times[0][0]) quo <= -quo;
                        // Store result
                        if (num_crit_times < 10) begin
                            crit_times[num_crit_times] <= quo[47:16];
                            num_crit_times <= num_crit_times + 1;
                        end
                        // Next pair
                        if (j_idx + 1 >= N_reg) begin
                            i_idx <= i_idx + 1;
                            state <= FIND_INTERSECTION_SETUP;
                        end else begin
                            j_idx <= j_idx + 1;
                            state <= FIND_INTERSECTION_COMPUTE;
                        end
                    end
                end

                EVALUATE_CRIT_TIMES: begin
                    if (time_idx < num_crit_times) begin
                        current_time <= crit_times[time_idx];
                        // Reset min/max for this time step
                        max_pos <= -64'h7FFFFFFFFFFFFFFF; // Min int
                        min_pos <= 64'h7FFFFFFFFFFFFFFF;  // Max int
                        eval_idx <= 0;
                        state <= EVALUATE_CALC;
                    end else begin
                        state <= DONE;
                    end
                end

                EVALUATE_CALC: begin
                    // For current cheetah `eval_idx`
                    if (eval_idx < N_reg) begin
                        // Check if running: current_time >= t_k[eval_idx]
                        if (current_time >= t_k[eval_idx]) begin
                            // Calculate pos = v * (t - t_k)
                            temp_sum <= current_time - t_k[eval_idx]; // 32-bit, Q16.16
                            state <= 4'hD; // Mult state
                        end else begin
                            // Not running, skip
                            eval_idx <= eval_idx + 1;
                            state <= EVALUATE_CALC; // Stay in loop
                        end
                    end else begin
                        // Done evaluating this time step
                        // Compute diff
                        if (max_pos !== -64'h7FFFFFFFFFFFFFFF && min_pos !== 64'h7FFFFFFFFFFFFFFF) begin
                             temp_sum <= max_pos - min_pos;
                             state <= EVALUATE_UPDATE;
                        end else begin
                             // No cheetahs valid, loop next time
                             time_idx <= time_idx + 1;
                             state <= EVALUATE_CRIT_TIMES;
                        end
                    end
                end

                4'hD: begin // Multiplication state for pos calculation
                    // pos = v_k[eval_idx] * (current_time - t_k[eval_idx])
                    temp_sum <= v_k[eval_idx] * temp_sum[31:0]; // 32x32->64
                    state <= 4'hE;
                end

                4'hE: begin // Store position state
                    // Update max
                    if (temp_sum > max_pos) max_pos <= temp_sum;
                    // Update min
                    if (temp_sum < min_pos) min_pos <= temp_sum;
                    eval_idx <= eval_idx + 1;
                    state <= EVALUATE_CALC;
                end

                EVALUATE_UPDATE: begin
                    // Compare with current min_pack_length
                    if (temp_sum[47:16] > min_pack_length) min_pack_length <= temp_sum[47:16];
                    time_idx <= time_idx + 1;
                    state <= EVALUATE_CRIT_TIMES;
                end

                DONE: begin
                    done <= 1'b1;
                    if (!start) begin // Wait for start to go low to reset or stay
                        state <= IDLE;
                    end
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule