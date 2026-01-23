module hearing_optimizer (
    input clk,
    input rst_n,
    input start,
    input [2:0] n,
    input [7:0] s [0:7],
    input [7:0] a [0:7],
    input [7:0] b [0:7],
    output reg [31:0] result,
    output reg done
);

    // State definition
    localparam IDLE = 5'b00001;
    localparam LOAD = 5'b00010;
    localparam CALCULATE = 5'b00100;
    localparam DIVIDE = 5'b01000;
    localparam FINALIZE = 5'b10000;

    // Registers and variables
    reg [4:0] state;
    reg [4:0] next_state;
    
    reg signed [31:0] dp [0:8]; // DP array, Q16.16. Index 0..8. dp[n] = 0.
    reg signed [31:0] attend_val;
    reg signed [31:0] sum_val;
    reg signed [31:0] skip_val;
    
    reg [2:0] i; // Current hearing index
    reg [7:0] t; // End time t
    reg [7:0] j; // Next hearing index
    
    // Division registers
    reg [63:0] div_num;
    reg [63:0] div_den;
    reg [63:0] div_rem;
    reg [31:0] div_res;
    reg [5:0] div_cnt;
    
    // Helper logic for j (next hearing)
    wire [2:0] next_j;
    assign next_j = (t <= s[0]) ? 3'd0 :
                    (t <= s[1]) ? 3'd1 :
                    (t <= s[2]) ? 3'd2 :
                    (t <= s[3]) ? 3'd3 :
                    (t <= s[4]) ? 3'd4 :
                    (t <= s[5]) ? 3'd5 :
                    (t <= s[6]) ? 3'd6 :
                    (t <= s[7]) ? 3'd7 : 3'd0;

    // State transition
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end

    // Control Path
    always @(*) begin
        case (state)
            IDLE: begin
                if (start) next_state = LOAD;
                else next_state = IDLE;
            end
            LOAD: begin
                next_state = CALCULATE;
            end
            CALCULATE: begin
                // We iterate t from s[i]+a[i] to s[i]+b[i]
                // In hardware, we can do this in cycles or single cycle with loop unroll.
                // Since constraints are small, let's do a state machine loop.
                // However, to meet latency requirements (10k cycles), we can do it sequentially.
                if (t < s[i] + b[i]) next_state = CALCULATE;
                else next_state = DIVIDE;
            end
            DIVIDE: begin
                if (div_cnt > 0) next_state = DIVIDE;
                else next_state = FINALIZE;
            end
            FINALIZE: begin
                if (i == 0) next_state = DONE;
                else next_state = LOAD;
            end
            DONE: begin
                if (start) next_state = LOAD; // Re-trigger if needed, or stay DONE
                else next_state = DONE;
            end
            default: next_state = IDLE;
        endcase
    end

    // Datapath
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            done <= 1'b0;
            result <= 32'd0;
            i <= 3'd0;
            t <= 8'd0;
            attend_val <= 32'd0;
            sum_val <= 32'd0;
            skip_val <= 32'd0;
            div_cnt <= 6'd0;
            div_num <= 64'd0;
            div_den <= 64'd0;
            // Initialize DP array to 0 (except dp[n] which is implicitly 0)
            // We will reset specific indices as we go, or reset all.
            // Let's reset all DP entries to 0.
            dp[0] <= 32'd0; dp[1] <= 32'd0; dp[2] <= 32'd0; dp[3] <= 32'd0;
            dp[4] <= 32'd0; dp[5] <= 32'd0; dp[6] <= 32'd0; dp[7] <= 32'd0;
            dp[8] <= 32'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    i <= n - 1; // Start from last hearing
                    dp[n] <= 32'd0; // Base case
                end
                
                LOAD: begin
                    // Setup for calculation of hearing i
                    // Initialize sum_val to 0
                    sum_val <= 32'd0;
                    t <= s[i] + a[i]; // Start time of valid end times
                end
                
                CALCULATE: begin
                    // Accumulate (1 + dp[next_j]) for all valid t
                    // Logic: if t <= s[i] + b[i], add (1 << 16) + dp[next_j] to sum_val
                    if (t <= s[i] + b[i]) begin
                        // 1.0 is 32'h00010000
                        // dp[next_j] is Q16.16
                        // next_j logic handles the search for compatible hearing
                        // Note: If no hearing starts >= t, next_j logic returns 0. dp[0] is valid result.
                        // However, dp[i] uses dp[j] for j > i. If no j, dp[j] = 0.
                        // My next_j logic finds first hearing >= t. It might be i or previous if sorted.
                        // But inputs are sorted. If t <= s[i], next_j = i. But t starts at s[i]+a[i] > s[i].
                        // So next_j > i. 
                        
                        // Correct logic for next_j: find first k where s[k] >= t and k > i?
                        // My wire 'next_j' finds first k where s[k] >= t.
                        // Since inputs are sorted, and t >= s[i] + 1, it will be >= s[i+1] potentially.
                        // We need to ensure we only pick k > i. The wire logic assumes global range.
                        // If s[i] <= t <= s[i+1], next_j = i+1. Good.
                        // If s[i] <= t < s[i+1], next_j = i. Problem.
                        // Let's fix next_j logic to be strictly > i.
                        // Since we have hardwired unrolled logic in the wire, let's fix it here conceptually.
                        // If next_j <= i (happens if t is small), we should treat it as 0 result (no next valid hearing?)
                        // Actually, if t <= s[i], we haven't finished, so we can't attend i. But t > s[i].
                        // So t > s[i]. If s is sorted, next_j >= i+1 is likely.
                        // Let's assume the wire 'next_j' is correct for sorted inputs where s[i] < s[i+1].
                        // If s[i] == s[i+1], the wire picks the lower index. That's acceptable.
                        
                        // Accumulate
                        // If next_j > i: sum_val <= sum_val + (1<<16) + dp[next_j]
                        // If next_j <= i (rare edge case): sum_val <= sum_val + (1<<16) (skip DP part or treat as 0)
                        
                        // To avoid complex combinational logic in ALWAYS block, we rely on the wire.
                        // We need to handle the case where next_j might be i (if t <= s[i], but t is start+a).
                        // Since a >= 1, t > s[i]. So next_j >= i+1 is guaranteed if sorted strictly.
                        
                        if (next_j > i) begin
                            sum_val <= sum_val + 32'h00010000 + dp[next_j];
                        end else begin
                            sum_val <= sum_val + 32'h00010000;
                        end
                        
                        t <= t + 1;
                    end
                end
                
                DIVIDE: begin
                    // sum_val contains the sum of (1 + dp[j]).
                    // Denominator is (b[i] - a[i] + 1).
                    // We need to divide sum_val by the count of terms.
                    // Sum is Q16.16. Count is integer.
                    // Result = Sum / Count. Should be Q16.16.
                    // We perform: (Sum << 16) / Count.
                    // wait, Sum is Q16.16. We want Q16.16 output.
                    // (Sum / Count) is Q16.16. 
                    // Integer division of fixed point number by integer: just divide integer part.
                    // Sum << 16 / Count.
                    
                    if (div_cnt == 6'd0) begin
                        // Initialize division
                        // Maximum sum: 8 hearings * (1+1)*65536 = ~10^6. 
                        // Shift left 16: ~10^12. Fits in 64 bits.
                        // Denominator: Max 255.
                        div_num <= {16'b0, sum_val, 16'b0}; // (Sum << 16)
                        div_den <= {56'b0, (b[i] - a[i] + 8'd1)};
                        div_res <= 32'd0;
                        div_rem <= 64'd0;
                        div_cnt <= 6'd48; // Enough for 48 bits of precision
                    end else begin
                        // Shift subtract algorithm
                        div_num <= {div_num[62:0], 1'b0};
                        div_rem <= {div_rem[62:0], div_num[63]};
                        div_res <= {div_res[30:0], 1'b0};
                        
                        if ({div_rem[62:0], div_num[63]} >= div_den) begin
                            div_rem <= {div_rem[62:0], div_num[63]} - div_den;
                            div_res <= {div_res[30:0], 1'b0} | 1'b1;
                        end
                        
                        div_cnt <= div_cnt - 1;
                    end
                end
                
                FINALIZE: begin
                    // Store attend_val = div_res
                    // We need to handle the division result correctly.
                    // The division loop computed (Sum << 16) / D.
                    // But we want Sum / D.
                    // If we do (Sum << 16) / D, we get Sum * (65536/D). That's wrong.
                    // We want Sum / D = (Sum << 16) / (D << 16).
                    // So we should have divided by (D << 16).
                    // But D is small. We can do: (Sum / D) = (Sum >> 0) / D (fixed point).
                    // Actually, standard division for Q16.16 / integer:
                    // Result = (Sum / D). 
                    // Let's use the 64-bit accumulator trick:
                    // Acc = Sum << 16. Divide by D. Result is Sum * (2^16/D). 
                    // We need to scale back? 
                    // Let's try standard algorithm: Acc = Sum. Remainder = 0.
                    // Shift Acc left 16 times. Each time shift Acc into Remainder. 
                    // Subtract D from Remainder. 
                    // Result is the quotient bits.
                    // Wait, if we want Q16.16 / Integer -> Q16.16.
                    // It is equivalent to: (Sum / D).
                    // If D=2, we want 0.5 of Sum.
                    // (Sum << 16) / D = (Sum * 65536) / 2 = Sum * 32768 = Sum / 2 * 65536.
                    // Yes, this gives Q16.16 result.
                    // So (Sum << 16) / D is correct for Q16.16 / Int -> Q16.16.
                    // My previous logic was: div_num = Sum << 16. div_den = D.
                    // div_res = quotient. This is correct.
                    
                    attend_val <= div_res;
                    
                    // Get skip value
                    skip_val <= dp[i+1];
                    
                    // Finalize DP[i] = max(attend_val, skip_val)
                    if (div_res > dp[i+1]) begin
                        dp[i] <= div_res;
                    end else begin
                        dp[i] <= dp[i+1];
                    end
                    
                    // Prepare for next iteration or done
                    if (i == 0) begin
                        result <= (div_res > dp[i+1]) ? div_res : dp[i+1];
                        done <= 1'b1;
                    end else begin
                        i <= i - 1;
                    end
                    
                    // Reset divider for next use
                    div_cnt <= 6'd0;
                end
                
                DONE: begin
                    // Maintain done high, result stable
                    if (start) begin
                        done <= 1'b0;
                    end
                end
            endcase
        end
    end

endmodule