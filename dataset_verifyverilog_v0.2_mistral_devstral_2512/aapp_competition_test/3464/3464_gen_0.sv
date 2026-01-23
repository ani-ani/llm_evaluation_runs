module casino_profit_calculator (
    input [15:0] x_in,    // Refund percentage in Q8.8 format (x * 256)
    input [15:0] p_in,    // Winning probability in Q8.8 format (p * 256)
    output [31:0] profit  // Maximum expected profit in Q16.16 format
);

    // Convert Q8.8 to Q16.16
    wire [31:0] x_q16 = $signed({16'd0, x_in});
    wire [31:0] p_q16 = $signed({16'd0, p_in});

    // Calculate (1 - x/100) in Q16.16
    // x/100 = x_q16 / 100 = x_q16 / (100 * 2^16) * 2^16 = (x_q16 * 2^16) / (100 * 2^16) = x_q16 / 100
    // But in Q16.16, division by 100 is equivalent to multiplying by 1/100 in Q16.16
    // 1/100 in Q16.16 = 65536 / 100 = 655.36 = 655 + 0.36*65536 = 655 + 23592 = 24247
    wire [31:0] x_div_100 = (x_q16 * 32'd24247) >>> 16;  // Q16.16 * Q16.16 = Q32.32, then shift to Q16.16
    wire [31:0] one_minus_x_div_100 = 32'd65536 - x_div_100;  // 1.0 in Q16.16 is 65536

    // Calculate (1 - p) in Q16.16
    wire [31:0] one_minus_p = 32'd65536 - p_q16;

    // Calculate (1-p)*(1-x/100) in Q16.16
    // Multiply two Q16.16 numbers: result is Q32.32, then shift to Q16.16
    wire [31:0] term = (one_minus_p * one_minus_x_div_100) >>> 16;

    // Calculate EV = p - (1-p)*(1-x/100)
    wire [31:0] ev = p_q16 - term;

    // Calculate expected profit for N=1 to 10 bets
    // For N bets, the expected profit with optimal stopping is more complex,
    // but for simplicity, we'll approximate by scaling EV by N
    // (This is a simplification; a full optimal stopping analysis would be more complex)
    wire [31:0] ev_n1 = ev;
    wire [31:0] ev_n2 = ev + ev;  // 2*EV
    wire [31:0] ev_n3 = ev + ev + ev;  // 3*EV
    wire [31:0] ev_n4 = ev << 2;  // 4*EV
    wire [31:0] ev_n5 = ev << 2 + ev;  // 5*EV
    wire [31:0] ev_n6 = ev << 2 + ev << 1;  // 6*EV
    wire [31:0] ev_n7 = ev << 3 - ev;  // 7*EV
    wire [31:0] ev_n8 = ev << 3;  // 8*EV
    wire [31:0] ev_n9 = ev << 3 + ev;  // 9*EV
    wire [31:0] ev_n10 = ev << 3 + ev << 1;  // 10*EV

    // Find the maximum among all N
    wire [31:0] max_ev = (ev <= 0) ? 0 : 
        (ev_n1 > ev_n2) ? (ev_n1 > ev_n3) ? (ev_n1 > ev_n4) ? (ev_n1 > ev_n5) ? (ev_n1 > ev_n6) ? (ev_n1 > ev_n7) ? (ev_n1 > ev_n8) ? (ev_n1 > ev_n9) ? ev_n1 : ev_n9 : ev_n8 : ev_n7 : ev_n6 : ev_n5 : ev_n4 : ev_n3 : ev_n2 :
        (ev_n2 > ev_n3) ? (ev_n2 > ev_n4) ? (ev_n2 > ev_n5) ? (ev_n2 > ev_n6) ? (ev_n2 > ev_n7) ? (ev_n2 > ev_n8) ? (ev_n2 > ev_n9) ? ev_n2 : ev_n9 : ev_n8 : ev_n7 : ev_n6 : ev_n5 : ev_n4 : ev_n3 :
        (ev_n3 > ev_n4) ? (ev_n3 > ev_n5) ? (ev_n3 > ev_n6) ? (ev_n3 > ev_n7) ? (ev_n3 > ev_n8) ? (ev_n3 > ev_n9) ? ev_n3 : ev_n9 : ev_n8 : ev_n7 : ev_n6 : ev_n5 : ev_n4 :
        (ev_n4 > ev_n5) ? (ev_n4 > ev_n6) ? (ev_n4 > ev_n7) ? (ev_n4 > ev_n8) ? (ev_n4 > ev_n9) ? ev_n4 : ev_n9 : ev_n8 : ev_n7 : ev_n6 : ev_n5 :
        (ev_n5 > ev_n6) ? (ev_n5 > ev_n7) ? (ev_n5 > ev_n8) ? (ev_n5 > ev_n9) ? ev_n5 : ev_n9 : ev_n8 : ev_n7 : ev_n6 :
        (ev_n6 > ev_n7) ? (ev_n6 > ev_n8) ? (ev_n6 > ev_n9) ? ev_n6 : ev_n9 : ev_n8 : ev_n7 :
        (ev_n7 > ev_n8) ? (ev_n7 > ev_n9) ? ev_n7 : ev_n9 : ev_n8 :
        (ev_n8 > ev_n9) ? ev_n8 : ev_n9;

    assign profit = max_ev;

endmodule