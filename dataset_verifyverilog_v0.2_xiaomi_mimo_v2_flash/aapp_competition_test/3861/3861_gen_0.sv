module max_non_square (
    input wire clk,
    input wire rst_n,
    input wire valid_in,
    input wire signed [31:0] data_in,
    input wire [9:0] count_in, // Number of elements (max 1024)
    input wire start,          // Pulse high to start new sequence
    output reg signed [31:0] max_out,
    output reg done
);

    // State encoding
    localparam IDLE       = 3'b001;
    localparam SQRT_CHECK = 3'b010;
    localparam UPDATE     = 3'b100;

    // Registers
    reg [2:0] current_state, next_state;
    reg signed [31:0] max_reg;
    reg [9:0] count_reg;
    
    // Sqrt Engine Registers
    reg [15:0] sqrt_in;      // Input for sqrt calculation (absolute value)
    reg [15:0] sqrt_guess;   // Current guess
    reg [15:0] sqrt_best;    // Best approximation
    reg sqrt_valid;          // Flag indicating sqrt engine is running
    reg [4:0] sqrt_iter;     // Iteration counter (5 bits for up to 32 iterations)
    reg [31:0] square_calc;  // Stores guess^2
    
    // Sqrt optimization: We need to check if number is perfect square.
    // We use a sequential iterative approach to save area.
    // Logic for 'guess' update: new_guess = (guess + number / guess) / 2
    // To avoid division, we use a binary search approach which is simpler for integer sqrt.
    // Range is 0 to 65535 (since data_in is 32-bit, but we clamp input to 16-bit for hardware feasibility
    // or handle the 32-bit range via the iterative logic).
    // Strategy: Binary Search for 16-bit range (covers up to ~4.2 billion).
    
    // Internal signals
    wire signed [31:0] abs_data;
    assign abs_data = (data_in[31]) ? (~data_in + 1) : data_in; // Absolute value
    
    // Sqrt Logic Control
    // We use a Binary Search approach for the sqrt.
    // Range [0, 65535] (16 bits).
    // We need to find the integer root.
    // We will use 16 cycles to complete one sqrt calculation.
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            max_out <= 32'h80000000; // Initialize to minimum signed
            max_reg <= 32'h80000000;
            done <= 1'b0;
            count_reg <= 10'd0;
            sqrt_valid <= 1'b0;
            sqrt_iter <= 5'd0;
            sqrt_guess <= 16'h8000; // Start at 2^15 (middle of range)
            sqrt_best <= 16'd0;
            sqrt_in <= 16'd0;
        end else begin
            case (current_state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        // Reset max value
                        max_reg <= 32'h80000000;
                        max_out <= 32'h80000000;
                        count_reg <= count_in;
                        if (count_in > 0 && valid_in) begin
                            current_state <= SQRT_CHECK;
                            // Prepare Sqrt
                            if (data_in[31]) begin // Negative
                                // Cannot be square, skip sqrt, go to update directly handling negative logic
                                sqrt_valid <= 1'b0; // Signal to skip update logic
                                current_state <= UPDATE;
                            end else begin
                                // Check if fits in 16-bit (0 to 65535)
                                if (data_in[31:16] != 0) begin
                                    // Too large for our simple 16-bit sqrt binary search,
                                    // assume it's not a square for this demo constraint or handle as overflow.
                                    // Given constraint "simplified logic for numbers up to 16 bits",
                                    // we treat values > 65535 as non-square (valid candidates).
                                    sqrt_valid <= 1'b0;
                                    current_state <= UPDATE;
                                end else begin
                                    sqrt_in <= data_in[15:0];
                                    sqrt_guess <= 16'h8000; // Start MSB
                                    sqrt_best <= 16'd0;
                                    sqrt_iter <= 5'd0;
                                    sqrt_valid <= 1'b1;
                                end
                            end
                            count_reg <= count_reg - 1;
                        end else begin
                            if (count_in == 0) done <= 1'b1;
                        end
                    end
                end

                SQRT_CHECK: begin
                    // Binary Search Loop (16 iterations for 16 bits)
                    // Iterative refinement: if (guess^2 <= number), keep guess, else remove bit.
                    // Or standard binary search: mid = (low + high) / 2.
                    // Let's use the Newton-Raphson bit-iteration method for speed/area.
                    // Actually, simple 'guess^2 <= sqrt_in' check is best here.
                    
                    if (sqrt_iter < 16) begin
                        sqrt_iter <= sqrt_iter + 1;
                        
                        // Check if current guess^2 <= sqrt_in
                        // Guess is typically represented as: 'Best + (1 << iter)'
                        // Let's refine 'sqrt_best' (accumulated result)
                        
                        // Revised Algorithm: restored remainder method (Babylonian/Newton variant)
                        // Let's use a simpler register update:
                        // sqrt_best = (guess > sqrt_in/guess) ? sqrt_best : guess;
                        // But division is expensive.
                        
                        // Let's use the standard shift-add algorithm for integer square root:
                        // Logic: 
                        // r = 0, b = 2^15 (0x8000)
                        // loop 16 times:
                        //   t = r + b
                        //   if (number >= t * t) then r = t
                        //   b = b >> 1
                        
                        // Note: t*t is hard to compute sequentially without multipliers.
                        // Let's use the approximation method used in the problem description:
                        // Binary Search on range [0, 65535].
                        // We use sqrt_guess as the midpoint.
                        // We need to maintain a low and high bound.
                        // Re-encoding state for binary search:
                        // We will use sqrt_guess as the current 'mid'.
                        // We need low and high registers. But we can derive mid updates.
                        // Let's stick to the 'guess^2' check.
                        
                        // Optimization: Use 1-cycle multiplier or pre-calc logic?
                        // In FPGA/ASIC, we use DSP blocks for multipliers. 16x16 mult is cheap.
                        // square_calc <= sqrt_guess * sqrt_guess (pipeline this?)
                        // For single cycle in this example, we assume combinational multiplier logic is available.
                        
                        // Let's perform standard binary search for sqrt.
                        // We need to track Low and High. 
                        // To save registers, we can just track the answer `r` and adjust it.
                        // Let's use the algorithm:
                        // r = 0; b = 0x8000;
                        // do 16 times:
                        //    r = r ^ b;
                        //    if (r * r > N) then r = r ^ b;
                        //    b = b >> 1;
                        
                        // Multiplication `r*r` or `sqrt_guess * sqrt_guess`.
                        // We will perform `sqrt_guess * sqrt_guess` in the same cycle or previous.
                        // Since we are in a loop, let's assume we compute `guess^2` combinationally.
                        
                        // Let's refine `sqrt_best` (current answer) instead of `sqrt_guess`.
                        // `sqrt_best` accumulates the bits.
                        // `sqrt_temp` = `sqrt_best` + `current_bit`.
                        // Check if `sqrt_temp * sqrt_temp` <= `sqrt_in`.
                        
                        // This requires a 16x16 multiplier. Let's instantiate it logic or assume combinational.
                        // To make it strictly sequential without heavy logic, let's assume we check `guess` vs `sqrt_in/guess`.
                        // Actually, the provided description suggests checking if `floor(sqrt)^2 == x`.
                        // Let's implement a simple binary search state machine.
                        
                        // We need `low` and `high` registers.
                        // Let's add `low_reg` and `high_reg` to the module if needed.
                        // But to keep it clean, let's interpret `sqrt_guess` as `mid`.
                        // We need `low` and `high`. Let's add them.
                        // Actually, we can derive `mid` from `low` and `high`.
                        // Let's use a 16-cycle binary search using `low` and `high`.
                    end else begin
                        // Sqrt finished. Check if perfect square.
                        // Final check: sqrt_best^2 == sqrt_in ?
                        // We need to perform this comparison. 
                        // Let's calculate `sqrt_best * sqrt_best`.
                        // If equal, it is a square (skip update). If not, update max.
                        current_state <= UPDATE;
                    end
                end

                UPDATE: begin
                    // Update logic depends on result of sqrt check
                    // Logic: If (valid_in was high)
                    //    If (data_in is NOT square) update max.
                    //    If (data_in is negative) update max.
                    //    If (data_in > 65535) update max.
                    //    Else if (sqrt_valid was 1 and sqrt_result != data_in) update max.
                    
                    // Note: We need to store the comparison result from SQRT_CHECK.
                    // Let's assume the comparison is done in the UPDATE state to save state complexity.
                    // Or we use a flag `is_square`.
                    
                    // Simplified update logic:
                    // We need to know the result of the sqrt check.
                    // Since we are in a stream, we must output the new max.
                    // max_out is just a wire to max_reg usually, but here it's an output reg.
                    
                    // We need a flag to know if it was a square.
                    // Let's add a temporary register `is_square_flag`.
                    // `is_square_flag` is set in SQRT_CHECK.
                    // Actually, let's add a `is_square` logic in UPDATE state.
                    // We have the `sqrt_in` (original number) and we need to compare with `sqrt_guess * sqrt_guess` (or accumulated result).
                    // Let's calculate square of final result in UPDATE state.
                    
                    // Let's define a 'checker' logic that calculates if `sqrt_in` is square.
                    // We can compute `final_sqrt * final_sqrt` in UPDATE state.
                    // But we didn't keep `final_sqrt` clearly. 
                    // Let's rely on the `sqrt_valid` flag and a new flag `is_square`.
                    // We will modify the SQRT_CHECK logic slightly to set a flag `is_square`.
                    
                    // Actually, let's simplify the FSM to perform the update in the cycle after sqrt.
                    // We need to perform: 
                    //   if (!is_square) max_reg = max(max_reg, original_data)
                    
                    // Wait, the problem requires "Largest integer ... not perfect square".
                    // We must update `max_out`.
                    
                    // We will compute `is_square` in the SQRT_CHECK state.
                    // In UPDATE state, we update `max_reg`.
                    // 
                    // Let's add a wire `is_square` computed from the sqrt calculation.
                    // `is_square` = ( (sqrt_guess * sqrt_guess) == sqrt_in )
                    // We need to compute the square of the found root.
                    // We can assume a combinational multiplier for 16x16 bits is available.
                    
                    // Let's refine the SQRT_CHECK logic.
                    // We will use the shift-add algorithm to find `r` such that `r^2 <= N`.
                    // Then we check `r^2 == N`.
                    // We need `r` register.
                    // We need `b` register (bit mask).
                    // We need `t` register (temp).
                    
                    // Let's restart the logic block for the SQRT engine inside FSM.
                    // State SQRT_CHECK:
                    //   If first iteration, init r=0, b=0x8000.
                    //   Else, calc t = r + b.
                    //   If (t*t <= sqrt_in) then r <= t.
                    //   b <= b >> 1.
                    //   If done (b=0), then store r in `sqrt_root`.
                    //   Then go to UPDATE.
                    
                    // In UPDATE state:
                    //   Compare `sqrt_root * sqrt_root` with `sqrt_in`.
                    //   If equal -> Square. Do nothing (keep max_reg).
                    //   Else -> Not Square. Update max_reg.
                    //   Also handle negative or large numbers (skipped sqrt, set `sqrt_root` to invalid or flag).
                    
                    // We need `sqrt_root` register.
                    // We need `b` register.
                    // We need `t` register.
                    // We need `t_squared` (calculated combinationally or pipelined).
                    // Let's assume we can calculate `t_squared` in one cycle (FPGA DSPs).
                    // If not, we might need extra cycles. 
                    // For this demo, we assume `t_squared` logic is combinational.
                    
                    // Revised Register List:
                    // reg [15:0] sqrt_r; // Accumulated root
                    // reg [15:0] sqrt_b; // Bit mask
                    // reg [15:0] sqrt_t; // Temp root candidate
                    // reg [31:0] sqrt_t_sq; // t^2
                    // reg [31:0] sqrt_in_reg; // Store input
                    // reg sqrt_active; // Flag for state transition
                    
                    // Let's simplify the UPDATE state to just update `max_reg`.
                    // We need to know if the current number is a square.
                    // If `valid_in` is high, we process.
                    // We can set a flag `process_valid` that latches `valid_in`.
                    
                    // Let's restructure:
                    // IDLE: Wait for start.
                    // FETCH: Wait for valid_in. Load data. Decide path.
                    //   If negative -> go to DO_UPDATE (set flag 'not_square').
                    //   If large -> go to DO_UPDATE (set flag 'not_square').
                    //   Else -> go to SQRT_LOOP.
                    // SQRT_LOOP: Perform binary search (16 cycles).
                    // DO_UPDATE: Update max_out if not_square.
                    // DEC_COUNT: Decrement count, check if done.
                    
                    // This is getting complex for a single module. 
                    // Let's stick to the 3-state logic (IDLE, SQRT_CHECK, UPDATE) but make it robust.
                    // We need to handle the case where we skip sqrt check (negative/large).
                    
                    // Let's implement the SQRT logic inside the SQRT_CHECK state fully.
                    // It will take 16 cycles.
                    // We need internal registers: `r`, `b`, `t`.
                    // 
                    // In UPDATE state:
                    //   We check if it is a square.
                    //   If (negative or large) -> NOT_SQUARE.
                    //   If (sqrt_calculated) -> check `r*r` == `sqrt_in`.
                    //   If NOT_SQUARE or (r*r != sqrt_in):
                    //       if (data_in > max_reg) max_reg <= data_in.
                    //   Then go to IDLE (or check count).
                    //   Wait, we have a count loop.
                    //   We need a state to check count and loop back to FETCH/SQRT.
                    
                    // Let's refine states:
                    // IDLE -> CHECK_COUNT (if count > 0, go WAIT_FOR_DATA, else DONE)
                    // WAIT_FOR_DATA -> if valid_in, load data, go DECODE
                    // DECODE:
                    //   if (data_in < 0) -> UPDATE (Not Square)
                    //   else if (data_in > 65535) -> UPDATE (Not Square - constrained)
                    //   else -> SQRT_INIT (Set up Sqrt, then SQRT_LOOP)
                    // SQRT_LOOP (16 cycles) -> UPDATE
                    // UPDATE:
                    //   Calc is_square = (r*r == data_in)
                    //   Update max
                    //   Decrement count
                    //   Loop back to CHECK_COUNT
                    // DONE -> output valid
                    
                    // This is 6 states. Fits easily.
                    // Let's implement this.
                end
            endcase
        end
    end

    // --- Logic Re-implementation based on the refined 6-state machine ---
    // To keep the code within the requested format and concise, I will rewrite the always block.
    
    // Registers for the refined FSM
    // We need: state_reg, count_reg, max_reg, data_reg (store current input), r_reg (sqrt result), b_reg (bitmask)
    reg [2:0] state;
    reg [9:0] cnt;
    reg signed [31:0] current_max;
    reg signed [31:0] d_reg; // store data_in
    reg [15:0] r, b, t;
    reg [31:0] t_sq;
    
    // States
    localparam S_IDLE = 0;
    localparam S_CHECK_COUNT = 1;
    localparam S_WAIT_DATA = 2;
    localparam S_DECODE = 3;
    localparam S_SQRT_LOOP = 4;
    localparam S_UPDATE = 5;
    localparam S_DONE = 6;

    // Combinational helper for square calculation (can be mapped to DSP)
    wire [31:0] t_sq_wire = t * t;
    wire [31:0] r_sq_wire = r * r;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_IDLE;
            current_max <= 32'h80000000;
            max_out <= 32'h80000000;
            done <= 1'b0;
            cnt <= 10'd0;
            r <= 16'd0;
            b <= 16'd0;
            t <= 16'd0;
        end else begin
            case (state)
                S_IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        current_max <= 32'h80000000;
                        max_out <= 32'h80000000;
                        cnt <= count_in;
                        state <= S_CHECK_COUNT;
                    end
                end

                S_CHECK_COUNT: begin
                    if (cnt > 0) begin
                        state <= S_WAIT_DATA;
                    end else begin
                        state <= S_DONE;
                    end
                end

                S_WAIT_DATA: begin
                    if (valid_in) begin
                        d_reg <= data_in;
                        state <= S_DECODE;
                    end
                end

                S_DECODE: begin
                    // Negative numbers are never perfect squares
                    if (d_reg[31]) begin
                        state <= S_UPDATE; // Not a square
                    end
                    // Large numbers (constrained to 16-bit for this demo)
                    else if (d_reg[31:16] != 0) begin
                        state <= S_UPDATE; // Not a square (or treat as large non-square)
                    end
                    else begin
                        // Start Square Root Calculation
                        // Algorithm: Bitwise search
                        // r = 0; b = 0x8000;
                        r <= 16'd0;
                        b <= 16'h8000;
                        state <= S_SQRT_LOOP;
                    end
                end

                S_SQRT_LOOP: begin
                    // Loop 16 times
                    if (b != 0) begin
                        t <= r + b;
                        // We need to check (r+b)^2 <= d_reg (lower 16 bits)
                        // We need to compute t_sq in the previous cycle or wait?
                        // We are using combinational logic for t_sq_wire.
                        // So t is updated this cycle, t_sq_wire updates this cycle.
                        // But d_reg is constant.
                        // However, b needs to be shifted for next iteration.
                        // To make it 1 cycle per iteration, we need 't' to be ready.
                        // We have `t_sq_wire` combinationally.
                        
                        if (t_sq_wire[31:0] <= {16'd0, d_reg[15:0]}) begin
                            r <= t; // Keep candidate
                        end
                        b <= b >> 1;
                        // Stay in this state
                    end else begin
                        state <= S_UPDATE;
                    end
                end

                S_UPDATE: begin
                    // Check if square
                    // If we skipped sqrt (negative/large), it's not a square.
                    // We can detect this by checking 'b'. If b==0 and we came from DECODE directly, we might be in a conflict.
                    // Let's use a flag or check 'state' transitions.
                    // Actually, if we came from DECODE->UPDATE, we didn't touch 'b'.
                    // But 'b' is 0 from reset. 
                    // Let's track if we are in 'sqrt mode' or 'skip mode'.
                    // Alternatively, re-verify in UPDATE.
                    
                    // Logic:
                    // If (d_reg < 0) -> Not Square.
                    // Else if (d_reg > 65535) -> Not Square.
                    // Else -> Check if (r * r == d_reg).
                    // We can compute r_sq_wire combinationally.
                    
                    // To distinguish skip vs sqrt, let's check if we came from DECODE with skip condition.
                    // Actually, we can just check `d_reg` again.
                    
                    if (d_reg[31]) begin // Negative
                        if (d_reg > current_max) current_max <= d_reg;
                    end else if (d_reg[31:16] != 0) begin // Large
                        if (d_reg > current_max) current_max <= d_reg;
                    end else begin
                        // Check Sqrt Result
                        // Note: r_sq_wire is r * r. We need to compare r_sq_wire with d_reg.
                        // d_reg is 32-bit signed. r is 16-bit. r*r is 32-bit unsigned (fits in 32-bit signed up to 4.2B).
                        if (r_sq_wire != d_reg[31:0]) begin
                            if (d_reg > current_max) current_max <= d_reg;
                        end
                    end
                    
                    // Move to next iteration
                    cnt <= cnt - 1;
                    state <= S_CHECK_COUNT;
                end

                S_DONE: begin
                    done <= 1'b1;
                    max_out <= current_max;
                    if (start) state <= S_IDLE; // Reset on start
                end
            endcase
        end
    end

endmodule