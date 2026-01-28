module starship_max_distance #(
    parameter N = 4,              // Number of stars (1-8)
    parameter STEPS = 256,        // Number of discrete angle steps
    parameter DATA_WIDTH = 32,    // Q16.16 fixed-point width
    parameter ANGLE_WIDTH = 16,   // Angle representation width
    parameter FRAC_BITS = 16      // Fractional bits in Q format
)(
    input wire clk,
    input wire rst_n,
    input wire start,
    // Star parameters - individual ports for compatibility
    input wire [DATA_WIDTH-1:0] t_0, t_1, t_2, t_3, t_4, t_5, t_6, t_7,
    input wire [DATA_WIDTH-1:0] s_0, s_1, s_2, s_3, s_4, s_5, s_6, s_7,
    input wire [ANGLE_WIDTH-1:0] a_0, a_1, a_2, a_3, a_4, a_5, a_6, a_7,
    output reg [DATA_WIDTH-1:0] max_distance,
    output reg done
);

// Constants
localparam signed [DATA_WIDTH-1:0] TWO_PI_Q16 = 32'h0006487F; // 2π in Q16.16 ≈ 411771
localparam [ANGLE_WIDTH-1:0] TWO_PI_RAW = 16'd411771; // 2π in angle units

// State definitions
localparam [2:0] STATE_IDLE = 3'd0;
localparam [2:0] STATE_INIT_ANGLE = 3'd1;
localparam [2:0] STATE_RESET_SUM = 3'd2;
localparam [2:0] STATE_ADD_STAR = 3'd3;
localparam [2:0] STATE_CHECK_DONE = 3'd4;
localparam [2:0] STATE_DONE = 3'd5;

// Internal registers
reg [2:0] state;
reg [7:0] angle_step;           // Current angle step counter
reg [2:0] star_idx;             // Current star index
reg signed [DATA_WIDTH-1:0] current_sum;
reg signed [DATA_WIDTH-1:0] max_sum;
reg signed [ANGLE_WIDTH-1:0] current_angle;

// Combinational logic for star parameter selection
wire signed [DATA_WIDTH-1:0] t_sel = 
    (star_idx == 0) ? t_0 : (star_idx == 1) ? t_1 : 
    (star_idx == 2) ? t_2 : (star_idx == 3) ? t_3 :
    (star_idx == 4) ? t_4 : (star_idx == 5) ? t_5 :
    (star_idx == 6) ? t_6 : t_7;

wire signed [DATA_WIDTH-1:0] s_sel = 
    (star_idx == 0) ? s_0 : (star_idx == 1) ? s_1 : 
    (star_idx == 2) ? s_2 : (star_idx == 3) ? s_3 :
    (star_idx == 4) ? s_4 : (star_idx == 5) ? s_5 :
    (star_idx == 6) ? s_6 : s_7;

wire signed [ANGLE_WIDTH-1:0] a_sel = 
    (star_idx == 0) ? a_0 : (star_idx == 1) ? a_1 : 
    (star_idx == 2) ? a_2 : (star_idx == 3) ? a_3 :
    (star_idx == 4) ? a_4 : (star_idx == 5) ? a_5 :
    (star_idx == 6) ? a_6 : a_7;

// Circular distance calculation
wire signed [ANGLE_WIDTH-1:0] diff_abs = 
    (current_angle > a_sel) ? (current_angle - a_sel) : (a_sel - current_angle);
wire signed [ANGLE_WIDTH-1:0] diff_complement = TWO_PI_RAW - diff_abs;
wire signed [ANGLE_WIDTH-1:0] dist = 
    (diff_abs < diff_complement) ? diff_abs : diff_complement;

// Fixed-point multiplication for s * dist
wire signed [DATA_WIDTH*2-1:0] product_raw = s_sel * dist;
wire signed [DATA_WIDTH-1:0] product_q16 = product_raw[FRAC_BITS*2 +: DATA_WIDTH];

// Contribution calculation with clamping
wire signed [DATA_WIDTH-1:0] contrib = 
    (t_sel > product_q16) ? (t_sel - product_q16) : 0;

// Main state machine
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= STATE_IDLE;
        done <= 0;
        max_distance <= 0;
        angle_step <= 0;
        star_idx <= 0;
        current_sum <= 0;
        max_sum <= 0;
        current_angle <= 0;
    end else begin
        case (state)
            STATE_IDLE: begin
                done <= 0;
                if (start) begin
                    state <= STATE_INIT_ANGLE;
                    angle_step <= 0;
                    max_sum <= 0;
                end
            end
            
            STATE_INIT_ANGLE: begin
                // Calculate current_angle = 2π * angle_step / STEPS
                // For STEPS=256: current_angle = (angle_step * TWO_PI_Q16) >> 8
                current_angle <= (angle_step * TWO_PI_Q16) >> 8;
                state <= STATE_RESET_SUM;
            end
            
            STATE_RESET_SUM: begin
                current_sum <= 0;
                star_idx <= 0;
                state <= STATE_ADD_STAR;
            end
            
            STATE_ADD_STAR: begin
                current_sum <= current_sum + contrib;
                
                if (star_idx == N-1) begin
                    // All stars processed for this angle
                    if (current_sum > max_sum)
                        max_sum <= current_sum;
                    state <= STATE_CHECK_DONE;
                end else begin
                    star_idx <= star_idx + 1;
                end
            end
            
            STATE_CHECK_DONE: begin
                if (angle_step == STEPS-1) begin
                    state <= STATE_DONE;
                end else begin
                    angle_step <= angle_step + 1;
                    state <= STATE_INIT_ANGLE;
                end
            end
            
            STATE_DONE: begin
                done <= 1;
                max_distance <= max_sum;
                state <= STATE_IDLE;
            end
            
            default: state <= STATE_IDLE;
        endcase
    end
end

endmodule