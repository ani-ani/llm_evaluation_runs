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
localparam [3:0] IDLE               = 4'd0;
localparam [3:0] COMPUTE_A_TARGET   = 4'd1;
localparam [3:0] BINARY_INIT        = 4'd2;
localparam [3:0] COMPUTE_AREA       = 4'd3;
localparam [3:0] COMPARE_AREA       = 4'd4;
localparam [3:0] UPDATE_SEARCH      = 4'd5;
localparam [3:0] COMPLETION         = 4'd6;

reg [3:0] state, next_state;

// Fixed-point representations
reg [DATA_WIDTH-1:0] h_min, h_max, h_mid;
reg [DATA_WIDTH-1:0] a_target;
reg [DATA_WIDTH-1:0] area_mid;

// Iteration control
reg [4:0] iter_count;
localparam [4:0] MAX_ITER = 5'd20;

// Area computation registers
reg [4:0] edge_counter;
reg signed [COORD_WIDTH+FRAC_BITS-1:0] clip_x [0:MAX_N+1];
reg signed [COORD_WIDTH+FRAC_BITS-1:0] clip_y [0:MAX_N+1];
reg [4:0] clip_count;
reg polygon_complete;
reg poly_valid;

// Temporary storage
reg [DATA_WIDTH-1:0] shoelace_sum;
reg [4:0] poly_idx;
reg [DATA_WIDTH-1:0] current_area;

integer i; // Loop variable

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        done <= 1'b0;
        h <= {DATA_WIDTH{1'b0}};
        h_min <= {DATA_WIDTH{1'b0}};
        h_max <= {DATA_WIDTH{1'b0}};
        h_mid <= {DATA_WIDTH{1'b0}};
        a_target <= {DATA_WIDTH{1'b0}};
        area_mid <= {DATA_WIDTH{1'b0}};
        iter_count <= 5'd0;
        shoelace_sum <= {DATA_WIDTH{1'b0}};
        current_area <= {DATA_WIDTH{1'b0}};
        edge_counter <= 5'd0;
        clip_count <= 5'd0;
        polygon_complete <= 1'b0;
        poly_valid <= 1'b0;
        poly_idx <= 5'd0;
        
        for (i=0; i<MAX_N+2; i=i+1) begin
            clip_x[i] <= {COORD_WIDTH+FRAC_BITS{1'b0}};
            clip_y[i] <= {COORD_WIDTH+FRAC_BITS{1'b0}};
        end
    end else begin
        state <= next_state;
        
        case (state)
            IDLE: begin
                done <= 1'b0;
                iter_count <= 5'd0;
                if (start) begin
                    a_target <= (L * 1000) << FRAC_BITS;
                    a_target <= a_target / D;
                end
            end
            
            COMPUTE_A_TARGET: begin
                // a_target already computed in IDLE
            end
            
            BINARY_INIT: begin
                // Find maximum y coordinate
                h_min <= {DATA_WIDTH{1'b0}};
                h_max <= {DATA_WIDTH{1'b0}};
                for (i=0; i<MAX_N; i=i+1) begin
                    if (y[i] > h_max[(COORD_WIDTH+FRAC_BITS-1):FRAC_BITS]) begin
                        h_max <= y[i] << FRAC_BITS;
                    end
                end
                h_mid <= (h_min + h_max) >> 1;
            end
            
            COMPUTE_AREA: begin
                if (edge_counter < N+1) begin
                    reg signed [COORD_WIDTH+FRAC_BITS-1:0] x1, y1, x2, y2;
                    reg signed [COORD_WIDTH+FRAC_BITS-1:0] h_fp;
                    
                    // Get current and next vertex
                    x1 = x[(edge_counter) % N] << FRAC_BITS;
                    y1 = y[(edge_counter) % N] << FRAC_BITS;
                    x2 = x[(edge_counter+1) % N] << FRAC_BITS;
                    y2 = y[(edge_counter+1) % N] << FRAC_BITS;
                    h_fp = h_mid;
                    
                    // Classification
                    if (y1 < h_fp && y2 < h_fp) begin
                        // Below waterline - discard
                    end else if (y1 >= h_fp && y2 >= h_fp) begin
                        // Entirely above - add point
                        clip_x[clip_count] <= x2;
                        clip_y[clip_count] <= y2;
                        clip_count <= clip_count + 5'd1;
                    end else begin
                        // Compute intersection
                        reg [COORD_WIDTH+FRAC_BITS-1:0] dx, dy, t;
                        reg [DATA_WIDTH-1:0] lerp_x;
                        
                        dy = y2 - y1;
                        if (dy != 0) begin
                            t = ((h_fp - y1) << FRAC_BITS) / dy;
                            lerp_x = x1 + ((x2 - x1) * t) >> FRAC_BITS;
                            
                            if (y1 < h_fp) begin
                                clip_x[clip_count] <= lerp_x;
                                clip_y[clip_count] <= h_fp;
                                clip_count <= clip_count + 5'd1;
                                clip_x[clip_count] <= x2;
                                clip_y[clip_count] <= y2;
                                clip_count <= clip_count + 5'd1;
                            end else begin
                                clip_x[clip_count] <= lerp_x;
                                clip_y[clip_count] <= h_fp;
                                clip_count <= clip_count + 5'd1;
                            end
                        end
                    end
                    edge_counter <= edge_counter + 5'd1;
                end else begin
                    polygon_complete <= 1'b1;
                end
            end
            
            COMPARE_AREA: begin
                // Shoelace formula calculation
                if (poly_idx < clip_count) begin
                    shoelace_sum <= shoelace_sum + 
                        (clip_x[poly_idx] * clip_y[(poly_idx+1) % clip_count]) -
                        (clip_x[(poly_idx+1) % clip_count] * clip_y[poly_idx]);
                    poly_idx <= poly_idx + 5'd1;
                end else begin
                    current_area <= (shoelace_sum >= 0) ? 
                                     (shoelace_sum >> (FRAC_BITS + 1)) : 
                                     ((-shoelace_sum) >> (FRAC_BITS + 1));
                    area_mid <= current_area;
                    shoelace_sum <= {DATA_WIDTH{1'b0}};
                    poly_idx <= 5'd0;
                end
            end
            
            UPDATE_SEARCH: begin
                if (iter_count < MAX_ITER) begin
                    if (current_area < a_target) begin
                        h_min <= h_mid;
                    end else begin
                        h_max <= h_mid;
                    end
                    h_mid <= (h_min + h_max) >> 1;
                    iter_count <= iter_count + 5'd1;
                end
            end
            
            COMPLETION: begin
                h <= h_mid;
                done <= 1'b1;
            end
            
            default: state <= IDLE;
        endcase
    end
end

always @* begin
    next_state = state;
    case (state)
        IDLE: if (start) next_state = COMPUTE_A_TARGET;
        COMPUTE_A_TARGET: next_state = BINARY_INIT;
        BINARY_INIT: next_state = COMPUTE_AREA;
        COMPUTE_AREA: if (polygon_complete) next_state = COMPARE_AREA;
        COMPARE_AREA: if (poly_idx == clip_count) next_state = UPDATE_SEARCH;
        UPDATE_SEARCH: next_state = (iter_count < MAX_ITER) ? COMPUTE_AREA : COMPLETION;
        COMPLETION: next_state = IDLE;
        default: next_state = IDLE;
    endcase
end

endmodule