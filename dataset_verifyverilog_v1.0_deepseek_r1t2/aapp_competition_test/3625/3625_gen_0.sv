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
    
    output reg [POP_WIDTH-1:0] result,      // Maximum total trees
    output reg done                         // Computation complete
);

// State machine states
localparam [2:0] IDLE = 3'd0, INIT = 3'd1, PREPARE_T = 3'd2, 
           COMPUTE_TOTAL = 3'd3, INCREMENT = 3'd5, DONE_STATE = 3'd6;

// Internal registers
reg [2:0] state, next_state;
reg [0:0] i_idx;                        // Outer loop: species index
reg [0:0] k_idx;                        // Inner loop: summation index
reg phase;                              // 0: B_i, 1: B_i+Y_i
reg [YEAR_WIDTH-1:0] t;                 // Current candidate year
reg [POP_WIDTH-1:0] total;              // Accumulator for current t
reg [POP_WIDTH-1:0] max_total;          // Maximum result

// Latched input data
reg [DATA_WIDTH-1:0] latched_S [0:1];
reg [DATA_WIDTH-1:0] latched_B [0:1];
reg [DATA_WIDTH-1:0] latched_Y [0:1];
reg [I_WIDTH-1:0] latched_I [0:1];

// Combinational population calculation for species k at year t
wire [POP_WIDTH-1:0] pop_k;
wire [YEAR_WIDTH-1:0] diff_t_B = t - latched_B[k_idx];
wire [YEAR_WIDTH-1:0] diff_t_BY = t - latched_B[k_idx] - latched_Y[k_idx];
wire signed [POP_WIDTH:0] inc_pop = latched_S[k_idx] + (latched_I[k_idx] * diff_t_B);
wire signed [POP_WIDTH:0] dec_pop = (latched_I[k_idx] * latched_Y[k_idx]) - (latched_I[k_idx] * diff_t_BY);
wire signed [POP_WIDTH:0] peak_pop = latched_S[k_idx] + (latched_I[k_idx] * latched_Y[k_idx]);

assign pop_k = (t < latched_B[k_idx]) ? POP_WIDTH'(0) :
               (t <= (latched_B[k_idx] + latched_Y[k_idx])) ? inc_pop[POP_WIDTH-1:0] :
               (dec_pop > 0) ? dec_pop[POP_WIDTH-1:0] : POP_WIDTH'(0);

// State transition
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        i_idx <= 1'b0;
        k_idx <= 1'b0;
        phase <= 1'b0;
        t <= YEAR_WIDTH'(0);
        total <= POP_WIDTH'(0);
        max_total <= POP_WIDTH'(0);
        latched_S[0] <= DATA_WIDTH'(0);
        latched_S[1] <= DATA_WIDTH'(0);
        latched_B[0] <= DATA_WIDTH'(0);
        latched_B[1] <= DATA_WIDTH'(0);
        latched_Y[0] <= DATA_WIDTH'(0);
        latched_Y[1] <= DATA_WIDTH'(0);
        latched_I[0] <= I_WIDTH'(0);
        latched_I[1] <= I_WIDTH'(0);
        done <= 1'b0;
        result <= POP_WIDTH'(0);
    end else begin
        state <= next_state;
        case (state)
            IDLE: begin
                done <= 1'b0;
                if (start) begin
                    next_state <= INIT;
                end else begin
                    next_state <= IDLE;
                end
            end
            
            INIT: begin
                latched_S[0] <= S_0;
                latched_B[0] <= B_0;
                latched_Y[0] <= Y_0;
                latched_I[0] <= I_0;
                latched_S[1] <= S_1;
                latched_B[1] <= B_1;
                latched_Y[1] <= Y_1;
                latched_I[1] <= I_1;
                max_total <= POP_WIDTH'(0);
                i_idx <= 1'b0;
                phase <= 1'b0;
                next_state <= PREPARE_T;
            end
            
            PREPARE_T: begin
                if (phase) begin
                    t <= latched_B[i_idx] + latched_Y[i_idx];
                end else begin
                    t <= latched_B[i_idx];
                end
                total <= POP_WIDTH'(0);
                k_idx <= 1'b0;
                next_state <= COMPUTE_TOTAL;
            end
            
            COMPUTE_TOTAL: begin
                if (k_idx < valid_count) begin
                    total <= total + pop_k;
                    k_idx <= k_idx + 1'b1;
                    next_state <= COMPUTE_TOTAL;
                end else begin
                    if (total > max_total) begin
                        max_total <= total;
                    end
                    next_state <= INCREMENT;
                end
            end
            
            INCREMENT: begin
                if (phase) begin
                    phase <= 1'b0;
                    i_idx <= i_idx + 1'b1;
                    if (i_idx == N-1) begin
                        next_state <= DONE_STATE;
                    end else begin
                        next_state <= PREPARE_T;
                    end
                end else begin
                    phase <= 1'b1;
                    next_state <= PREPARE_T;
                end
            end
            
            DONE_STATE: begin
                done <= 1'b1;
                result <= max_total;
                if (!start) begin
                    next_state <= IDLE;
                end else begin
                    next_state <= DONE_STATE;
                end
            end
            
            default: next_state <= IDLE;
        endcase
    end
end

endmodule