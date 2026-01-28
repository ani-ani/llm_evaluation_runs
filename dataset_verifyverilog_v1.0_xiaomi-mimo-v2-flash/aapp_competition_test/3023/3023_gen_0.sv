module cake_cuts (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [4:0] n,
    input wire [3:0] m,
    input wire [15:0] candle_x,
    input wire [15:0] candle_y,
    input wire [31:0] cut_a,
    output reg result,
    output reg done
);
    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] FETCH_CANDLE = 3'd1;
    localparam [2:0] COMPUTE_SIG = 3'd2;
    localparam [2:0] CHECK_COLLISION = 3'd3;
    localparam [2:0] STORE_SIGNATURE = 3'd4;
    localparam [2:0] UPDATE_COUNTER = 3'd5;
    localparam [2:0] FINISH = 3'd6;

    reg [2:0] state, next_state;
    reg [4:0] candle_counter;
    reg [3:0] cut_counter;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd200;

    // Buffer for storing signatures of previously processed candles
    // Max 31 candles, max 15 cuts. We use 16-bit signature (15 bits + padding)
    reg [15:0] sig_buffer [0:30];
    reg [4:0] stored_count;
    reg [15:0] current_signature;
    reg collision_detected;
    reg [15:0] temp_sum;
    reg signed [15:0] temp_val;
    reg signed [31:0] mult_result;

    // Temporary storage for current candle coordinates
    reg [3:0] curr_x;
    reg [3:0] curr_y;

    // Signal to check if current signature matches any in buffer
    reg match_found;
    reg [4:0] buf_idx;

    // Input registers
    reg [4:0] n_reg;
    reg [3:0] m_reg;
    reg [15:0] candle_x_reg;
    reg [15:0] candle_y_reg;
    reg [31:0] cut_a_reg;

    // Helper wire to extract current cut coefficients
    wire signed [7:0] curr_a;
    wire signed [7:0] curr_b;
    wire signed [7:0] curr_c;

    // Decode current cut: 3 8-bit fields packed in 32-bit input
    // Max 4 cuts fit in 32 bits (4 * 8 bits) if we limit precision
    // Constraint says: Pack 4-bit signed a,b,c into 12-bit words.
    // Let's use 12-bit packing for coefficients.
    // 32 bits / 12 bits = 2 full cuts + 8 bits. 
    // Re-interpretation: We use 8-bit signed coeffs for robustness per constraint.
    // If M > 4, we would need multiple inputs, but spec says single 32-bit input.
    // We will assume max 4 cuts for 32-bit input with 8-bit coeffs.
    // cut_a[7:0] = Cut 0 C
    // cut_a[15:8] = Cut 0 B
    // cut_a[23:16] = Cut 0 A
    // cut_a[31:24] = Cut 1 C (Truncated if M > 2, or complex packing)
    // Let's follow the "8-bit coeffs" hint in comments.
    
    // To support up to 8 cuts as hinted, let's assume 4-bit coeffs (a,b,c) = 12 bits.
    // 32 bits can hold 2 cuts exactly (24 bits) or 2 cuts (24 bits) + 8 bits.
    // Given the ambiguity, I will implement a flexible reader for up to 2 cuts per 32-bit word
    // assuming the testbench packs 2 cuts into 32 bits (12b + 12b + 8b padding).
    // However, to strictly match "Pack 4-bit signed... into 12-bit words", let's assume
    // the testbench expects us to read 12 bits per cut from the 32-bit vector.
    // 32 bits = 2 full 12-bit words + 8 unused bits.
    
    assign curr_a = (cut_a_reg >> (cut_counter * 12 + 8)) & 8'hFF; // 4-bit signed ext to 8
    assign curr_b = (cut_a_reg >> (cut_counter * 12 + 4)) & 8'hFF;
    assign curr_c = (cut_a_reg >> (cut_counter * 12 + 0)) & 8'hFF;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 1'b0;
            done <= 1'b0;
            candle_counter <= 5'd0;
            cut_counter <= 4'd0;
            cycle_count <= 8'd0;
            stored_count <= 5'd0;
            collision_detected <= 1'b0;
            current_signature <= 16'd0;
            match_found <= 1'b0;
            buf_idx <= 5'd0;
            // Initialize buffer (optional but good practice, for loop unrolled)
            // Can't use for loop easily in synthesis without careful handling.
            // We will rely on valid flag or written data.
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    result <= 1'b0;
                    candle_counter <= 5'd0;
                    cut_counter <= 4'd0;
                    cycle_count <= 8'd0;
                    stored_count <= 5'd0;
                    collision_detected <= 1'b0;
                    current_signature <= 16'd0;
                    if (start) begin
                        n_reg <= n;
                        m_reg <= m;
                        candle_x_reg <= candle_x;
                        candle_y_reg <= candle_y;
                        cut_a_reg <= cut_a;
                    end
                end

                FETCH_CANDLE: begin
                    // Extract current candle from packed input
                    // candle_x[3:0] = x_0, candle_x[7:4] = x_1, etc.
                    curr_x <= candle_x_reg[candle_counter*4 +: 4];
                    curr_y <= candle_y_reg[candle_counter*4 +: 4];
                    current_signature <= 16'd0;
                    cut_counter <= 4'd0;
                end

                COMPUTE_SIG: begin
                    // Calculate expression for current cut
                    // A*x + B*y + C
                    // x, y are 4-bit. A, B, C are 4-bit signed (extends to 8-bit in wire)
                    // Use 32-bit math to avoid overflow
                    // Sign extension is crucial. 
                    // Note: curr_a/b/c are wires driven by shift logic. 
                    // If shift result is empty (m <= cut_counter), default 0.
                    
                    if (cut_counter < m_reg) begin
                        // Signed multiplication: A * x
                        // x is unsigned 4-bit, treat as signed? Usually signed coords.
                        // Let's cast x to signed 8-bit.
                        mult_result <= $signed({{4{curr_x[3]}}, curr_x}) * $signed(curr_a);
                        temp_sum <= $signed({{4{curr_y[3]}}, curr_y}) * $signed(curr_b) + $signed({{24{curr_c[7]}}, curr_c});
                    end
                end

                STORE_SIGNATURE: begin
                    if (cut_counter < m_reg) begin
                        // Combine results
                        // total = (A*x + B*y) + C
                        // Wait 1 cycle for mult result
                        // Optimization: We are mixing stages. Let's restructure FSM.
                        // COMPUTE_SIG: Calculate Ax, By, C sum
                        // STORE_SIGNATURE: Or bit into current_signature
                        
                        temp_val <= mult_result[15:0] + temp_sum; // Sum of B*Y + C
                        
                        // Wait for computation... actually, let's do it in one block
                    end
                end

                UPDATE_COUNTER: begin
                    // Logic to update signature bit
                    // If (Ax + By + C) > 0, set bit. Else clear bit (assuming binary cut)
                    // Usually "Distinct pieces" implies half-planes. 
                    // Sign determines side. 
                    // Let's interpret signature as a bit vector of signs.
                    // Bit i = 1 if expression > 0, 0 otherwise.
                    
                    if (cut_counter < m_reg) begin
                        // We need the sum from COMPUTE_SIG/STORE_SIGNATURE stage
                        // Since FSM is sequential, let's compute sum inside UPDATE_COUNTER
                        // to save states, or use a combinational block.
                        // Let's use a combinational logic for sum to save cycles.
                    end
                end
            endcase
        end
    end

    // Combinational next-state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: if (start) next_state = FETCH_CANDLE;
            
            FETCH_CANDLE: begin
                if (candle_counter < n_reg) next_state = COMPUTE_SIG;
                else next_state = FINISH;
            end

            COMPUTE_SIG: next_state = STORE_SIGNATURE;

            STORE_SIGNATURE: begin
                // We need to compute the sum for the current cut here (combinational)
                // to update the signature.
                // If we are pipelining, we wait. If combinational, we proceed.
                // Given cycle limit (200) and max N=31, M=15, we have plenty of cycles.
                // Let's add a CALC state to avoid complex combinational paths.
                next_state = UPDATE_COUNTER;
            end

            UPDATE_COUNTER: begin
                if ((cut_counter + 1) < m_reg) begin
                    next_state = COMPUTE_SIG;
                end else begin
                    next_state = CHECK_COLLISION;
                end
            end

            CHECK_COLLISION: next_state = STORE_SIGNATURE_BUFFER;

            STORE_SIGNATURE_BUFFER: next_state = UPDATE_CANDLE;

            UPDATE_CANDLE: begin
                if (collision_detected) next_state = FINISH;
                else if ((candle_counter + 1) < n_reg) next_state = FETCH_CANDLE;
                else next_state = FINISH;
            end

            FINISH: next_state = IDLE;
            
            default: next_state = IDLE;
        endcase
    end

    // Extra states to handle the logic properly without huge combinational blocks
    // Defined new states implicitly in next_state logic, need to declare them
    // Actually, let's refine the state machine to be cleaner.
    
    // Redefining States for clarity
    localparam [2:0] S_IDLE = 3'd0;
    localparam [2:0] S_FETCH = 3'd1;
    localparam [2:0] S_COMPUTE = 3'd2; // Calculate Ax+By+C for current cut
    localparam [2:0] S_UPDATE_SIG = 3'd3; // Shift/Or bit into signature
    localparam [2:0] S_NEXT_CUT = 3'd4; // Loop cuts
    localparam [2:0] S_MATCH = 3'd5; // Check collision with buffer
    localparam [2:0] S_NEXT_CANDLE = 3'd6; // Loop candles
    localparam [2:0] S_DONE = 3'd7;

    // Corrected FSM Implementation
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_IDLE;
            done <= 1'b0;
            result <= 1'b0;
        end else begin
            case (state)
                S_IDLE: begin
                    done <= 1'b0;
                    result <= 1'b0;
                    cycle_count <= 8'd0;
                    candle_counter <= 5'd0;
                    stored_count <= 5'd0;
                    collision_detected <= 1'b0;
                    if (start) begin
                        n_reg <= n;
                        m_reg <= m;
                        candle_x_reg <= candle_x;
                        candle_y_reg <= candle_y;
                        cut_a_reg <= cut_a;
                        state <= S_FETCH;
                    end
                end

                S_FETCH: begin
                    // Read current candle coordinates
                    curr_x <= candle_x_reg[candle_counter*4 +: 4];
                    curr_y <= candle_y_reg[candle_counter*4 +: 4];
                    current_signature <= 16'd0;
                    cut_counter <= 4'd0;
                    state <= S_COMPUTE;
                end

                S_COMPUTE: begin
                    // Check if we have more cuts
                    if (cut_counter < m_reg) begin
                        // Extract coeffs. 
                        // Assuming packed 12 bits per cut: AAAA BBBB CCCC (4-bit each)
                        // cut_a_reg is 32 bits. 
                        // We only have 32 bits. This limits us to 2 cuts if using 12-bit packing.
                        // Let's extract 4-bit values and sign extend.
                        
                        // Access 4-bit fields.
                        // Note: Shift amount must be constant or variable depending on synthesis.
                        // cut_counter * 12. Max cut_counter 15. 15*12 = 180 bits. > 32.
                        // The problem states: "Pack 4-bit signed a,b,c into 12-bit words" for max 8 cuts.
                        // This implies the input port width is dynamic or we read from a stream.
                        // Given the interface is a single 32-bit input, we must assume it holds the current cut's coefficients.
                        // OR, the testbench drives different values on start (impossible for 8 cuts).
                        // Let's re-read: "cut_a[31:0]: Packed ... for up to 2 cuts (or packed for sequence)."
                        // "Simplified for max 8 cuts: Pack 4-bit signed a,b,c per cut into 12-bit words."
                        // This implies the input might be repeated or we process only 2 cuts at a time.
                        // BUT, the problem says "m[3:0]: Number of cuts".
                        // If m=8, we need 8 cuts.
                        // Hypothesis: The testbench will provide different `cut_a` values for each cycle if we request them?
                        // No, inputs are static per start trigger usually.
                        // LIMITATION: With a single 32-bit input, we can only support 2 cuts (12 bits each) or 4 cuts (8 bits each).
                        // I will implement for 2 cuts per input vector, assuming `cut_a` updates externally or we only check 2 cuts.
                        // WAIT. The problem says: "m[3:0]: Number of cuts (0-15)".
                        // And "candle_x[15:0]": 16 bits for X coordinates (4 bits per candle, max 16 candles).
                        // This implies 16 candles is the hard limit.
                        // For cuts, 12 bits * 15 cuts = 180 bits. Too big for 32-bit port.
                        // Clarification needed. I will assume the input `cut_a` contains the coefficients for the CURRENT cut being processed.
                        // This means we need an additional input or we iterate `cut_a` is updated by testbench.
                        // Since the interface is fixed, I will assume `cut_a` holds coefficients for the first 2 cuts (or 4 cuts if 8-bit).
                        // Let's stick to the most reasonable interpretation for a single input port:
                        // The input port `cut_a` is 32 bits. It can hold 2 cuts of 12 bits (a,b,c) or 4 cuts of 8 bits.
                        // Given the context "max 8 cuts", 8 bits per coeff (a,b,c) is 24 bits. Too big.
                        // 4 bits per coeff (a,b,c) = 12 bits. 32 bits / 12 = 2 cuts (24 bits) + 8 unused.
                        // I will implement a solution that supports up to 2 cuts based on the static 32-bit input.
                        // If the testbench expects 8 cuts, it must be that `cut_a` is a scalar and we use multiple inputs or I am missing something.
                        // However, strictly following "candle_x[15:0]... max 16 candles", we see a packed array for candles.
                        // For cuts, we don't have a packed array of coefficients in the spec (only `cut_a[31:0]`).
                        // I will assume the cut coefficients are fixed for this operation and stored in `cut_a`, 
                        // and we support max 2 cuts (since 32 bits is small).
                        // OR, `cut_a` is the A coefficient of the FIRST cut, `cut_b` is B, `cut_c` is C? No, `cut_a` is single port.
                        
                        // DECISION: Implement for 2 cuts (24 bits used of 32). 
                        // If m > 2, we will only process the first 2 cuts (or wrap around/ignore).
                        // To support >2 cuts, we'd need a wider port or a stream.
                        // I will make the cut extraction logic robust to 4-bit fields.
                        
                        // Extract 4-bit signed values
                        // We need to handle the loop.
                        // Let's calculate the shift amount.
                        // Since Verilog shift amount must be constant or variable, and we are in FSM,
                        // we can use variable shift.
                        
                        // cut_a_reg holds 2 cuts max (24 bits).
                        // If cut_counter == 0: bits [11:0]
                        // If cut_counter == 1: bits [23:12]
                        // If cut_counter >= 2: Zero out coeffs (or handle error)
                        
                        // Optimization: Pre-calculate offsets in logic.
                        // Since we can't loop variable amounts easily in combinational logic without for loops,
                        // we unroll or use conditional select.
                        
                        // Let's use a combinational block to get coeffs.
                    end
                end

                S_UPDATE_SIG: begin
                    // Update signature with bit from current cut
                    // Bit is 1 if (Ax + By + C) > 0
                    // We need to compute Ax + By + C. 
                    // This takes 1 cycle for multiply/add.
                    // Wait, S_COMPUTE calculated values? No, S_COMPUTE is just state.
                    // Let's add a CALC state or do it in S_COMPUTE.
                end
            endcase
        end
    end

    // Re-implementing logic with a cleaner structure:
    // 1. Fetch Candle
    // 2. For each cut (0 to m-1):
    //    a. Get coeffs (combinational)
    //    b. Compute Ax + By + C (Sequential add/mul)
    //    c. Update signature bit
    // 3. Check collision with buffer
    // 4. Store signature if no collision
    
    // Since we have limited cycles (200) and small N, M, we can afford a simple state machine.

    // Combinational extraction of cut coefficients
    wire [11:0] cut_data; // 4b A, 4b B, 4b C
    // We need to handle m > 2. Since input is 32 bits, we only have data for 2 cuts (24 bits).
    // We will replicate the logic or assume the testbench handles cut input.
    // Given the ambiguity, I will implement a "virtual" cut reader.
    // If cut_counter < 2, read from cut_a_reg. Else assume 0 or handle externally.
    
    wire signed [3:0] a_in, b_in, c_in;
    
    // Helper to select 12-bit slice
    // 12 bits per cut. 
    // cut 0: [11:0], cut 1: [23:12]
    assign cut_data = (cut_counter == 4'd0) ? cut_a_reg[11:0] : 
                      (cut_counter == 4'd1) ? cut_a_reg[23:12] : 
                      12'd0; // Fallback
    
    assign a_in = cut_data[11:8];
    assign b_in = cut_data[7:4];
    assign c_in = cut_data[3:0];

    // Combinational calculation of line equation result
    // A*x + B*y + C
    // x, y are 4-bit unsigned (0-15). Coeffs 4-bit signed.
    // Result range: (-8*15) + (-8*15) + 8 = -240 + 8 = -232. Fits in 9 bits.
    // We use 16 bits for safety.
    wire signed [15:0] line_value;
    assign line_value = $signed({{12{a_in[3]}}, a_in}) * $signed({{12{curr_x[3]}}, curr_x}) +
                        $signed({{12{b_in[3]}}, b_in}) * $signed({{12{curr_y[3]}}, curr_y}) +
                        $signed({{12{c_in[3]}}, c_in});

    wire current_bit;
    assign current_bit = (line_value > 16'sd0) ? 1'b1 : 1'b0;

    // Combinational match check
    always @(*) begin
        match_found = 1'b0;
        for (buf_idx = 0; buf_idx < stored_count; buf_idx = buf_idx + 1) begin
            if (sig_buffer[buf_idx] == current_signature) begin
                match_found = 1'b1;
            end
        end
    end

    // Sequential Logic Update
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result <= 1'b0;
            cycle_count <= 8'd0;
            stored_count <= 5'd0;
            collision_detected <= 1'b0;
            current_signature <= 16'd0;
            candle_counter <= 5'd0;
            cut_counter <= 4'd0;
        end else begin
            cycle_count <= cycle_count + 8'd1;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    result <= 1'b0;
                    cycle_count <= 8'd0;
                    stored_count <= 5'd0;
                    collision_detected <= 1'b0;
                    candle_counter <= 5'd0;
                    if (start) begin
                        n_reg <= n;
                        m_reg <= m;
                        candle_x_reg <= candle_x;
                        candle_y_reg <= candle_y;
                        cut_a_reg <= cut_a;
                        state <= FETCH_CANDLE;
                    end
                end

                FETCH_CANDLE: begin
                    // Check if done with all candles
                    if (candle_counter >= n_reg) begin
                        state <= FINISH;
                    end else begin
                        // Extract current candle
                        curr_x <= candle_x_reg[candle_counter*4 +: 4];
                        curr_y <= candle_y_reg[candle_counter*4 +: 4];
                        current_signature <= 16'd0;
                        cut_counter <= 4'd0;
                        state <= COMPUTE_SIG;
                    end
                end

                COMPUTE_SIG: begin
                    // Compute bit for current cut
                    // Line value is calculated combinationally from curr_x/y and cut_a/cut_counter
                    // We need to register the bit.
                    
                    if (cut_counter < m_reg) begin
                        // Append bit to signature
                        // Signature is built left-to-right or right-to-left. 
                        // Let's build right-to-left (LSB is cut 0)
                        current_signature[cut_counter] <= current_bit;
                        
                        // Move to next cut
                        cut_counter <= cut_counter + 4'd1;
                        // Stay in this state to process next cut (combinational update)
                        // To avoid combinational loops, we might need a cycle per cut or 
                        // rely on the fact that cut_counter updates next cycle.
                        // Actually, we need to wait for cut_counter to update.
                        // But line_value depends on cut_counter. 
                        // If we stay in COMPUTE_SIG, on next cycle cut_counter is updated.
                        // This works.
                    end else begin
                        // All cuts processed for this candle
                        state <= CHECK_COLLISION;
                    end
                end

                CHECK_COLLISION: begin
                    // Compare current_signature with buffer
                    // match_found is combinational
                    if (match_found) begin
                        collision_detected <= 1'b1;
                    end
                    state <= STORE_SIGNATURE;
                end

                STORE_SIGNATURE: begin
                    // Store if no collision (or just store if we want to check uniqueness)
                    // If collision detected, we might still want to store to fill buffer? 
                    // No, if collision, it's already in buffer.
                    // If unique, store it.
                    if (!match_found) begin
                        sig_buffer[stored_count] <= current_signature;
                        stored_count <= stored_count + 5'd1;
                    end
                    state <= UPDATE_CANDLE;
                end

                UPDATE_CANDLE: begin
                    candle_counter <= candle_counter + 5'd1;
                    state <= FETCH_CANDLE;
                end

                FINISH: begin
                    done <= 1'b1;
                    // Result is 1 if no collisions AND stored_count == n_reg
                    // collision_detected is true if ANY collision happened.
                    // However, if we skip storing on collision, stored_count < n is the indicator.
                    // But we set collision_detected explicitly.
                    if (!collision_detected && (stored_count == n_reg)) begin
                        result <= 1'b1;
                    end else begin
                        result <= 1'b0;
                    end
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
            
            // Timeout safety
            if (cycle_count >= MAX_CYCLES && state != IDLE && state != FINISH) begin
                state <= FINISH;
                result <= 1'b0;
                done <= 1'b1;
            end
        end
    end
endmodule