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
localparam [2:0] IDLE = 3'd0;
localparam [2:0] COMPUTE_A_TARGET = 3'd1;
localparam [2:0] BINARY_SEARCH_START = 3'd2;
localparam [2:0] COMPUTE_AREA = 3'd3;
localparam [2:0] COMPARE = 3'd4;
localparam [2:0] DONE = 3'd5;

reg [2:0] state, next_state;

// Internal registers
reg [DATA_WIDTH-1:0] a_target;
reg [DATA_WIDTH-1:0] h_min, h_max, h_mid;
reg [DATA_WIDTH-1:0] area_mid;
reg [4:0] iteration_count;

// Fixed-point multiplication function
function [DATA_WIDTH-1:0] fp_mul(input [DATA_WIDTH-1:0] a, input [DATA_WIDTH-1:0] b);
    reg [DATA_WIDTH*2-1:0] prod;
    prod = a * b;
    fp_mul = prod >> FRAC_BITS;
endfunction

// Fixed-point division function (truncating division)
function [DATA_WIDTH-1:0] fp_div(input [DATA_WIDTH-1:0] a, input [DATA_WIDTH-1:0] b);
    reg [DATA_WIDTH*2-1:0] dividend;
    dividend = a;
    dividend = dividend << FRAC_BITS;
    fp_div = dividend / b;
endfunction

// Area computation state machine
reg [2:0] area_state;
localparam [2:0] AREA_IDLE = 3'd0;
localparam [2:0] AREA_INIT = 3'd1;
localparam [2:0] AREA_PROCESS_EDGES = 3'd2;
localparam [2:0] AREA_COMPUTE = 3'd3;
localparam [2:0] AREA_DONE = 3'd4;

reg [3:0] edge_idx;
reg signed [COORD_WIDTH+FRAC_BITS-1:0] area_sum;
reg signed [COORD_WIDTH+FRAC_BITS-1:0] x0, y0, x1, y1;
reg signed [COORD_WIDTH+FRAC_BITS+1:0] cross_product;
reg signed [COORD_WIDTH+FRAC_BITS+1:0] cross_sum;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        done <= 1'b0;
        h <= 32'd0;
        iteration_count <= 5'd0;
        a_target <= 32'd0;
        h_min <= 32'd0;
        h_max <= 32'd0;
        h_mid <= 32'd0;
        area_mid <= 32'd0;
        area_state <= AREA_IDLE;
        edge_idx <= 4'd0;
        area_sum <= 32'd0;
        cross_sum <= 32'd0;
        x0 <= 32'd0;
        y0 <= 32'd0;
        x1 <= 32'd0;
        y1 <= 32'd0;
        cross_product <= 32'd0;
    end else begin
        state <= next_state;
        
        case (state)
            IDLE: begin
                done <= 1'b0;
                if (start) begin
                    iteration_count <= 5'd0;
                end
            end
            
            COMPUTE_A_TARGET: begin
                // a_target = (L * 1000) / D * 2^16
                // L is 12-bit, D is 11-bit
                a_target <= fp_div({{20{1'b0}}, L} * 32'd1000, {{21{1'b0}}, D});
            end
            
            BINARY_SEARCH_START: begin
                // Set h_max to maximum y coordinate (using y[2] as specified in problem)
                h_max <= y[2] << FRAC_BITS;
                h_min <= 32'd0;
                h_mid <= (y[2] << (FRAC_BITS - 1)); // h_max / 2
            end
            
            COMPUTE_AREA: begin
                // Area calculation state machine
                case (area_state)
                    AREA_IDLE: begin
                        area_state <= AREA_INIT;
                    end
                    
                    AREA_INIT: begin
                        area_sum <= 32'd0;
                        cross_sum <= 32'd0;
                        edge_idx <= 4'd0;
                        area_state <= AREA_PROCESS_EDGES;
                    end
                    
                    AREA_PROCESS_EDGES: begin
                        if (edge_idx < N) begin
                            // Get vertices for edge (edge_idx, next_idx)
                            x0 <= x[edge_idx] << FRAC_BITS;
                            y0 <= y[edge_idx] << FRAC_BITS;
                            
                            // Get next vertex with wrap-around
                            if (edge_idx == N - 1) begin
                                x1 <= x[0] << FRAC_BITS;
                                y1 <= y[0] << FRAC_BITS;
                            end else begin
                                x1 <= x[edge_idx + 1] << FRAC_BITS;
                                y1 <= y[edge_idx + 1] << FRAC_BITS;
                            end
                            
                            area_state <= AREA_COMPUTE;
                        end else begin
                            area_state <= AREA_DONE;
                        end
                    end
                    
                    AREA_COMPUTE: begin
                        // Shoelace formula: sum(x_i * y_{i+1} - x_{i+1} * y_i)
                        cross_product <= (x0 * y1) - (x1 * y0);
                        cross_sum <= cross_sum + ((x0 * y1) - (x1 * y0));
                        edge_idx <= edge_idx + 4'd1;
                        area_state <= AREA_PROCESS_EDGES;
                    end
                    
                    AREA_DONE: begin
                        // Divide by 2 and take absolute value
                        // area = |cross_sum| / 2
                        if (cross_sum >= 0) begin
                            area_mid <= cross_sum >> 1;
                        end else begin
                            area_mid <= (~cross_sum + 1) >> 1;
                        end
                        area_state <= AREA_IDLE;
                    end
                    
                    default: area_state <= AREA_IDLE;
                endcase
            end
            
            COMPARE: begin
                if (iteration_count < ITERATIONS) begin
                    iteration_count <= iteration_count + 5'd1;
                    
                    if (area_mid < a_target) begin
                        h_min <= h_mid;
                    end else begin
                        h_max <= h_mid;
                    end
                    
                    // Update h_mid
                    h_mid <= (h_min + h_max) >> 1;
                end else begin
                    h <= h_mid;
                    done <= 1'b1;
                end
            end
            
            DONE: begin
                done <= 1'b0;
            end
        endcase
    end
end

always @(*) begin
    next_state = state;
    case (state)
        IDLE: begin
            if (start) next_state = COMPUTE_A_TARGET;
        end
        
        COMPUTE_A_TARGET: begin
            next_state = BINARY_SEARCH_START;
        end
        
        BINARY_SEARCH_START: begin
            next_state = COMPUTE_AREA;
        end
        
        COMPUTE_AREA: begin
            if (area_state == AREA_IDLE && area_state != AREA_IDLE) begin
                // Wait for area calculation to complete
                // Area calculation triggers state changes internally
            end
            if (area_state == AREA_IDLE) begin
                next_state = COMPARE;
            end
        end
        
        COMPARE: begin
            if (iteration_count >= ITERATIONS) begin
                next_state = DONE;
            end else begin
                next_state = COMPUTE_AREA;
            end
        end
        
        DONE: begin
            next_state = IDLE;
        end
        
        default: next_state = IDLE;
    endcase
end

endmodule