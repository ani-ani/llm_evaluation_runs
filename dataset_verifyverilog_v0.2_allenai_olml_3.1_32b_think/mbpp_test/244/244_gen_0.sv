module next_perfect_square (
    input [15:0] N,
    output [15:0] result
);

// Intermediate signals for bit-by-bit sqrt
wire [7:0] x;
wire [15:0] rem;

// Initialize
assign x = 0;
assign rem = 0;

// Iteration 0: bits 15:14
wire [1:0] bits0 = N[15:14];
wire [7:0] trial0 = (x << 1) | 1;
wire [15:0] trial_sq0 = trial0 * trial0;
wire take0 = trial_sq0 <= ((rem << 2) | bits0);
wire [7:0] x1 = take0 ? trial0 : x;
wire [15:0] rem1 = take0 ? ((rem << 2) | bits0) - trial_sq0 : ((rem << 2) | bits0);

// Iteration1: bits13:12
wire [1:0] bits1 = N[13:12];
wire [7:0] trial1 = x1 << 1 | 1;
wire [15:0] trial_sq1 = trial1 * trial1;
wire take1 = trial_sq1 <= ((rem1 << 2) | bits1);
wire [7:0] x2 = take1 ? trial1 : x1;
wire [15:0] rem2 = take1 ? ((rem1 << 2) | bits1) - trial_sq1 : ((rem1 << 2) | bits1);

// Iteration2: bits11:10
wire [1:0] bits2 = N[11:10];
wire [7:0] trial2 = x2 << 1 | 1;
wire [15:0] trial_sq2 = trial2 * trial2;
wire take2 = trial_sq2 <= ((rem2 << 2) | bits2);
wire [7:0] x3 = take2 ? trial2 : x2;
wire [15:0] rem3 = take2 ? ((rem2 << 2) | bits2) - trial_sq2 : ((rem2 << 2) | bits2);

// Iteration3: bits9:8
wire [1:0] bits3 = N[9:8];
wire [7:0] trial3 = x3 << 1 | 1;
wire [15:0] trial_sq3 = trial3 * trial3;
wire take3 = trial_sq3 <= ((rem3 << 2) | bits3);
wire [7:0] x4 = take3 ? trial3 : x3;
wire [15:0] rem4 = take3 ? ((rem3 << 2) | bits3) - trial_sq3 : ((rem3 << 2) | bits3);

// Iteration4: bits7:6
wire [1:0] bits4 = N[7:6];
wire [7:0] trial4 = x4 << 1 | 1;
wire [15:0] trial_sq4 = trial4 * trial4;
wire take4 = trial_sq4 <= ((rem4 << 2) | bits4);
wire [7:0] x5 = take4 ? trial4 : x4;
wire [15:0] rem5 = take4 ? ((rem4 << 2) | bits4) - trial_sq4 : ((rem4 << 2) | bits4);

// Iteration5: bits5:4
wire [1:0] bits5 = N[5:4];
wire [7:0] trial5 = x5 << 1 | 1;
wire [15:0] trial_sq5 = trial5 * trial5;
wire take5 = trial_sq5 <= ((rem5 << 2) | bits5);
wire [7:0] x6 = take5 ? trial5 : x5;
wire [15:0] rem6 = take5 ? ((rem5 << 2) | bits5) - trial_sq5 : ((rem5 << 2) | bits5);

// Iteration6: bits3:2
wire [1:0] bits6 = N[3:2];
wire [7:0] trial6 = x6 << 1 | 1;
wire [15:0] trial_sq6 = trial6 * trial6;
wire take6 = trial_sq6 <= ((rem6 << 2) | bits6);
wire [7:0] x7 = take6 ? trial6 : x6;
wire [15:0] rem7 = take6 ? ((rem6 << 2) | bits6) - trial_sq6 : ((rem6 << 2) | bits6);

// Iteration7: bits1:0
wire [1:0] bits7 = N[1:0];
wire [7:0] trial7 = x7 << 1 | 1;
wire [15:0] trial_sq7 = trial7 * trial7;
wire take7 = trial_sq7 <= ((rem7 << 2) | bits7);
wire [7:0] x_final = take7 ? trial7 : x7;
wire [15:0] rem_final = take7 ? ((rem7 << 2) | bits7) - trial_sq7 : ((rem7 << 2) | bits7);

// Compute nextN = x_final +1
wire [8:0] nextN = x_final + 1;

// Compute result = (nextN)^2, truncated to 16 bits
assign result = (nextN * nextN) & 16'hFFFF;

endmodule