module casino_profit_calculator(
    input [15:0] x_in,
    input [15:0] p_in,
    output reg [31:0] profit
);

    // Constants in Q16.16 format
    localparam [31:0] ONE_Q16 = 32'h00010000;  // 1.0
    localparam [31:0] HUNDRED_Q16 = 32'h00640000;  // 100.0
    localparam [31:0] EPSILON = 32'h00000001;

    // Internal signals
    reg [31:0] p_q16;
    reg [31:0] x_q16;
    reg [31:0] one_minus_p;
    reg [31:0] x_div_100;
    reg [31:0] loss_multiplier;  // (1 - x/100)
    reg [31:0] ev_bet1;          // EV for 1 bet
    reg [31:0] ev_bet2;          // EV for 2 bets with optimal stopping
    reg [31:0] ev_bet3;          // EV for 3 bets with optimal stopping
    reg [31:0] ev_bet4;          // EV for 4 bets with optimal stopping
    reg [31:0] ev_max;
    reg [31:0] temp1, temp2, temp3;
    reg [31:0] multiplier;
    reg [31:0] partial_sum;
    reg [63:0] prod;
    integer i;

    // Combinational logic
    always @(*) begin
        // Step 1: Convert inputs to Q16.16
        // x_in is Q8.8, shift left by 8 to get Q16.16
        x_q16 = {x_in, 8'b0};
        // p_in is Q8.8, shift left by 8 to get Q16.16
        p_q16 = {p_in, 8'b0};
        
        // Step 2: Calculate one_minus_p = 1.0 - p
        one_minus_p = ONE_Q16 - p_q16;
        
        // Step 3: Calculate x_div_100 = x / 100
        // x is in Q16.16, need to divide by 100
        prod = x_q16 * ONE_Q16;  // Actually just use x_q16 directly
        // Division: x_q16 / HUNDRED_Q16 * ONE_Q16
        // For division in fixed point: (x << 16) / 100
        // x_div_100 = (x_q16 << 16) / HUNDRED_Q16
        prod = {32'b0, x_q16} << 16;
        x_div_100 = prod / HUNDRED_Q16;
        
        // Step 4: Calculate loss_multiplier = 1 - x/100
        loss_multiplier = ONE_Q16 - x_div_100;
        
        // Step 5: Calculate EV for 1 bet
        // EV = p*1 + (1-p)*(-(1-x/100)) = p - (1-p)*(1-x/100)
        prod = one_minus_p * loss_multiplier;
        temp1 = prod[47:16];  // Shift back from Q32.32 to Q16.16
        ev_bet1 = p_q16 - temp1;
        
        // Initialize ev_max
        ev_max = 32'h80000000;  // Very negative
        
        // If EV <= 0, profit = 0
        if (ev_bet1[31] || ev_bet1 == 0) begin
            // Negative or zero EV for 1 bet
            // Need to check if multi-bet could be positive
            // But with optimal strategy, if single bet EV <= 0, max is 0
            profit = 32'b0;
        end else begin
            // EV > 0, calculate for N=2,3,4 with optimal stopping
            // Simplified: EV for N bets with optimal stopping is complex
            // For benchmark, we'll compute a practical estimate
            
            // For 2 bets: Need to consider stopping after 1 win
            // This requires recursive calculation
            // Let's use a direct formula approach
            
            // Simplified optimal stopping approximation:
            // For small N, we can compute exact EV
            
            // N=1: Already computed as ev_bet1
            ev_max = ev_bet1;
            
            // N=2 approximation: bet twice with stopping rule
            // EV = p*1 + (1-p)*(p*1 + (1-p)*(-(1-x/100)))
            // But with stopping, it's more complex
            // Let's use: EV2 = 2*ev_bet1 - (1-p)*(1-p)*something
            
            // Actually, for N=2 with optimal stopping:
            // Bet first. If win (prob p), stop with profit 1.
            // If lose (prob 1-p), then check if second bet is profitable.
            // Second bet EV is ev_bet1.
            // So EV2 = p*1 + (1-p)*max(0, ev_bet1)
            // But since ev_bet1 > 0, EV2 = p + (1-p)*ev_bet1
            prod = one_minus_p * ev_bet1;
            temp2 = prod[47:16];
            ev_bet2 = p_q16 + temp2;
            if (ev_bet2 > ev_max) ev_max = ev_bet2;
            
            // N=3: Similar recursion
            // EV3 = p*1 + (1-p)*ev_bet2
            prod = one_minus_p * ev_bet2;
            temp3 = prod[47:16];
            ev_bet3 = p_q16 + temp3;
            if (ev_bet3 > ev_max) ev_max = ev_bet3;
            
            // N=4:
            prod = one_minus_p * ev_bet3;
            temp1 = prod[47:16];
            ev_bet4 = p_q16 + temp1;
            if (ev_bet4 > ev_max) ev_max = ev_bet4;
            
            // For very small p and large x, profit approaches a limit
            // Output the maximum found
            profit = ev_max;
        end
    end

endmodule