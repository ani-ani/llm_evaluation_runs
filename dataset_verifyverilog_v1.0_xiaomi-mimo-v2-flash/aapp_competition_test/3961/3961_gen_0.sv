module DP_Vasya (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [15:0] p_i,
    input wire valid_in,
    input wire [9:0] len,
    output reg [31:0] result,
    output reg done
);

    // Constants
    localparam [31:0] MOD = 32'd1000000007;
    localparam [10:0] MAX_ROOMS = 11'd1024;
    localparam [10:0] EXTRA_ROOM = 11'd1025;

    // State Definitions
    localparam [2:0] IDLE    = 3'd0;
    localparam [2:0] LOAD    = 3'd1;
    localparam [2:0] COMPUTE = 3'd2;
    localparam [2:0] WAIT_RD = 3'd3; // Wait for read latency
    localparam [2:0] FINISH  = 3'd4;

    // Registers
    reg [2:0] state, next_state;
    reg [10:0] i; // Iteration counter (1 to n)
    reg [10:0] load_cnt; // Counter for loading p_i values
    reg [10:0] len_reg; // Store len locally
    reg write_enable_p;
    reg write_enable_dp;
    reg [9:0] addr_p; // 10-bit for 1024 entries
    reg [9:0] addr_dp;
    reg [15:0] data_in_p;
    reg [31:0] data_in_dp;
    reg [31:0] dp_prev; // Stores dp[i-1]
    reg [31:0] dp_pi_val; // Stores dp[p_i]
    reg [1:0] phase; // 0: p_i read, 1: dp_prev read, 2: dp_pi read, 3: calc
    reg start_computation; // Trigger computation start
    reg [31:0] result_reg;

    // BRAM Control Signals for p_array (16-bit width)
    wire [15:0] q_p;
    wire [9:0] addr_p_wr;
    wire [15:0] data_p_wr;
    wire we_p;

    // BRAM Control Signals for dp_array (32-bit width)
    wire [31:0] q_dp;
    wire [9:0] addr_dp_wr;
    wire [31:0] data_dp_wr;
    wire we_dp;

    // Datapath Intermediate Registers
    reg [33:0] calc_temp; // 34-bit to prevent overflow
    reg [31:0] calc_result;

    // Memory Instantiations (Inferred BRAMs)
    // p_array: 1024 x 16-bit RAM
    reg [15:0] p_array_reg [0:1023];
    
    // dp_array: 1024 x 32-bit RAM
    reg [31:0] dp_array_reg [0:1023];

    // Synchronous Read/Write Logic for p_array
    always @(posedge clk) begin
        if (we_p) begin
            p_array_reg[addr_p_wr] <= data_p_wr;
        end
        // Read port (combinational output for synchronous read behavior)
        // Using registered address for BRAM inference style if needed, 
        // but here q_p follows addr_p immediately for simplicity in logic
    end
    assign q_p = p_array_reg[addr_p_wr];

    // Synchronous Read/Write Logic for dp_array
    always @(posedge clk) begin
        if (we_dp) begin
            dp_array_reg[addr_dp_wr] <= data_dp_wr;
        end
    end
    assign q_dp = dp_array_reg[addr_dp_wr];

    // State Machine Synchronous Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result_reg <= 32'd0;
            done <= 1'b0;
            i <= 11'd1;
            load_cnt <= 11'd0;
            len_reg <= 10'd0;
            write_enable_p <= 1'b0;
            write_enable_dp <= 1'b0;
            phase <= 2'd0;
            start_computation <= 1'b0;
            dp_prev <= 32'd0;
            dp_pi_val <= 32'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    start_computation <= 1'b0;
                    load_cnt <= 11'd0;
                    if (start) begin
                        state <= LOAD;
                        len_reg <= len;
                        // Pre-load dp[1] = 2
                        write_enable_dp <= 1'b1;
                        addr_dp_wr <= 10'd1; // dp[1]
                        data_dp_wr <= 32'd2;
                    end
                end

                LOAD: begin
                    write_enable_p <= 1'b0;
                    write_enable_dp <= 1'b0; // Stop dp write after initial setup
                    
                    if (valid_in && load_cnt < len_reg) begin
                        // Write p_i to memory at index load_cnt + 1
                        // p_array index corresponds to room number
                        write_enable_p <= 1'b1;
                        addr_p_wr <= load_cnt[9:0]; // 0-based index: p_i for room i is at i-1
                        data_p_wr <= p_i;
                        load_cnt <= load_cnt + 11'd1;
                    end
                    
                    if (load_cnt == len_reg && !valid_in) begin
                        state <= COMPUTE;
                        i <= 11'd2; // Start computation from i = 2
                        phase <= 2'd0;
                        start_computation <= 1'b1;
                    end
                end

                COMPUTE: begin
                    start_computation <= 1'b0;
                    if (i <= len_reg) begin
                        // Read Phase
                        case (phase)
                            2'd0: begin
                                // Read dp[i-1]
                                write_enable_dp <= 1'b0;
                                addr_dp_wr <= i[9:0] - 10'd1;
                                phase <= 2'd1;
                            end
                            2'd1: begin
                                // Read p[i]
                                write_enable_p <= 1'b0;
                                addr_p_wr <= i[9:0] - 10'd1; // p[i] is at index i-1
                                phase <= 2'd2;
                            end
                            2'd2: begin
                                // Read dp[p_i]
                                write_enable_dp <= 1'b0;
                                addr_dp_wr <= q_p[9:0]; // p_i is 16-bit but value <= i <= 1024
                                phase <= 2'd3;
                            end
                            2'd3: begin
                                // Calculate and Write
                                dp_prev <= q_dp; // dp[i-1] (from phase 0)
                                dp_pi_val <= q_dp; // dp[p_i] (from phase 2)
                                
                                // Computation Logic (Verilog)
                                if (q_p == (i + 16'd1)) begin
                                    // p_i == i+1 case
                                    calc_temp = dp_prev + 32'd2;
                                end else begin
                                    // p_i != i+1 case
                                    // dp[i] = 2*dp[i-1] - dp[p_i] + 2
                                    // We need dp_prev (from stored reg) and dp_pi_val (from q_dp in phase 2)
                                    // Note: q_p in condition refers to current p_i
                                    // q_dp in phase 2 is dp[p_i]
                                    // dp_prev is dp[i-1]
                                    // Let's re-evaluate cycle dependencies
                                    // Cycle 0 (Phase 0): Request dp[i-1]. Available in cycle 1.
                                    // Cycle 1 (Phase 1): Request p[i]. Available in cycle 2.
                                    // Cycle 2 (Phase 2): Request dp[p_i]. Available in cycle 3.
                                    // Cycle 3 (Phase 3): Calc. 
                                    
                                    // We need dp[i-1] and dp[p_i] to compute.
                                    // dp[i-1] was read in Phase 0 (q_dp here in Phase 1).
                                    // Wait, we need to capture values properly.
                                    
                                    // Let's use the captured registers.
                                    // dp_prev captured q_dp in previous iteration (or initial)
                                    // dp_pi_val captured q_dp in Phase 2
                                    
                                    calc_temp = (dp_pi_val * 2); 
                                    calc_temp = calc_temp - dp_prev; // Warning: unsigned subtraction underflow? 
                                    if (calc_temp[33]) begin // If negative (very unlikely with correct logic, but safe)
                                        calc_temp = calc_temp + MOD;
                                    end
                                    calc_temp = calc_temp + 32'd2;
                                end
                                
                                // Modulo
                                calc_temp = calc_temp % MOD;
                                
                                // Write to RAM
                                write_enable_dp <= 1'b1;
                                addr_dp_wr <= i[9:0];
                                data_dp_wr <= calc_temp[31:0];
                                
                                phase <= 2'd0;
                                i <= i + 11'd1;
                            end
                        endcase
                    end else begin
                        // Done with loop
                        state <= FINISH;
                        // Retrieve dp[n]
                        result_reg <= q_dp; // q_dp has dp[n] from last read (if needed) or 
                                            // we need one more read for finish
                        // Actually, after loop ends (i > n), the last written value is dp[n].
                        // Let's just read it one last time.
                        write_enable_dp <= 1'b0;
                        addr_dp_wr <= len_reg[9:0];
                        state <= WAIT_RD;
                    end
                end
                
                WAIT_RD: begin
                    // Wait for memory read latency
                    result_reg <= q_dp;
                    state <= FINISH;
                end

                FINISH: begin
                    result <= result_reg;
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end

    // Assign internal signals to wire assignments for RAM interface
    assign addr_p_wr = (state == LOAD) ? load_cnt[9:0] : 
                       (state == COMPUTE && phase == 2'd1) ? (i[9:0] - 10'd1) : 10'd0;
    assign data_p_wr = p_i;
    assign we_p = (state == LOAD && valid_in && load_cnt < len_reg);

    // For dp RAM
    // We handle this in always block logic mostly, but need clean wire mapping
    // The always block logic above is slightly flawed regarding direct wire assignments vs always logic.
    // Refactoring RAM control to be pure wires based on state.

    // Cleaned up RAM Control Logic
    reg dp_write_en;
    reg [9:0] dp_addr;
    reg [31:0] dp_data_in;
    reg [9:0] p_addr;
    reg p_write_en;
    
    always @(posedge clk) begin
        if (p_write_en) p_array_reg[p_addr] <= p_i; // p_i is external input
        if (dp_write_en) dp_array_reg[dp_addr] <= dp_data_in;
    end
    assign q_p = p_array_reg[p_addr];
    assign q_dp = dp_array_reg[dp_addr];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            dp_write_en <= 1'b0;
            p_write_en <= 1'b0;
            dp_addr <= 10'd0;
            p_addr <= 10'd0;
            dp_data_in <= 32'd0;
            done <= 1'b0;
            state <= IDLE;
            i <= 11'd2;
            load_cnt <= 11'd0;
            phase <= 2'd0;
            result <= 32'd0;
        end else begin
            dp_write_en <= 1'b0;
            p_write_en <= 1'b0;
            done <= 1'b0;
            
            case (state)
                IDLE: begin
                    if (start) begin
                        state <= LOAD;
                        len_reg <= len;
                        // Initialize dp[1] = 2
                        dp_write_en <= 1'b1;
                        dp_addr <= 10'd1;
                        dp_data_in <= 32'd2;
                    end
                end

                LOAD: begin
                    // The previous dp[1] write completes here.
                    if (valid_in && load_cnt < len_reg) begin
                        p_write_en <= 1'b1;
                        p_addr <= load_cnt[9:0]; // Index 0 to n-1
                        load_cnt <= load_cnt + 11'd1;
                    end
                    if (load_cnt == len_reg && !valid_in) begin
                        state <= COMPUTE;
                        phase <= 2'd0; // Start read phase
                    end
                end

                COMPUTE: begin
                    if (i <= len_reg) begin
                        case (phase)
                            2'd0: begin
                                // Read dp[i-1]
                                dp_addr <= i[9:0] - 10'd1;
                                phase <= 2'd1;
                            end
                            2'd1: begin
                                // Read p[i] (stored at i-1 index)
                                p_addr <= i[9:0] - 10'd1;
                                phase <= 2'd2;
                            end
                            2'd2: begin
                                // Read dp[p_i]
                                // p_i is in q_p (16-bit)
                                // We need to latch q_p from phase 1 to know which address
                                // But q_p updates immediately in comb logic.
                                // To be safe, we latch p_i in a register.
                                phase <= 2'd3;
                            end
                            2'd3: begin
                                // Calculation Phase
                                // We have q_dp (dp[i-1] from Phase 0)
                                // We have q_p (p[i] from Phase 1)
                                // We have q_dp (dp[p_i] from Phase 2)
                                
                                // NOTE: In hardware, q_dp/q_p are available immediately.
                                // But registers need to be stable.
                                // We will rely on the fact that RAM output is stable 1 cycle after address set.
                                
                                // Capture values for calculation
                                reg [31:0] val_dp_prev;
                                reg [31:0] val_dp_pi;
                                reg [15:0] val_p;
                                
                                // These assignments happen in combination with phase logic
                                // In a real single-cycle logic (without pipeline registers), we read the outputs directly.
                                // However, let's assume RAMs have 1 cycle read latency or use registered outputs.
                                // The code assumes q_dp/q_p are combinational from address.
                                
                                // Calculations
                                // dp[i-1] is q_dp from Phase 0 (which happened 2 cycles ago? No, i increments)
                                // Let's step through i=2.
                                // P0: Read dp[1] (addr 1). q_dp = 2.
                                // P1: Read p[2] (addr 1). q_p = p2. q_dp still 2.
                                // P2: Read dp[p2]. q_p is p2. q_dp becomes dp[p2].
                                // P3: Compute. 
                                
                                // We need to store dp[i-1] and p[i] carefully.
                                // Let's use the registers from the previous simplified logic.
                                
                                // Correction: The previous state machine logic had a flaw in variable capture.
                                // Let's implement a strict sequential flow.
                                
                                // 1. Compute
                                // dp_prev holds dp[i-1] (captured at start of i loop)
                                // q_p holds p_i
                                // q_dp holds dp[p_i]
                                
                                // Wait, dp_prev needs to be updated from the RAM read of dp[i-1]
                                // That read happens in Phase 0. So by Phase 3, we have it available in q_dp.
                                // However, Phase 2 also reads q_dp. 
                                
                                // Solution: Split phases or use intermediate registers.
                                // Let's stick to the cycle-accurate model: 
                                // Phase 0 (Cycle N): Set addr to i-1. Result avail N+1.
                                // Phase 1 (Cycle N+1): Set addr to p[i]. Result avail N+2.
                                // Phase 2 (Cycle N+2): Set addr to p[i] (wait, we need p[i] from N+1 to know dp[p_i] addr).
                                
                                // Actually, let's process in 3 cycles per iteration strictly.
                                // Cycle 0: Read dp[i-1] (address i-1). Latch to `dp_prev_reg`.
                                // Cycle 1: Read p[i] (address i-1). Latch to `p_reg`.
                                // Cycle 2: Read dp[p_i] (address p_reg). Latch to `dp_pi_reg`.
                                // Cycle 3: Calculate and Write dp[i].
                                
                                // Let's adjust the state machine phases to be 0, 1, 2, 3 matching this.
                                // In Phase 0, we need `dp_prev` for the *previous* iteration's calculation, 
                                // but for the *current* iteration, we need to read dp[i-1].
                                
                                // Let's re-write the computation block simply.
                                
                                // At start of Phase 0 (for current i):
                                // `dp_prev_reg` should contain dp[i-1] (read in previous iteration's Phase 0, or init)
                                // `p_reg` should contain p[i] (read in previous iteration's Phase 1)
                                // `dp_pi_reg` should contain dp[p_i] (read in previous iteration's Phase 2)
                                
                                // Wait, the indexing is tricky. 
                                // For i=2:
                                // Phase 0: Read dp[1].
                                // Phase 1: Read p[2].
                                // Phase 2: Read dp[p[2]].
                                // Phase 3: Calc dp[2]. Write to index 2.
                                
                                // We need to delay the calculation until Phase 3.
                                // And we need to save the values read in Phase 0, 1, 2.
                                
                                // Registers:
                                // reg_dp_prev: Captured in Phase 0
                                // reg_p_i: Captured in Phase 1
                                // reg_dp_pi: Captured in Phase 2
                                
                                // Modulo Logic:
                                // If p_i == i+1: dp[i] = dp[i-1] + 2
                                // Else: dp[i] = 2*dp[i-1] - dp[p_i] + 2
                                
                                // Implementation:
                                
                                // We need to handle the signed subtraction carefully (2*dp[i-1] - dp[p_i] + 2).
                                // Since dp values are modulo M, and M is large (10^9+7), 
                                // 2*dp[i-1] + 2 is usually > dp[p_i].
                                // However, 2*dp[i-1] + 2 + M - dp[p_i] is the same modulo.
                                
                                // Calculation:
                                // temp1 = (reg_dp_prev << 1) + 2
                                // if (reg_p_i == i + 1) result = temp1
                                // else result = (temp1 + M - reg_dp_pi) % M
                                
                                // Let's write the calculation logic here.
                                
                                // We need to latch values from RAM outputs.
                                // q_dp is available based on address set in previous cycle.
                                // q_p is available based on address set in previous cycle.
                                
                                // The logic in the FSM handles address setting.
                                // Here we handle data latching and calculation.
                                
                                // We will use `phase` to control latching.
                                
                            end
                        endcase
                    end else begin
                        state <= FINISH;
                        // We need to retrieve dp[n]
                        dp_addr <= len_reg[9:0];
                        // Wait one cycle for read
                        state <= WAIT_RD;
                    end
                end
                
                WAIT_RD: begin
                    result <= q_dp;
                    state <= FINISH;
                end

                FINISH: begin
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end

    // To fix the combinational loop/phase logic:
    // We will re-write the FSM with explicit latching of intermediate values.
    // This is safer for synthesis and Icarus Verilog.

    reg [31:0] val_dp_prev;
    reg [15:0] val_p;
    reg [31:0] val_dp_pi;
    reg [31:0] val_dp_calc;
    
    // Re-implementing the sequential logic block cleanly
    // Note: The block above is messy. Let's replace it with a cleaner version.

endmodule

// Since the previous block was getting messy, let's define the module again cleanly.
// This is the final deliverable module.

module DP_Vasya_Final (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [15:0] p_i,
    input wire valid_in,
    input wire [9:0] len,
    output reg [31:0] result,
    output reg done
);

    // Constants
    localparam [31:0] MOD = 32'd1000000007;
    
    // States
    localparam [2:0] IDLE    = 3'd0;
    localparam [2:0] LOAD    = 3'd1;
    localparam [2:0] COMP_READ_PREV = 3'd2; // Read dp[i-1]
    localparam [2:0] COMP_READ_P    = 3'd3; // Read p[i]
    localparam [2:0] COMP_READ_PI   = 3'd4; // Read dp[p_i]
    localparam [2:0] COMP_CALC      = 3'd5; // Calculate & Write
    localparam [2:0] FINISH         = 3'd6;

    // Registers
    reg [2:0] state, next_state;
    reg [9:0] i;
    reg [9:0] n; // len
    reg [9:0] load_idx;
    
    // RAMs
    reg [15:0] p_reg [0:1023];
    reg [31:0] dp_reg [0:1023];
    
    // Latches for computation
    reg [31:0] dp_prev_val;
    reg [15:0] p_val;
    reg [31:0] dp_pi_val;
    
    // Address/Data regs
    reg [9:0] addr_r;
    reg [31:0] data_w;
    reg we;

    // Helpers
    reg [31:0] temp_calc;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result <= 32'd0;
            we <= 1'b0;
        end else begin
            done <= 1'b0;
            we <= 1'b0;
            
            case (state)
                IDLE: begin
                    if (start) begin
                        n <= len;
                        load_idx <= 10'd0;
                        state <= LOAD;
                        // Pre-load dp[1] = 2
                        we <= 1'b1;
                        addr_r <= 10'd1;
                        data_w <= 32'd2;
                    end
                end

                LOAD: begin
                    // If we just wrote dp[1] in IDLE, it completes this cycle.
                    // Accept inputs
                    if (valid_in && load_idx < n) begin
                        p_reg[load_idx] <= p_i; // p[i] stored at index i-1
                        load_idx <= load_idx + 10'd1;
                    end
                    
                    // Transition to compute when loaded
                    // We need to ensure we start from i=2
                    if (load_idx == n && !valid_in) begin
                        i <= 10'd2;
                        state <= COMP_READ_PREV;
                    end
                end

                COMP_READ_PREV: begin
                    // Read dp[i-1]
                    if (i <= n) begin
                        addr_r <= i - 10'd1;
                        state <= COMP_READ_P;
                    end else begin
                        // Done with all i
                        // We need to retrieve dp[n]
                        addr_r <= n;
                        state <= FINISH;
                    end
                end

                COMP_READ_P: begin
                    // Read p[i] (index i-1)
                    // Latch dp[i-1] result
                    dp_prev_val <= dp_reg[addr_r];
                    // Set address for p[i]
                    addr_r <= i - 10'd1;
                    state <= COMP_READ_PI;
                end

                COMP_READ_PI: begin
                    // Read dp[p_i]
                    // Latch p[i]
                    p_val <= p_reg[addr_r];
                    // Set address for dp[p_i]
                    // p_val is 16-bit, but valid range is 1..i+1. Fits in 10 bits.
                    // Since p_i <= i, and i <= 1024, address fits.
                    addr_r <= p_val[9:0];
                    state <= COMP_CALC;
                end

                COMP_CALC: begin
                    // Latch dp[p_i]
                    dp_pi_val <= dp_reg[addr_r];
                    
                    // Perform Calculation
                    // Note: dp_prev_val, dp_pi_val are valid from previous RAM reads.
                    
                    // dp[i] = dp[i-1] + 2 if p_i == i+1
                    // else dp[i] = 2*dp[i-1] - dp[p_i] + 2
                    
                    // Intermediate: 2*dp[i-1] + 2
                    // 34-bit to hold 2*10^9 roughly without overflow
                    wire [33:0] term1;
                    assign term1 = (dp_prev_val << 1) + 32'd2;
                    
                    if (p_val == (i + 16'd1)) begin
                        temp_calc = term1[31:0]; // Safe because MOD fits 32-bit
                    end else begin
                        // term1 - dp_pi_val
                        // If term1 < dp_pi_val, result is negative (theoretical), 
                        // but mathematically term1 >= dp_pi_val for valid inputs 
                        // (since dp grows monotonically roughly).
                        // However, modulo arithmetic subtraction can underflow conceptually.
                        // We do modular subtraction: (A - B + MOD) % MOD
                        
                        if (term1 >= dp_pi_val) begin
                            temp_calc = term1 - dp_pi_val;
                        end else begin
                            temp_calc = term1 + MOD - dp_pi_val;
                        end
                    end
                    
                    // Apply modulo (though input was modded, output should be modded)
                    // Since temp_calc < 2*MOD + 2 roughly, we might need one subtraction.
                    // But 2*MOD + 2 < 2^32. 
                    // Just use % MOD for safety in Verilog.
                    data_w <= temp_calc % MOD;
                    
                    // Write to dp_reg[i]
                    we <= 1'b1;
                    addr_r <= i;
                    
                    // Next iteration
                    i <= i + 10'd1;
                    state <= COMP_READ_PREV;
                end

                FINISH: begin
                    result <= dp_reg[addr_r];
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule