module TreeHarvester #(
    parameter N = 2,                    // Max species
    parameter DATA_WIDTH = 8,           // S, B, Y: 0-255
    parameter I_WIDTH = 8,              // I: 0-255
    parameter YEAR_WIDTH = 12,          // Max year: 4095
    parameter POP_WIDTH = 24            // Population sum width
)(
    input clk,                          // Clock
    input rst_n,                        // Active-low reset
    input start,                        // Start pulse (1 cycle)
    input [1:0] valid_count,            // Number of valid species (1-2)
    
    // Species 0 data
    input [DATA_WIDTH-1:0] S_0, B_0, Y_0,
    input [I_WIDTH-1:0] I_0,
    // Species 1 data  
    input [DATA_WIDTH-1:0] S_1, B_1, Y_1,
    input [I_WIDTH-1:0] I_1,
    
    output [POP_WIDTH-1:0] result,      // Maximum total trees
    output reg done                     // Computation complete
);

// State machine states
localparam [2:0] IDLE = 3'd0;
localparam [2:0] INIT = 3'd1;
localparam [2:0] PREPARE_T = 3'd2;
localparam [2:0] COMPUTE_TOTAL = 3'd3;
localparam [2:0] UPDATE_MAX = 3'd4;
localparam [2:0] INCREMENT = 3'd5;
localparam [2:0] DONE = 3'd6;

// Internal registers
reg [2:0] state;
reg [0:0] i_idx;                        // Outer loop: species index
reg [0:0] k_idx;                        // Inner loop: summation index
reg phase;                              // 0: B_i, 1: B_i+Y_i
reg [YEAR_WIDTH-1:0] t;                 // Current candidate year
reg [POP_WIDTH-1:0] total;              // Accumulator for current t
reg [POP_WIDTH-1:0] max_total;          // Maximum result

// Latched input data
reg [DATA_WIDTH-1:0] latched_S_0;
reg [DATA_WIDTH-1:0] latched_B_0;
reg [DATA_WIDTH-1:0] latched_Y_0;
reg [I_WIDTH-1:0] latched_I_0;
reg [DATA_WIDTH-1:0] latched_S_1;
reg [DATA_WIDTH-1:0] latched_B_1;
reg [DATA_WIDTH-1:0] latched_Y_1;
reg [I_WIDTH-1:0] latched_I_1;

// Select current species data for calculation
wire [DATA_WIDTH-1:0] curr_S = (i_idx == 0) ? latched_S_0 : latched_S_1;
wire [DATA_WIDTH-1:0] curr_B = (i_idx == 0) ? latched_B_0 : latched_B_1;
wire [DATA_WIDTH-1:0] curr_Y = (i_idx == 0) ? latched_Y_0 : latched_Y_1;
wire [I_WIDTH-1:0] curr_I = (i_idx == 0) ? latched_I_0 : latched_I_1;

// Combinational population calculation for current species at year t
reg [POP_WIDTH-1:0] pop_k;  // Register to hold calculation result

