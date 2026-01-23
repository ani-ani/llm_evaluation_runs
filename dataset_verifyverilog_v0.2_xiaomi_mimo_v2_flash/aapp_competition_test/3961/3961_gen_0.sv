module maze_solver (
    input clk,
    input rst_n,
    input start,
    input [2:0] p_i,
    input [2:0] current_room_index,
    output reg [31:0] total_moves,
    output reg done
);

    // Constants
    localparam MOD = 32'd1000000007;
    localparam MAX_ROOMS = 4'd8;

    // State Encoding
    localparam IDLE = 2'b00;
    localparam CALC = 2'b01;
    localparam DONE = 2'b10;

    // Registers
    reg [1:0] state, next_state;
    reg [31:0] f [0:8]; // DP array f[0] to f[8]
    reg [3:0] i;        // Iterator for computation loop
    reg [2:0] p_reg;    // Registered input p_i
    reg [2:0] n_reg;    // Registered target room index
    
    // Computation registers
    reg [31:0] term1, term2;
    reg signed [32:0] calc_sum;
    reg [31:0] next_f_val;

    // State Transition and Output Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            total_moves <= 32'b0;
            // Reset DP array (optional but good practice)
            // f[0] is base case. f[0] = 0
            f[0] <= 32'd0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        p_reg <= p_i;
                        n_reg <= current_room_index;
                        // Ensure f[0] is 0 if not previously set (base case)
                        // In a real scenario, we might want to keep previous values if the sequence is continuous,
                        // but the problem implies a start signal for a specific computation.
                        // However, the description "maintain internal memory" suggests persistence.
                        // We will assume base case f[0] = 0 is preserved.
                    end
                end

                CALC: begin
                    // Perform calculation for current i
                    // Logic: If p_reg == i: f[i] = f[i-1] + 2
                    // Else: f[i] = (2 + 2*f[i-1] - f[p_i-1]) % MOD
                    
                    if (p_reg == i[2:0]) begin
                        next_f_val = f[i-1] + 2;
                    end else begin
                        // Calculate 2 + 2*f[i-1] - f[p_i-1]
                        // Use signed arithmetic to handle negative intermediate results
                        calc_sum = 33'sd2 + 33'sd2 * f[i-1] - f[p_reg - 1];
                        
                        // Handle negative modulo
                        if (calc_sum < 0) begin
                            // Add enough multiples of MOD to make it positive
                            // Since max negative is roughly -f[1000], we might need multiple adds,
                            // but single loop is safer for synthesis if range is known.
                            // Given 32-bit signed range, we add MOD once. If still negative, add again.
                            // But simple (val % MOD + MOD) % MOD works if val + MOD doesn't overflow signed 32-bit.
                            // Let's use a while-loop equivalent logic or assumption.
                            // The max negative magnitude is roughly -2*MOD (worst case if f[i-1] is near MOD).
                            // So adding MOD once makes it positive or zero.
                            calc_sum = calc_sum + MOD;
                            if (calc_sum < 0) calc_sum = calc_sum + MOD; // Just in case
                            next_f_val = calc_sum[31:0] % MOD;
                        end else begin
                            next_f_val = calc_sum[31:0] % MOD;
                        end
                    end
                    
                    f[i] <= next_f_val;
                end

                DONE: begin
                    total_moves <= f[n_reg];
                    done <= 1'b1;
                end
            endcase
        end
    end

    // Next State Logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: if (start) next_state = CALC;
            CALC: begin
                // Loop control: We need to compute f[i] for i = 1 to n_reg
                if (i == n_reg && n_reg != 0) next_state = DONE;
                else if (n_reg == 0) next_state = DONE; // Edge case if n=0
            end
            DONE: if (!start) next_state = IDLE; // Wait for start to go low before accepting new start
            default: next_state = IDLE;
        endcase
    end

    // Iterator Logic (i counter)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            i <= 4'd1;
        end else begin
            case (state)
                IDLE: begin
                    if (start) i <= 4'd1;
                end
                CALC: begin
                    if (i < n_reg) begin
                        i <= i + 1;
                    end else begin
                        // Reset i or hold, depending on preference. Holding is fine.
                    end
                end
                DONE: begin
                    // Reset i for next run logic or keep it
                    i <= 4'd1;
                end
            endcase
        end
    end

endmodule
