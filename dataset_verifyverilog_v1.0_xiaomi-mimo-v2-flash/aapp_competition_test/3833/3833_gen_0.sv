module StringReorder (
    input clk,
    input rst_n,
    input start,
    input [15:0] t_bits,
    input [15:0] s_cnt0,
    input [15:0] s_cnt1,
    input [4:0] t_len,
    output reg out_char,
    output reg out_valid,
    output reg done
);

    // State definitions
    localparam [3:0] IDLE      = 4'd0;
    localparam [3:0] KMP_PREP  = 4'd1;
    localparam [3:0] KMP_LOOP  = 4'd2;
    localparam [3:0] KMP_WAIT  = 4'd3;
    localparam [3:0] SETUP     = 4'd4;
    localparam [3:0] OUT_T     = 4'd5;
    localparam [3:0] OUT_T_WAIT= 4'd6;
    localparam [3:0] OUT_LOOP  = 4'd7;
    localparam [3:0] OUT_REM   = 4'd8;
    localparam [3:0] FINISH    = 4'd9;

    reg [3:0] state, next_state;

    // KMP Internal Registers
    reg [4:0] kmp_len;          // Current index for prefix function
    reg [4:0] kmp_j;            // Length of previous longest prefix
    reg [15:0] pi [0:15];       // Prefix table (max 16 entries)
    reg [4:0] kmp_idx;          // Loop index for computation
    
    // Pattern Bits Extraction
    reg [3:0] i_split;          // Index to find overlap split
    reg overlap_found;
    
    // Resource Calculation
    reg [15:0] rep_part_bits;   // Bits of repeating part
    reg [4:0] rep_len;          // Length of repeating part
    reg [15:0] cnt0_rem;        // Remaining zeros
    reg [15:0] cnt1_rem;        // Remaining ones
    reg [15:0] cnt_rep0;        // Zeros in repeating part
    reg [15:0] cnt_rep1;        // Ones in repeating part
    
    // Output State Machine
    reg [4:0] out_idx;          // Current bit index in t
    reg [15:0] loop_cnt;        // Number of repeating parts to output
    
    // Cycle Counter for Safety
    reg [15:0] cycle_cnt;
    localparam [15:0] MAX_CYCLES = 16'd1024;

    // Next State Logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: 
                if (start) next_state = KMP_PREP;
            
            KMP_PREP:
                next_state = KMP_LOOP;
            
            KMP_LOOP:
                if (kmp_idx >= t_len) next_state = KMP_WAIT;
                else if (kmp_j > 0 && t_bits[kmp_idx] != t_bits[kmp_j]) next_state = KMP_LOOP; // Stays in loop
                else next_state = KMP_LOOP;
            
            KMP_WAIT:
                next_state = SETUP;
            
            SETUP:
                next_state = OUT_T;
            
            OUT_T:
                if (t_len == 0) next_state = OUT_LOOP;
                else next_state = OUT_T_WAIT;
            
            OUT_T_WAIT:
                if (out_idx >= t_len) next_state = OUT_LOOP;
                else next_state = OUT_T_WAIT;
            
            OUT_LOOP:
                if (loop_cnt == 0) next_state = OUT_REM;
                else if (out_idx >= rep_len) next_state = OUT_LOOP;
                else next_state = OUT_LOOP;
            
            OUT_REM:
                if (cnt0_rem == 0 && cnt1_rem == 0) next_state = FINISH;
                else next_state = OUT_REM;
            
            FINISH:
                next_state = IDLE;
            
            default: next_state = IDLE;
        endcase
    end

    // Output Logic (Sequenced)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            out_valid <= 1'b0;
            cycle_cnt <= 16'd0;
            // Reset Internal Regs
            kmp_idx <= 5'd0;
            kmp_j <= 5'd0;
            kmp_len <= 5'd0;
            i_split <= 4'd0;
            overlap_found <= 1'b0;
            rep_len <= 5'd0;
            cnt_rep0 <= 16'd0;
            cnt_rep1 <= 16'd0;
            cnt0_rem <= 16'd0;
            cnt1_rem <= 16'd0;
            out_idx <= 5'd0;
            loop_cnt <= 16'd0;
            out_char <= 1'b0;
        end else begin
            state <= next_state;
            done <= 1'b0;
            out_valid <= 1'b0;
            
            if (state != IDLE) begin
                cycle_cnt <= cycle_cnt + 16'd1;
            end else begin
                cycle_cnt <= 16'd0;
            end

            case (state)
                IDLE: begin
                    // Wait for start
                end

                KMP_PREP: begin
                    kmp_idx <= 5'd1;
                    kmp_j <= 5'd0;
                    pi[0] <= 16'd0;
                end

                KMP_LOOP: begin
                    // Compute KMP prefix function
                    if (kmp_idx < t_len) begin
                        if (kmp_j > 0 && t_bits[kmp_idx] != t_bits[kmp_j]) begin
                            kmp_j <= pi[kmp_j - 5'd1];
                        end else if (t_bits[kmp_idx] == t_bits[kmp_j]) begin
                            pi[kmp_idx] <= kmp_j + 5'd1;
                            kmp_j <= kmp_j + 5'd1;
                            kmp_idx <= kmp_idx + 5'd1;
                        end else begin
                            pi[kmp_idx] <= 5'd0;
                            kmp_idx <= kmp_idx + 5'd1;
                        end
                    end
                end

                KMP_WAIT: begin
                    // Store overlap length
                    kmp_len <= pi[t_len - 5'd1];
                end

                SETUP: begin
                    // Calculate repeating part
                    rep_len <= t_len - kmp_len;
                    
                    // Initialize remainder counters (copy input counts)
                    cnt0_rem <= s_cnt0;
                    cnt1_rem <= s_cnt1;
                    
                    // Initialize counters for repeating part
                    cnt_rep0 <= 16'd0;
                    cnt_rep1 <= 16'd0;
                    
                    // Reset split finder
                    i_split <= 4'd0;
                end

                OUT_T: begin
                    // Handle case where t_len is 0
                    if (t_len == 5'd0) begin
                        out_idx <= 5'd0;
                        loop_cnt <= 16'd0;
                    end else begin
                        out_idx <= 5'd0;
                    end
                end

                OUT_T_WAIT: begin
                    if (out_idx < t_len) begin
                        out_char <= t_bits[out_idx];
                        out_valid <= 1'b1;
                        out_idx <= out_idx + 5'd1;
                    end
                end

                OUT_LOOP: begin
                    if (loop_cnt == 16'd0) begin
                        // Determine loop count and start finding split
                        // Find split point in repeating part to count resources
                        if (i_split < rep_len) begin
                            // Count resources of repeating part on the fly first time through
                            if (t_bits[kmp_len + i_split]) cnt_rep1 <= cnt_rep1 + 16'd1;
                            else cnt_rep0 <= cnt_rep0 + 16'd1;
                            i_split <= i_split + 4'd1;
                        end else begin
                            // Calculated repeating part counts
                            if (cnt0_rem >= cnt_rep0 && cnt1_rem >= cnt_rep1 && cnt_rep0 + cnt_rep1 > 0) begin
                                // Calculate how many repeats we can do
                                if (cnt_rep0 > 0 && cnt_rep1 > 0) begin
                                    if (cnt0_rem / cnt_rep0 < cnt1_rem / cnt_rep1) loop_cnt <= cnt0_rem / cnt_rep0;
                                    else loop_cnt <= cnt1_rem / cnt_rep1;
                                end else if (cnt_rep0 > 0) begin
                                    loop_cnt <= cnt0_rem / cnt_rep0;
                                end else if (cnt_rep1 > 0) begin
                                    loop_cnt <= cnt1_rem / cnt_rep1;
                                end
                                out_idx <= 5'd0;
                            end
                        end
                    end else begin
                        // Output repeating part
                        if (out_idx < rep_len) begin
                            out_char <= t_bits[kmp_len + out_idx];
                            out_valid <= 1'b1;
                            out_idx <= out_idx + 5'd1;
                        end else begin
                            // One full repeat output
                            out_idx <= 5'd0;
                            loop_cnt <= loop_cnt - 16'd1;
                            cnt0_rem <= cnt0_rem - cnt_rep0;
                            cnt1_rem <= cnt1_rem - cnt_rep1;
                        end
                    end
                end

                OUT_REM: begin
                    if (cnt0_rem > 0) begin
                        out_char <= 1'b0;
                        out_valid <= 1'b1;
                        cnt0_rem <= cnt0_rem - 16'd1;
                    end else if (cnt1_rem > 0) begin
                        out_char <= 1'b1;
                        out_valid <= 1'b1;
                        cnt1_rem <= cnt1_rem - 16'd1;
                    end
                end

                FINISH: begin
                    done <= 1'b1;
                end
            endcase

            // Safety timeout
            if (cycle_cnt >= MAX_CYCLES && state != IDLE) begin
                done <= 1'b1;
                state <= IDLE;
            end
        end
    end

endmodule