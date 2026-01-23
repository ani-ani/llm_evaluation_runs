module cook_time (
    input [15:0] k,    // Stove on time
    input [15:0] d,    // Julia's check interval
    input [15:0] t,    // Cooking time when stove is on
    output [31:0] total_time  // Total cooking time in Q16.16 format
);

// Internal signals (32-bit to prevent overflow)
wire [31:0] k32 = {16'b0, k};
wire [31:0] d32 = {16'b0, d};
wire [31:0] t32 = {16'b0, t};

// Calculate cycle length T = ceil(k/d) * d
wire [31:0] ceil_div = (k32 + d32 - 1) / d32;
wire [31:0] T = ceil_div * d32;

// Check if k is divisible by d (stove always on)
wire is_divisible = (k % d == 0);

// Calculate cooking per cycle in fixed-point units
// One cooking unit = 2*t (to avoid fractions)
wire [31:0] two_t = t32 << 1;
wire [31:0] cycle_units = k32 + ((T - k32) >> 1);  // k + (T-k)/2

// Number of full cycles
wire [31:0] full_cycles = two_t / cycle_units;
wire [31:0] remaining_units = two_t - full_cycles * cycle_units;

// Calculate remaining cooking time
wire [31:0] remaining_time;
assign remaining_time = (remaining_units <= k32) ? 
                        remaining_units : 
                        k32 + ((remaining_units - k32) << 1);

// Final result: (full_cycles * T + remaining_time) converted to Q16.16
// Multiply by 65536 (2^16) to convert to fixed-point
wire [31:0] result = is_divisible ? 
                    (t32 << 16) : 
                    ((full_cycles * T + remaining_time) << 16);

assign total_time = result;

endmodule