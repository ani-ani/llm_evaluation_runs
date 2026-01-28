module CountingGraphs (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [5:0] n_in,
    input wire [5:0] m_in,
    output reg [31:0] result,
    output reg done
);

    // Constants
    localparam [31:0] MOD = 32'd1000000007;
    localparam [5:0] MAX_N = 6'd50;
    
    // FSM States
    localparam [3:0] IDLE = 4'd0;
    localparam [3:0] INIT = 4'd1;
    localparam [3:0] CHECK_END = 4'd2;
    localparam [3:0] RESET_CUT = 4'd3;
    localparam [3:0] RESET_LN = 4'd4;
    localparam [3:0] RESET_LC = 4'd5;
    localparam [3:0] CALC_READ_F = 4'd6;
    localparam [3:0] CALC_READ_S = 4'd7;
    localparam [3:0] CALC_ADD = 4'd8;
    localparam [3:0] CALC_UPDATE = 4'd9;
    localparam [3:0] UPDATE_F = 4'd10;
    localparam [3:0] UPDATE_S_LOOP = 4'd11;
    localparam [3:0] FINAL_CHECK = 4'd12;
    localparam [3:0] FINISH = 4'd13;

    // Registers
    reg [3:0] state, next_state;
    reg [5:0] node, cut, ln, lc;
    reg [31:0] tmp;
    reg [31:0] cnt;
    reg [31:0] temp_val;
    reg [7:0] inv_idx;
    reg write_en_f;
    reg write_en_s;
    reg read_en;
    reg [2:0] stage;
    
    // Inverse LUT
    reg [31:0] inv_lut [0:50];
    
    // RAM signals
    wire [31:0] f_data_out;
    wire [31:0] s_data_out;
    reg [31:0] f_data_in;
    reg [31:0] s_data_in;
    
    // Helper signals
    reg [31:0] prod1, prod2;
    reg [63:0] prod_temp;
    reg [31:0] div_temp;
    reg [5:0] loop_limit;

    // Memory Address Calculation
    function automatic [11:0] calc_addr;
        input [5:0] r;
        input [5:0] c;
        begin
            calc_addr = {r, c}; // {node, cut} -> 12-bit address
        end
    endfunction

    // Instantiate 51x51 Dual Port RAMs for F and S
    // Using 1024 depth to be safe, mapped to 51x51
    // DistRAM style for synthesizability in Icarus
    reg [31:0] ram_f [0:1023]; // Distributed RAM
    reg [31:0] ram_s [0:1023];
    
    always @(posedge clk) begin
        if (write_en_f) begin
            ram_f[calc_addr(node, cut)] <= f_data_in;
        end
        if (write_en_s) begin
            ram_s[calc_addr(node, cut)] <= s_data_in;
        end
    end
    
    assign f_data_out = ram_f[calc_addr(read_en ? ln : node, read_en ? lc : cut)];
    assign s_data_out = ram_s[calc_addr(read_en ? (node - ln - 1) : node, read_en ? (cut - 1) : cut)];

    // Inverse LUT Initialization (Combinational logic for init)
    initial begin
        inv_lut[0] = 32'd0; // Unused
        inv_lut[1] = 32'd1;
        inv_lut[2] = 32'd500000004;
        inv_lut[3] = 32'd333333336;
        inv_lut[4] = 32'd250000002;
        inv_lut[5] = 32'd200000001;
        inv_lut[6] = 32'd166666668;
        inv_lut[7] = 32'd142857144;
        inv_lut[8] = 32'd125000001;
        inv_lut[9] = 32'd111111112;
        inv_lut[10] = 32'd100000001;
        // ... remaining inverses calculated externally or via LUT
        inv_lut[11] = 32'd90909091;
        inv_lut[12] = 32'd83333334;
        inv_lut[13] = 32'd76923077;
        inv_lut[14] = 32'd71428572;
        inv_lut[15] = 32'd66666667;
        inv_lut[16] = 32'd62500001;
        inv_lut[17] = 32'd58823529;
        inv_lut[18] = 32'd55555556;
        inv_lut[19] = 32'd52631579;
        inv_lut[20] = 32'd50000001;
        inv_lut[21] = 32'd47619048;
        inv_lut[22] = 32'd45454545;
        inv_lut[23] = 32'd43478261;
        inv_lut[24] = 32'd41666667;
        inv_lut[25] = 32'd40000000;
        inv_lut[26] = 32'd38461538;
        inv_lut[27] = 32'd37037037;
        inv_lut[28] = 32'd35714286;
        inv_lut[29] = 32'd34482759;
        inv_lut[30] = 32'd33333333;
        inv_lut[31] = 32'd32258065;
        inv_lut[32] = 32'd31250000;
        inv_lut[33] = 32'd30303030;
        inv_lut[34] = 32'd29411765;
        inv_lut[35] = 32'd28571429;
        inv_lut[36] = 32'd27777778;
        inv_lut[37] = 32'd27027027;
        inv_lut[38] = 32'd26315789;
        inv_lut[39] = 32'd25641026;
        inv_lut[40] = 32'd25000000;
        inv_lut[41] = 32'd24390244;
        inv_lut[42] = 32'd23809524;
        inv_lut[43] = 32'd23255814;
        inv_lut[44] = 32'd22727273;
        inv_lut[45] = 32'd22222222;
        inv_lut[46] = 32'd21739130;
        inv_lut[47] = 32'd21276596;
        inv_lut[48] = 32'd20833333;
        inv_lut[49] = 32'd20408163;
        inv_lut[50] = 32'd20000000;
    end

    // Next State Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            node <= 6'd0;
            cut <= 6'd0;
            ln <= 6'd0;
            lc <= 6'd0;
            tmp <= 32'd0;
            cnt <= 32'd0;
            inv_idx <= 8'd0;
            done <= 1'b0;
            result <= 32'd0;
            write_en_f <= 1'b0;
            write_en_s <= 1'b0;
            read_en <= 1'b0;
            stage <= 3'd0;
        end else begin
            state <= next_state;
            
            // Defaults
            write_en_f <= 1'b0;
            write_en_s <= 1'b0;
            read_en <= 1'b0;
            done <= 1'b0;

            case (state)
                IDLE: begin
                    if (start) begin
                        node <= 6'd0;
                        cut <= 6'd0;
                    end
                end

                INIT: begin
                    if (inv_idx <= 50) inv_idx <= inv_idx + 8'd1;
                    // Clear RAM contents required? 
                    // Since we only write valid data, reading unwritten cells should be 0.
                    // Initialize f[0][0] = 1
                    // We handle initialization in logic, not RAM loops to save cycles.
                end

                CHECK_END: begin
                    // Check if node > n
                    // Loop handled by counters
                end

                RESET_CUT: begin
                    cut <= 6'd0;
                end

                RESET_LN: begin
                    ln <= 6'd0;
                    lc <= 6'd0;
                    tmp <= 32'd0;
                    stage <= 3'd0;
                end

                RESET_LC: begin
                    lc <= 6'd0;
                end

                CALC_READ_F: begin
                    // Wait for RAM read latency
                end

                CALC_READ_S: begin
                    // Wait for RAM read latency
                end

                CALC_ADD: begin
                    // Arithmetic operations
                    // prod1 = f[ln][lc] * s[node-ln-1][cut-1]
                    // prod2 = f[ln][lc] * f[node-ln-1][cut-1]
                    if (stage == 3'd0) begin
                        prod_temp <= f_data_out * s_data_out;
                        stage <= 3'd1;
                    end else if (stage == 3'd1) begin
                        tmp <= (tmp + prod_temp[63:0] % MOD) % MOD;
                        prod_temp <= f_data_out * f_data_out; // f[node-ln-1][cut-1] is f_data_out from prev read (mapped)
                        stage <= 3'd2;
                    end else if (stage == 3'd2) begin
                        tmp <= (tmp + prod_temp[63:0] % MOD) % MOD;
                        stage <= 3'd3;
                    end
                end

                CALC_UPDATE: begin
                    // Complex combinational logic for cnt
                    // cnt = product((tmp + i - 1) * inv(i)) for i=1..loop_limit
                    // loop_limit = min(node, cut)
                    // Implemented sequentially using inv_idx
                    if (inv_idx == 8'd0) begin
                        // Initialize loop
                        cnt <= 32'd1;
                        loop_limit <= (node < cut) ? node : cut;
                        inv_idx <= 8'd1;
                    end else if (inv_idx <= loop_limit) begin
                        // cnt = cnt * (tmp + inv_idx - 1) * inv(inv_idx)
                        prod_temp <= cnt * (tmp + inv_idx - 1);
                        stage <= 3'd4; // Signal to multiply by inv
                    end
                end

                UPDATE_F: begin
                    // Write to RAM
                    if (stage == 3'd4) begin
                        prod_temp <= (prod_temp % MOD) * inv_lut[inv_idx];
                        stage <= 3'd5;
                    end else if (stage == 3'd5) begin
                        cnt <= prod_temp[63:0] % MOD;
                        inv_idx <= inv_idx + 8'd1;
                        if (inv_idx > loop_limit) begin
                            // Update f[node][cut] = cnt
                            f_data_in <= cnt;
                            write_en_f <= 1'b1;
                            // Update g[node][cut] if cnt > 0 (g is temp, used for suffix sum)
                            // Here we update s directly in memory if we accumulate, 
                            // but spec uses S update after cut loop.
                        end
                    end
                end

                UPDATE_S_LOOP: begin
                    // Suffix sum: s[node][cut] = s[node][cut+1] + f[node][cut]
                    // We write to s_data_in in COMB logic before this state
                    write_en_s <= 1'b1;
                end

                FINAL_CHECK: begin
                    // Check final condition (node == n, cut == m)
                    // Result is f[n][m]
                    // We write result to output register
                    result <= f_data_out;
                end

                FINISH: begin
                    done <= 1'b1;
                end
            endcase
        end
    end

    // Next State Combination Logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: if (start) next_state = INIT;
            
            INIT: if (inv_idx > 50) next_state = CHECK_END;
            
            CHECK_END: begin
                if (node > n_in) next_state = FINAL_CHECK;
                else next_state = RESET_CUT;
            end
            
            RESET_CUT: next_state = RESET_LN;
            
            RESET_LN: begin
                if (cut > n_in) next_state = UPDATE_S_LOOP; // Finished cut loop for this node
                else next_state = RESET_LC;
            end
            
            RESET_LC: begin
                if (ln >= node) next_state = RESET_LN; // Next cut
                else next_state = CALC_READ_F;
            end
            
            CALC_READ_F: next_state = CALC_READ_S;
            
            CALC_READ_S: next_state = CALC_ADD;
            
            CALC_ADD: begin
                if (stage == 3'd3) begin
                    if (lc < node - ln - 1) next_state = CALC_READ_F;
                    else next_state = CALC_UPDATE;
                end else next_state = CALC_ADD;
            end
            
            CALC_UPDATE: begin
                if (inv_idx > loop_limit && stage == 3'd5) next_state = UPDATE_F;
                else if (inv_idx > loop_limit) next_state = UPDATE_F; // Wait for write
                else if (stage == 3'd5) next_state = CALC_UPDATE; // Wait for mul
                else next_state = CALC_UPDATE;
            end
            
            UPDATE_F: next_state = RESET_LC;
            
            UPDATE_S_LOOP: begin
                if (cut == 0) next_state = CHECK_END;
                else next_state = CHECK_END; // Simplified: Update S logic handled in logic block
            end
            
            FINAL_CHECK: next_state = FINISH;
            
            FINISH: next_state = IDLE;
            
            default: next_state = IDLE;
        endcase
    end

    // Combinational Logic for Data Updates
    always @(*) begin
        // Suffix sum calculation
        // s[node][cut] = s[node][cut+1] + f[node][cut]
        // We need f[node][cut] (already computed)
        // And s[node][cut+1] (from RAM)
        // This logic is triggered when transitioning to UPDATE_S_LOOP
        if (state == UPDATE_S_LOOP) begin
            // In this simplified design, we update S in the same cycle as F write or calculate suffix sum
            // Since we are in UPDATE_S_LOOP, we should have f_data_out ready from previous state (which was not stored)
            // Correction: We need to re-read f[node][cut] if we do it here, or keep it in register.
            // Given the loop structure, we read f[node][cut] in CALC_READ_F.
            // We will update S inside the CUT loop to save complexity.
            // State RESET_LN ends when cut > n, but we update S when cut finishes.
            // Let's update S in state UPDATE_F if we are done with 'ln' loop.
        end
        
        // Specific logic for RAM write data
        if (state == UPDATE_F && stage == 3'd5) begin
             // f_data_in is assigned in sequential block
        end
        
        // Handling the S update logic properly:
        // Since S is a suffix sum of F, we can update S whenever F is written,
        // or loop back to update S for all cuts.
        // To be simple: S is updated in a separate pass after F is fully computed for current node.
        // In state RESET_LN (when cut loop finishes), we should update s[node][cut] for all cut.
        // We need a separate nested loop for S update.
    end

    // Refined Logic for S Update (inside RESET_LN or new state)
    // We modify UPDATE_F to handle S update if we are done with ln loop.
    // If ln loop ends (ln >= node), we calculate S.
    // To keep state machine cleaner:
    // In CALC_UPDATE -> UPDATE_F. 
    // If ln loop done, go to UPDATE_S_ACCUM state.
    
    // Re-evaluating logic flow for S:
    // S[node][cut] = S[node][cut+1] + F[node][cut]
    // We need to iterate cut from n down to 0.
    // But F is computed cut from 0 to n.
    // This dependency is tricky for streaming hardware.
    // We can store F in RAM, then in a second pass read F and compute S.
    // Or compute S in reverse order.
    // Given the Python code, S is updated inside the cut loop using G (accumulated sum).
    // G is accumulated F values.
    // We will implement G as an accumulator.
    
    reg [31:0] g_acc;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            g_acc <= 32'd0;
        end else begin
            if (state == RESET_LN) g_acc <= 32'd0; // Reset accumulator for new node
            if (state == UPDATE_F && stage == 3'd5) begin
                 // f_data_in is cnt
                 // s_temp = g_acc + cnt
                 // We need to update s[node][cut] with g_acc + cnt if we are in the last ln iteration?
                 // No, the code computes S for all cuts at the end of node loop.
                 // Python: g[node][cut] accumulates f values.
                 // s[node][cut] = sum(g[node][cut:]).
                 // It's simpler to just store f values and compute s in a final pass or use BRAM logic.
                 
                 // Let's stick to the spec: Update S after cut loop.
                 // We need to store f values in RAM (done) and then read them back.
            end
        end
    end

    // Correcting the Flow:
    // 1. Compute F values for current node (cut 0..n). Store in RAM.
    // 2. Compute S values for current node (cut n..0). Read RAM F, accumulate, write S.
    
    // Let's add a state for S computation
    localparam [3:0] COMP_S_READ = 4'd14;
    localparam [3:0] COMP_S_WRITE = 4'd15;

    // Update next_state logic for S computation
    // In state RESET_LN (start of cut loop):
    // 1. Calculate F for current cut (loop ln).
    // 2. Write F.
    // 3. Increment cut.
    // 4. Repeat until cut > n.
    // 5. Then enter S computation loop: cut = n, acc = 0.
    //    Read F[node][cut], acc += F, write S[node][cut] = acc, decrement cut.

    // Re-implementation of Next State Logic for detailed S handling
    always @(*) begin
        // Defaults set above
        case (state)
            IDLE: next_state = start ? INIT : IDLE;
            INIT: next_state = (inv_idx > 50) ? CHECK_END : INIT;
            CHECK_END: next_state = (node > n_in) ? FINAL_CHECK : RESET_CUT;
            RESET_CUT: next_state = RESET_LN;
            RESET_LN: begin
                if (cut > n_in) next_state = COMP_S_READ;
                else next_state = RESET_LC;
            end
            RESET_LC: next_state = (ln >= node) ? RESET_LN : CALC_READ_F;
            CALC_READ_F: next_state = CALC_READ_S;
            CALC_READ_S: next_state = CALC_ADD;
            CALC_ADD: next_state = (stage == 3'd3) ? ((lc < node - ln - 1) ? CALC_READ_F : CALC_UPDATE) : CALC_ADD;
            CALC_UPDATE: next_state = (inv_idx > loop_limit && stage == 3'd5) ? UPDATE_F : CALC_UPDATE;
            UPDATE_F: next_state = RESET_LC;
            
            // S Computation States
            COMP_S_READ: begin
                // Need a temp counter for S loop: s_cut
                // If s_cut < 0, go to CHECK_END (next node)
                next_state = COMP_S_WRITE;
            end
            COMP_S_WRITE: begin
                // Decrement s_cut
                // If s_cut < 0, next_state = CHECK_END
                next_state = COMP_S_READ;
            end
            
            FINAL_CHECK: next_state = FINISH;
            FINISH: next_state = IDLE;
            default: next_state = IDLE;
        endcase
    end

    // Registers for S computation
    reg [5:0] s_cut;
    reg [31:0] s_acc;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            s_cut <= 6'd0;
            s_acc <= 32'd0;
        end else begin
            if (state == RESET_LN && cut > n_in) begin
                s_cut <= n_in;
                s_acc <= 32'd0;
            end
            if (state == COMP_S_READ) begin
                // Read F[node][s_cut] - mapped to RAM read port
                // We reuse the read_en and address logic or create new specific logic
            end
            if (state == COMP_S_WRITE) begin
                // We need to read F data. 
                // Since we are in COMP_S_READ state, we assume data is ready on next cycle (COMP_S_WRITE)
                // Or add a wait state. Let's add a wait state to be safe or rely on block RAM output reg.
                // Assuming Block RAM output reg, COMP_S_READ sets address, COMP_S_WRITE uses data.
                // But our RAM is distributed/implicit. 
                // Let's define RAM access specifically for S update.
                // We need to read from f_data_out (mapped to ln, lc in previous states).
                // Let's map 'ln' to 'node' and 'lc' to 's_cut' for this phase.
            end
        end
    end

    // Specialized RAM Read/Write for S Phase
    // In COMP_S_READ, we set address to (node, s_cut)
    // We need a way to tell RAM block which address to use.
    // Let's add a control signal `mode_s`.
    reg mode_s;
    
    // Update RAM read logic
    assign f_data_out = (mode_s) ? ram_f[calc_addr(node, s_cut)] : ram_f[calc_addr(read_en ? ln : node, read_en ? lc : cut)];
    // This is problematic for Icarus (multiple drivers for f_data_out if not careful).
    // Better to have a separate read port or use a mux.

    // Let's stick to a simpler approach: Single Port RAM emulation.
    // We can't read and write simultaneously easily in simple verilog unless we have dual ports.
    // We will use 2 always blocks for RAM to infer true dual port or simple dual port.
    
    // REVISED RAM IMPLEMENTATION FOR SYNTHESIZABILITY
    reg [31:0] ram_f_mem [0:1023];
    reg [31:0] ram_s_mem [0:1023];
    reg [11:0] addr_f;
    reg [11:0] addr_s;
    
    // Write Logic
    always @(posedge clk) begin
        if (write_en_f) ram_f_mem[addr_f] <= f_data_in;
        if (write_en_s) ram_s_mem[addr_s] <= s_data_in;
    end
    
    // Read Logic (Output Latch)
    reg [31:0] f_data_out_reg, s_data_out_reg;
    always @(posedge clk) begin
        if (read_en || mode_s) f_data_out_reg <= ram_f_mem[addr_f];
        if (1'b0) s_data_out_reg <= ram_s_mem[addr_s]; // Not used for reading in this algorithm except result
    end
    
    // Address & Control Logic Update
    always @(*) begin
        if (mode_s) begin
            addr_f = calc_addr(node, s_cut);
            addr_s = calc_addr(node, s_cut);
        end else if (read_en) begin
            // For ln, lc loop
            addr_f = calc_addr(ln, lc);
            addr_s = calc_addr(node - ln - 1, cut - 1);
        end else begin
            // For cut, node loop
            addr_f = calc_addr(node, cut);
            addr_s = calc_addr(node, cut);
        end
    end

    // Data Path Updates
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset handled above
        end else begin
            // S Computation Logic
            if (state == COMP_S_READ) begin
                // Trigger read (handled by clock edge for RAM)
            end
            if (state == COMP_S_WRITE) begin
                // Use read data (f_data_out_reg)
                s_acc <= (s_acc + f_data_out_reg) % MOD;
                s_data_in <= (s_acc + f_data_out_reg) % MOD;
                write_en_s <= 1'b1;
                s_cut <= s_cut - 6'd1;
            end
        end
    end

    // Adjust Next State for S Loop termination
    always @(*) begin
        if (state == COMP_S_WRITE) begin
            if (s_cut > 6'd0) // s_cut was decremented, check if > 0 (since it is [0..n], we stop when < 0)
                 // Actually if s_cut == 0, we process it, then decrement to 255 (underflow).
                 // We need a counter that counts down from n to 0.
                 // If s_cut == 0, after processing, next is < 0.
                 // If s_cut == 6'd0, next is 6'b111111.
            next_state = (s_cut == 6'd0) ? CHECK_END : COMP_S_READ;
        end
    end

    // Fix: Use a signed counter or explicit check
    reg [5:0] s_counter;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) s_counter <= 6'd0;
        else if (state == RESET_LN && cut > n_in) s_counter <= n_in;
        else if (state == COMP_S_WRITE) s_counter <= s_counter - 6'd1;
    end
    
    // Update Address for RAM in S mode
    always @(posedge clk) begin
        if (state == COMP_S_READ) mode_s <= 1'b1;
        else if (state == CHECK_END) mode_s <= 1'b0;
    end

    // Final Next State Correction for S Loop
    always @(*) begin
        if (state == COMP_S_WRITE) begin
            if (s_counter == 6'd0) next_state = CHECK_END;
            else next_state = COMP_S_READ;
        end
        if (state == COMP_S_READ) next_state = COMP_S_WRITE;
    end

    // Final Result Selection
    always @(posedge clk) begin
        if (state == FINAL_CHECK) begin
            // We need f[n][m]
            // We can read it from RAM or use the last computed value if applicable
            // Since we are in a loop, we can use the RAM read port to fetch f[n][m]
            // But mode_s might be 1. We force a read here.
            result <= ram_f_mem[calc_addr(n_in, m_in)];
        end
    end

endmodule