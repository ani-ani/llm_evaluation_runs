module max_hits (
    input wire clk,
    input wire rst_n,
    input wire [7:0] valid_mask,
    input wire [31:0] circle_x [0:7],
    input wire [31:0] circle_y [0:7],
    input wire [31:0] circle_r [0:7],
    output reg [3:0] max_hits,
    output reg done
);

    // --- Constants and Parameters ---
    parameter PI_Q16 = 32'h0006487F; // pi in Q16.16 approx 3.14159
    parameter TWO_PI_Q16 = 32'h000C90FE; // 2*pi in Q16.16
    parameter ONE_Q16 = 32'h00010000; // 1.0 in Q16.16

    // --- State Machine Definition ---
    reg [3:0] state;
    localparam IDLE = 4'd0;
    localparam COMPUTE_ANGLES = 4'd1;
    localparam NORMALIZE = 4'd2;
    localparam SORT = 4'd3;
    localparam SWEEP = 4'd4;
    localparam DONE = 4'd5;

    // --- Computation Registers and Wires ---
    // Store circle data
    reg [7:0] valid_mask_reg;
    reg signed [31:0] x_reg [0:7];
    reg signed [31:0] y_reg [0:7];
    reg signed [31:0] r_reg [0:7];

    // Angle storage (16 endpoints: 8 start, 8 end)
    // Each angle is 33 bits to allow signed overflow during calculation, normalized to 32 bits
    reg signed [32:0] angles_start [0:7]; // Computed atan2(y, x) - atan2(r, d)
    reg signed [32:0] angles_end [0:7];   // Computed atan2(y, x) + atan2(r, d)

    // Normalized angles for sorting
    // We store pairs: {type, angle}. type=0 for start, type=1 for end.
    // Packed into 33 bits: [32] is type, [31:0] is angle value
    reg [32:0] endpoints [0:15]; 

    // Sorting registers
    reg [32:0] sort_buffer [0:15];
    reg [4:0] sort_idx;
    reg [4:0] sort_j;

    // Sweep registers
    reg [4:0] sweep_idx;
    reg signed [4:0] current_count;
    reg signed [4:0] max_count;
    reg [32:0] current_angle;
    reg is_end_type;

    // --- Helper Variables for Combinatorial Logic ---
    integer i, j;

    // --- CORDIC / Atan2 Computation Logic ---
    // Iterative CORDIC is too slow for single cycle. 
    // We will implement a small pipeline for the angle calculation.
    // Since inputs are fixed point, we handle scaling.
    // We need to compute: angle = atan2(y, x)
    // We also need to compute delta = atan2(r, sqrt(x^2 + y^2))
    // To save logic, we can use a pipelined state approach for the calculation steps.

    // Registers for CORDIC pipeline steps
    // We unroll the logic slightly in the state machine to keep it sequential rather than massive combinational paths.

    // Intermediate calculations for normalizing
    wire [32:0] normalized_val;
    wire overflow_flag;
    // Handle wraparound logic for the computed angles
    // We perform checks: if angle < 0, add 2pi. If angle >= 2pi, sub 2pi.
    // Since we compute a few stages per clock in NORMALIZE state, we can iterate.

    // --- Logic for CORDIC (Simplified for brevity and speed) ---
    // Note: A full CORDIC implementation is verbose. 
    // We will implement a simplified approximation or small pipelined step.
    // Given the strict cycle requirement (32 cycles), we have plenty of time.
    // Let's break CORDIC into sub-states.

    // CORDIC Registers
    reg signed [31:0] cord_x, cord_y;
    reg [4:0] cord_iter;
    reg cord_sign; 
    reg [31:0] cord_angle_acc;
    reg [31:0] cord_lut [0:15]; // arctan(2^-i)

    // State for CORDIC
    reg [2:0] cordic_substate;
    localparam CORDIC_IDLE = 0;
    localparam CORDIC_LOAD = 1;
    localparam CORDIC_ITERATE = 2;
    localparam CORDIC_DONE = 3;

    // Registers to hold which circle we are processing
    reg [3:0] circle_idx;

    // --- Initialization of LUT ---
    initial begin
        cord_lut[0] = 32'h0000C90F; // 0.785398 (pi/4)
        cord_lut[1] = 32'h000076B1; // 0.463648
        cord_lut[2] = 32'h00003EB6; // 0.244979
        cord_lut[3] = 32'h00001FD5; // 0.124355
        cord_lut[4] = 32'h00000FFA; // 0.062419
        cord_lut[5] = 32'h000007FF; // 0.031239
        cord_lut[6] = 32'h00000400; // 0.015625
        cord_lut[7] = 32'h00000200; // 0.007812
        cord_lut[8] = 32'h00000100; // 0.003906
        cord_lut[9] = 32'h00000080; // 0.001953
        cord_lut[10] = 32'h00000040; // 0.000977
        cord_lut[11] = 3