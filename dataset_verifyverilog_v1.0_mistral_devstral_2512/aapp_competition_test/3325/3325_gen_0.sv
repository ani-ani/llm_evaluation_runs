module water_height_calculator #(
    parameter MAX_N = 8,
    parameter DATA_WIDTH = 32,
    parameter FRAC_BITS = 16,
    parameter COORD_WIDTH = 12,
    parameter ITERATIONS = 20
)(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [4:0] N,
    input wire [10:0] D,
    input wire [11:0] L,
    input wire signed [COORD_WIDTH-1:0] x [MAX_N-1:0],
    input wire signed [COORD_WIDTH-1:0] y [MAX_N-1:0],
    output reg [DATA_WIDTH-1:0] h,
    output reg done
);

// State definitions
localparam [3:0] IDLE = 4'd0;
localparam [3:0] COMPUTE_A_TARGET = 4'd1;
localparam [3:0] BINARY_SEARCH_START = 4'd2;
localparam [3:0] COMPUTE_AREA = 4'd3;
localparam [3:0] COMPARE = 4'd4;
localparam [3:0] DONE = 4'd5;

reg [3:0] current_state, next_state;

// Internal registers
reg [DATA_WIDTH-1:0] a_target;
reg [DATA_WIDTH-1:0] h_min, h_max, h_mid;
reg [DATA_WIDTH-1:0] area_mid;
reg [4:0] iteration_count;

// Area computation signals
reg [DATA_WIDTH-1:0] current_h;
reg [3:0] clip_count;
reg [3:0] edge_index;
reg signed [COORD_WIDTH+15:0] clip_x [0:MAX_N+1];
reg signed [COORD_WIDTH+15:0] clip_y [0:MAX_N+1];

// Fixed-point multiplication
function [DATA_WIDTH-1:0] fp_mul(input [DATA_WIDTH-1:0] a, input [DATA_WIDTH-1:0] b);
    reg [DATA_WIDTH*2-1:0] prod;
    prod = a * b;
    fp_mul = prod >> FRAC_BITS;
endfunction

// Fixed-point division
function [DATA_WIDTH-1:0] fp_div(input [DATA_WIDTH-1:0] a, input [DATA_WIDTH-1:0] b);
    reg [DATA_WIDTH*2-1:0] dividend;
    dividend = a;
    dividend = dividend << FRAC_BITS;
    fp_div = dividend / b;
endfunction

// State machine
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        current_state <= IDLE;
        done <= 1'b0;
        h <= 32'd0;
        iteration_count <= 5'd0;
        clip_count <= 4'd0;
        edge_index <= 4'd0;
        a_target <= 32'd0;
        h_min <= 32'd0;
        h_max <= 32'd0;
        h_mid <= 32'd0;
        area_mid <= 32'd0;
        current_h <= 32'd0;
    end else begin
        current_state <= next_state;
        case (current_state)
            IDLE: begin
                if (start) begin
                    iteration_count <= 5'd0;
                    done <= 1'b0;
                    next_state <= COMPUTE_A_TARGET;
                end
            end

            COMPUTE_A_TARGET: begin
                a_target <= fp_div(L * 1000, D);
                next_state <= BINARY_SEARCH_START;
            end

            BINARY_SEARCH_START: begin
                h_max <= y[2] << FRAC_BITS;
                h_min <= 32'd0;
                h_mid <= (y[2] << FRAC_BITS) >> 1;
                next_state <= COMPUTE_AREA;
            end

            COMPUTE_AREA: begin
                current_h <= h_mid;
                clip_count <= 4'd0;
                edge_index <= 4'd0;
                next_state <= COMPARE;
            end

            COMPARE: begin
                if (iteration_count < ITERATIONS) begin
                    iteration_count <= iteration_count + 5'd1;
                    if (area_mid < a_target) begin
                        h_min <= h_mid;
                    end else begin
                        h_max <= h_mid;
                    end
                    h_mid <= (h_min + h_max) >> 1;
                    next_state <= COMPUTE_AREA;
                end else begin
                    h <= h_mid;
                    done <= 1'b1;
                    next_state <= DONE;
                end
            end

            DONE: begin
                done <= 1'b0;
                next_state <= IDLE;
            end

            default: next_state <= IDLE;
        endcase
    end
end

// Next state logic
always @(*) begin
    next_state = current_state;
    case (current_state)
        IDLE: if (start) next_state = COMPUTE_A_TARGET;
        COMPUTE_A_TARGET: next_state = BINARY_SEARCH_START;
        BINARY_SEARCH_START: next_state = COMPUTE_AREA;
        COMPUTE_AREA: next_state = COMPARE;
        COMPARE: ;
        DONE: next_state = IDLE;
        default: next_state = current_state;
    endcase
end

endmodule