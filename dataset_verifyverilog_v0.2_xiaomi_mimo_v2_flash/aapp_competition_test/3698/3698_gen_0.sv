module special_number_counter (
    input clk,
    input rst_n,
    input start,
    input [1023:0] n_binary,
    input [9:0] k_in,
    output reg [31:0] result,
    output reg done
);

    parameter MOD = 1000000007;
    localparam IDLE = 3'b000;
    localparam PRECOMPUTE = 3'b001;
    localparam COUNTING = 3'b010;
    localparam DONE_STATE = 3'b011;

    reg [2:0] state;
    reg [9:0] k_target;
    reg [1023:0] n_reg;

    // Precompute registers
    reg [10:0] m_val; // 1 to 1024
    reg [31:0] fact [0:1024];
    reg [31:0] invFact [0:1024];
    reg [10:0] special_m_list [0:63];
    reg [5:0] special_m_count;
    reg [2:0] pre_state; // 0:fact, 1:inv_prep, 2:inv_loop, 3:valid_m

    // Counting registers
    reg [10:0] bit_idx;
    reg [10:0] ones_seen;
    reg [31:0] temp_sum;
    reg [1:0] count_state; // 0: calc, 1: accum
    reg current_bit_is_one;

    // Combinational nCr logic
    wire [31:0] nCr_term;
    reg [10:0] nCr_n, nCr_r;

    // nCr function using precomputed fact/invFact
    // Since we can't pass arrays to functions, we access them directly in combinational block.
    // We need a combinational block to calculate nCr_term.

    // Helper function for modular exponentiation (for inverse)
    function [31:0] mod_pow;
        input [31:0] base, exp;
        integer i;
        reg [31:0] res;
        reg [31:0] b;
        reg [31:0] e;
        begin
            res = 1;
            b = base % MOD;
            e = exp;
            for (i = 0; i < 31; i = i + 1) begin
                if (e[0]) res = (res * b) % MOD;
                b = (b * b) % MOD;
                e = e >> 1;
            end
            mod_pow = res;
        end
    endfunction

    // Combinational block for nCr term
    // This block assumes fact and invFact are up to date.
    always @(*) begin
        if (nCr_r > nCr_n || nCr_n > 1024) begin
            nCr_term = 0;
        end else begin
            nCr_term = (((fact[nCr_n] * invFact[nCr_r]) % MOD) * invFact[nCr_n - nCr_r]) % MOD;
        end
    end

    // Combinational check for valid m
    function is_special_m;
        input [10:0] m;
        input [9:0] k_val;
        integer steps;
        reg [10:0] curr;
        begin
            if (k_val == 0) begin
                // Only m=1 is theoretically valid for the reduction chain ending at 1,
                // but we handle k=0 separately in counting (x=1 only).
                // However, for list population, we can just mark m=1.
                // The counting logic will filter x=1.
                is_special_m = (m == 1);
            end else begin
                steps = 0;
                curr = m;
                while (curr > 1 && steps < k_val - 1) begin
                    // Popcount curr (11 bits)
                    curr = curr[0] + curr[1] + curr[2] + curr[3] + curr[4] + curr[5] + curr[6] + curr[7] + curr[8] + curr[9] + curr[10];
                    steps = steps + 1;
                end
                if (curr == 1 && steps == k_val - 1) is_special_m = 1;
                else is_special_m = 0;
            end
        end
    endfunction

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 0;
            result <= 0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 0;
                    if (start) begin
                        state <= PRECOMPUTE;
                        n_reg <= n_binary;
                        k_target <= k_in;
                        // Reset precompute
                        m_val <= 1;
                        special_m_count <= 0;
                        pre_state <= 0; // Start Fact
                        fact[0] <= 1;
                    end
                end

                PRECOMPUTE: begin
                    case (pre_state)
                        0: begin // Factorial and Valid M Scan
                            if (m_val <= 1024) begin
                                fact[m_val] <= (fact[m_val - 1] * m_val) % MOD;
                                // Check valid m
                                if (is_special_m(m_val, k_target)) begin
                                    if (special_m_count < 64) begin
                                        special_m_list[special_m_count] <= m_val;
                                        special_m_count <= special_m_count + 1;
                                    end
                                end
                                m_val <= m_val + 1;
                            end else begin
                                // Finished fact and scan
                                m_val <= 0; // Use m_val as index for inverse prep
                                pre_state <= 1;
                            end
                        end
                        1: begin // Compute Inverse of Fact[1024]
                            // invFact[1024] = mod_pow(fact[1024], MOD-2)
                            // We can't do iterative pow here easily in 1 cycle.
                            // Let's use the combinational function for just this one value.
                            // Or we can use the sequential iterative method in the next state.
                            // Let's use the combinational function for simplicity of state logic.
                            // mod_pow is combinational in terms of state (no external state), but it loops.
                            // It synthesizes to logic.
                            invFact[1024] <= mod_pow(fact[1024], MOD - 2);
                            pre_state <= 2;
                        end
                        2: begin // Backtrack InvFact
                            if (m_val < 1024) begin // Iterate 0 to 1023 (wait, i goes down)
                                // Backtrack: invFact[i] = invFact[i+1] * (i+1)
                                // We need index i = 1023 down to 0.
                                // Let's use m_val as the target index i.
                                // We start with i=1023. 
                                // Wait, we need to handle the loop index carefully.
                                // Let's use a separate counter or reuse m_val.
                                // m_val was 0. We want to fill 1023...0.
                                // Let's use a counter `inv_idx` initialized to 1023.
                                // Since we don't have that var, let's manage m_val.
                                // If m_val == 0, set temp index to 1023.
                                // We can just use a generate-like loop unrolled in state machine? No.
                                // Let's stick to: 
                                // We need to compute invFact[1023] down to invFact[0].
                                // We can iterate 1024 times.
                                // Let's use `m_val` as the loop counter (0 to 1024).
                                // When m_val == 0: we are at step 1 (calc invFact[1023])? 
                                // Let's introduce `inv_idx`.
                                // To keep it simple: 
                                // m_val starts at 0. 
                                // invFact[1024] is ready.
                                // First iteration: invFact[1023] = invFact[1024] * 1024.
                                // Second: invFact[1022] = invFact[1023] * 1023.
                                // ...
                                // Last: invFact[0] = invFact[1] * 1.
                                
                                // We need a temporary register for the current index.
                                // Let's use a new register `idx_ptr` initialized to 1024 in IDLE or PRECOMPUTE entry.
                                // To avoid adding registers, we can infer `invFact[1024 - m_val - 1]` ?
                                // No.
                                // Let's add `inv_idx`.
                                // Let's assume `inv_idx` is 1024 initially.
                                // We need to update it.
                                // To avoid adding code, let's just do: 
                                // We iterate 1024 times.
                                // In cycle T (0..1023), we compute invFact[1023-T].
                                // If m_val = 0..1023: compute invFact[1023-m_val].
                                // invFact[1023-m_val] = invFact[1023-m_val+1] * (1023-m_val+1).
                                // i.e., invFact[1023-m_val] = invFact[1024-m_val] * (1024-m_val).
                                
                                // We need to access invFact[1024-m_val] which is already computed.
                                // Since we computed invFact[1024] first, then m_val=0: calc invFact[1023] using invFact[1024].
                                // m_val=1: calc invFact[1022] using invFact[1023].
                                
                                // So logic:
                                // invFact[1023 - m_val] <= (invFact[1024 - m_val] * (1024 - m_val)) % MOD;
                                // Need to handle (1024 - m_val). 
                                // When m_val = 1023: 1023-1023=0. 1024-1023=1. calc invFact[0] = invFact[1] * 1. Correct.
                                
                                // We need to be careful with array index bounds.
                                // We can compute index dynamically.
                                // Let's use a temp variable for clarity in logic.
                                // Wait, we are in always @posedge. We can't use dynamic array index easily if it's not constant in synthesis?
                                // Verilog allows it if the array is packed? No, unpacked arrays usually require constant index.
                                // `invFact[1024 - m_val]` -> index expression not constant.
                                // Synthesis usually rejects this for unpacked arrays.
                                // We need to use a packed array or iterate explicitly.
                                // Let's use a generate block to define the logic? No, runtime dynamic.
                                // We must unpack the arrays or use a large case statement? No.
                                // We can pack the arrays.
                                // `reg [31:0] fact [0:1024]` is unpacked.
                                // We can use `reg [31:0] fact [0:1024]` but access with variable index is not synthesizable for RAM inference if we want speed.
                                // BUT, for this specific backtracking, we are iterating sequentially.
                                // We can use a shift register approach? 
                                // Or we can just use explicit state machine states? 1024 states is too many.
                                // We can use a packed array to allow variable indexing? 
                                // `reg [31:0] fact [0:1024]` cannot be indexed with variable in combinational logic easily.
                                // However, many synthesizers (Xilinx Vivado, Synopsys) DO support variable indexing for arrays if the array is implemented as RAM/Registers.
                                // Let's assume we can use variable index.
                                // If we must be 100% safe without variable indexing, we can unroll the loop in the code generator (but we can't).
                                // So we rely on variable indexing.
                                // Let's use a temporary register `current_inv` to hold the value and shift it.
                                // Actually, we can just use a chain of registers.
                                // Start with `current_inv = invFact[1024]`.
                                // Loop i from 1 to 1024:
                                //   invFact[1024-i] = current_inv * (1024-i+1).
                                //   current_inv = invFact[1024-i].
                                // This avoids variable indexing! Just one register `current_inv`.
                                // We need to store results? No, we need invFact for later.
                                // But we only need invFact in the counting state.
                                // So we need to store the whole array.
                                // If we can't index dynamically, we are stuck.
                                // Let's try to use `for` loop inside combinational block to initialize? No, that's initial block.
                                // We are in sequential logic.
                                // We can use `generate` inside the module to create 1024 blocks.
                                // `generate for...endgenerate`. This creates hardware structure.
                                // But we need to control the flow (when to compute).
                                // We can have a `compute_inv` signal.
                                // If `compute_inv` is high, the generate block logic updates.
                                // But generate blocks are static.
                                // We can use the `current_inv` chain method.
                                // But we need to store all values.
                                // We can use 1024 registers in a chain.
                                // Register 1024: input invFact[1024].
                                // Register 1023: input Reg[1024] * 1024.
                                // Register 1022: input Reg[1023] * 1023.
                                // ...
                                // This requires 1024 multipliers and 1024 registers.
                                // And we enable them in sequence.
                                // We can enable them one by one.
                                // Cycle 0: Compute Reg[1023] = Reg[1024] * 1024. Store in Reg[1023].
                                // Cycle 1: Compute Reg[1022] = Reg[1023] * 1023. Store in Reg[1022].
                                // ...
                                // We need to access Reg[1024] at cycle 0.
                                // So we need `current_inv` register that holds the latest computed value.
                                // And we store it into the array at the correct index.
                                // But if we can't index array dynamically, we can't store it into `invFact[index]`.
                                // However, we can store it into a specific register `invFact[1023]`, `invFact[1022]` etc if we hardcode.
                                // Hardcoding 1024 lines is impossible.
                                // So we must rely on variable indexing.
                                // Most FPGAs/ASIC tools allow variable indexing for register files (implemented as LUT RAM or Flip-Flops).
                                // Let's proceed with variable indexing.
                                
                                if (m_val < 1024) begin
                                    // invFact[1023 - m_val] <= (invFact[1024 - m_val] * (1024 - m_val)) % MOD;
                                    // Let's compute index carefully.
                                    // m_val goes 0 to 1023.
                                    // dest_idx = 1023 - m_val.
                                    // src_idx = 1024 - m_val.
                                    // mult_val = 1024 - m_val.
                                    invFact[1023 - m_val] <= (invFact[1024 - m_val] * (1024 - m_val)) % MOD;
                                    m_val <= m_val + 1;
                                end else begin
                                    // Done
                                    m_val <= 0; // Reset for counting or not needed
                                    state <= COUNTING;
                                    bit_idx <= 1023;
                                    ones_seen <= 0;
                                    result <= 0;
                                    count_state <= 0; // Calc
                                end
                            end
                        end
                    endcase
                end

                COUNTING: begin
                    if (count_state == 0) begin // Calculate
                        // Calculate contribution if bit is 1
                        if (k_target == 0) begin
                            // Special case: only x=1 counts.
                            // x=1: ones_seen=0, bit_idx=0, n_reg[0]=1.
                            // Note: This calc state runs for every bit.
                            // We only add if bit_idx==0 && ones_seen==0.
                            // But we need to check n_reg[0]?
                            // Actually, the `temp_sum` will be added in accum state only if `current_bit_is_one`.
                            // So if n_reg[0] is 1, and ones_seen==0, temp_sum should be 1.
                            // Else 0.
                            if (bit_idx == 0 && ones_seen == 0) temp_sum <= 1;
                            else temp_sum <= 0;
                        end else begin
                            // Normal calculation
                            // Sum_{m in list} nCr(bit_idx, m - (ones_seen + 1))
                            // We perform this sum combinationaly using a for loop.
                            // Since we are in sequential block, we must calculate the sum manually or use a helper wire.
                            // We can't use `for` loop to update `temp_sum` inside always block easily for synthesis of complex logic?
                            // Actually, we can use a `for` loop with `disable` or just sequential updates.
                            // Sequential updates would take 64 cycles (too slow).
                            // We need to unroll it.
                            // We can define a helper combinational block that calculates the sum.
                            // Let's define a `always @(*)` block that computes `calc_sum`.
                            // Inputs: bit_idx, ones_seen, special_m_count, special_m_list, fact, invFact.
                            // Output: calc_sum.
                            // Then assign temp_sum = calc_sum.
                            // This pushes the combinational logic to the separate block.
                            // Yes, do that.
                            
                            // temp_sum <= calc_contribution;
                        end
                        count_state <= 1;
                        current_bit_is_one <= n_reg[bit_idx];
                    end else begin // Accumulate
                        if (current_bit_is_one) begin
                            result <= (result + temp_sum) % MOD;
                            ones_seen <= ones_seen + 1;
                        end
                        // Next bit
                        if (bit_idx == 0) begin
                            state <= DONE_STATE;
                            done <= 1;
                        end else begin
                            bit_idx <= bit_idx - 1;
                            count_state <= 0;
                        end
                    end
                end
                
                DONE_STATE: begin
                    // Done signal is high. Wait for start low to reset.
                    if (!start) begin
                        state <= IDLE;
                        done <= 0;
                    end
                end
            endcase
        end
    end

    // Helper combinational block for contribution calculation
    reg [31:0] calc_sum;
    integer i;
    reg [10:0] needed;
    reg [31:0] term;
    
    always @(*) begin
        calc_sum = 0;
        if (k_target > 0) begin
            for (i = 0; i < 64; i = i + 1) begin
                if (i < special_m_count) begin
                    needed = special_m_list[i] - (ones_seen + 1);
                    if (needed >= 0 && needed <= bit_idx) begin
                        // nCr = fact[bit_idx] * invFact[needed] * invFact[bit_idx - needed]
                        // Since bit_idx can be 0, we must be careful with array access.
                        // fact[0] is valid. invFact[0] is valid.
                        term = fact[bit_idx];
                        term = (term * invFact[needed]) % MOD;
                        term = (term * invFact[bit_idx - needed]) % MOD;
                        calc_sum = (calc_sum + term) % MOD;
                    end
                end
            end
        end
    end

endmodule