always @(*) begin
    if (t < curr_B) begin
        pop_k = 0;
    end else if (t <= curr_B + curr_Y) begin
        // Increasing phase: pop = S + I*(t - B)
        // Calculate (t - curr_B) first, ensure no overflow
        wire [YEAR_WIDTH-1:0] diff_t_B = t - curr_B;
        wire signed [POP_WIDTH:0] calc_inc = $signed({1'b0, curr_S}) + 
                                              $signed({1'b0, curr_I}) * $signed({1'b0, diff_t_B});
        pop_k = (calc_inc[POP_WIDTH]) ? 0 : calc_inc[POP_WIDTH-1:0];
    end else begin
        // Decreasing phase: pop = I*Y - I*(t - B - Y)
        // Check if t - B - Y > Y, then pop = 0
        wire [YEAR_WIDTH-1:0] diff_t_B_Y = t - curr_B - curr_Y;
        wire signed [POP_WIDTH:0] calc_dec = $signed({1'b0, curr_I}) * $signed({1'b0, curr_Y}) - 
                                              $signed({1'b0, curr_I}) * $signed({1'b0, diff_t_B_Y});
        pop_k = (calc_dec[POP_WIDTH] || diff_t_B_Y > curr_Y) ? 0 : calc_dec[POP_WIDTH-1:0];
    end
end

// State transition
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        i_idx <= 0;
        k_idx <= 0;
        phase <= 0;
        t <= 0;
        total <= 0;
        max_total <= 0;
        latched_S_0 <= 0;
        latched_B_0 <= 0;
        latched_Y_0 <= 0;
        latched_I_0 <= 0;
        latched_S_1 <= 0;
        latched_B_1 <= 0;
        latched_Y_1 <= 0;
        latched_I_1 <= 0;
        done <= 1'b0;
    end else begin
        done <= 1'b0;  // Default: done is 0 unless in DONE state
        case (state)
            IDLE: begin
                if (start) begin
                    state <= INIT;
                end
            end
            INIT: begin
                // Latch all input data
                latched_S_0 <= S_0;
                latched_B_0 <= B_0;
                latched_Y_0 <= Y_0;
                latched_I_0 <= I_0;
                latched_S_1 <= S_1;
                latched_B_1 <= B_1;
                latched_Y_1 <= Y_1;
                latched_I_1 <= I_1;
                state <= PREPARE_T;
            end
            PREPARE_T: begin
                // Set t based on current phase
                if (phase == 0) begin
                    t <= curr_B;
                end else begin
                    t <= curr_B + curr_Y;
                end
                total <= 0;
                k_idx <= 0;
                state <= COMPUTE_TOTAL;
            end
            COMPUTE_TOTAL: begin
                // Sum population for all valid species at this t
                if (k_idx < valid_count) begin
                    // For k_idx == 0, we need to calculate for species 0
                    // For k_idx == 1, we need to calculate for species 1
                    // We use a temporary register to hold the calculation
                    // Actually, we need to handle this differently
                    // The comb logic pop_k always computes for current i_idx
                    // So we need to iterate through all species here
                    // Let's restructure: COMPUTE_TOTAL computes sum for current t
                    // We need to iterate k_idx from 0 to valid_count-1
                    // For each k_idx, set i_idx to k_idx, then add pop_k
                    // But i_idx is for outer loop... need separate temp
                    
                    // Actually, let's use k_idx directly with muxed inputs
                    wire [DATA_WIDTH-1:0] temp_S = (k_idx == 0) ? latched_S_0 : latched_S_1;
                    wire [DATA_WIDTH-1:0] temp_B = (k_idx == 0) ? latched_B_0 : latched_B_1;
                    wire [DATA_WIDTH-1:0] temp_Y = (k_idx == 0) ? latched_Y_0 : latched_Y_1;
                    wire [I_WIDTH-1:0] temp_I = (k_idx == 0) ? latched_I_0 : latched_I_1;
                    
                    // Calculate pop for species k_idx
                    reg [POP_WIDTH-1:0] temp_pop;
                    if (t < temp_B) begin
                        temp_pop = 0;
                    end else if (t <= temp_B + temp_Y) begin
                        wire [YEAR_WIDTH-1:0] diff_t_B = t - temp_B;
                        wire signed [POP_WIDTH:0] calc_inc = $signed({1'b0, temp_S}) + 
                                                              $signed({1'b0, temp_I}) * $signed({1'b0, diff_t_B});
                        temp_pop = (calc_inc[POP_WIDTH]) ? 0 : calc_inc[POP_WIDTH-1:0];
                    end else begin
                        wire [YEAR_WIDTH-1:0] diff_t_B_Y = t - temp_B - temp_Y;
                        wire signed [POP_WIDTH:0] calc_dec = $signed({1'b0, temp_I}) * $signed({1'b0, temp_Y}) - 
                                                              $signed({1'b0, temp_I}) * $signed({1'b0, diff_t_B_Y});
                        temp_pop = (calc_dec[POP_WIDTH] || diff_t_B_Y > temp_Y) ? 0 : calc_dec[POP_WIDTH-1:0];
                    end
                    
                    total <= total + temp_pop;
                    k_idx <= k_idx + 1;
                end else begin
                    // Done summing for this t
                    if (total > max_total) begin
                        state <= UPDATE_MAX;
                    end else begin
                        state <= INCREMENT;
                    end
                end
            end
            UPDATE_MAX: begin
                max_total <= total;
                state <= INCREMENT;
            end
            INCREMENT: begin
                // Move to next t
                if (phase == 0) begin
                    phase <= 1;
                    state <= PREPARE_T;
                end else begin
                    phase <= 0;
                    if (i_idx + 1 >= valid_count) begin
                        // All species processed
                        state <= DONE;
                    end else begin
                        i_idx <= i_idx + 1;
                        state <= PREPARE_T;
                    end
                end
            end
            DONE: begin
                done <= 1'b1;
                if (!start) begin
                    state <= IDLE;
                end
            end
            default: begin
                state <= IDLE;
            end
        endcase
    end
end

assign result = max_total;

endmodule