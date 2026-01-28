module phaser_opt #(
    parameter MAX_ROOMS = 8,
    parameter COORD_BITS = 10,  // 10 bits for coordinates 0-1000
    parameter L_BITS = 10,      // 10 bits for length 0-1000
    parameter DATA_WIDTH = COORD_BITS,
    parameter ARRAY_SIZE = 4*MAX_ROOMS + 1  // 4 coords per room + ℓ
)(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [DATA_WIDTH-1:0] arr [0:ARRAY_SIZE-1],  // Flattened coordinates and ℓ
    input wire [3:0] num_rooms,  // Number of rooms (1 to MAX_ROOMS)
    output reg [7:0] result,
    output reg done
);

    // State machine states
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] LOAD = 3'd1;
    localparam [2:0] INIT = 3'd2;
    localparam [2:0] LOOP_I = 3'd3;
    localparam [2:0] LOOP_J = 3'd4;
    localparam [2:0] COMPUTE = 3'd5;
    localparam [2:0] UPDATE_MAX = 3'd6;
    localparam [2:0] DONE = 3'd7;
    
    reg [2:0] state, next_state;
    
    // Internal storage
    reg [COORD_BITS-1:0] coords [0:4*MAX_ROOMS-1];  // Room coordinates
    reg [L_BITS-1:0] ell;                            // Beam length
    reg [5:0] i;                                     // Start corner index
    reg [5:0] j;                                     // Direction corner index
    reg [7:0] max_hit;                               // Maximum rooms hit
    reg [7:0] current_hit;                           // Current hit count
    
    // Fixed-point arithmetic (Q8.8)
    localparam FRAC_BITS = 8;
    localparam FP_WIDTH = 16;
    reg [FP_WIDTH-1:0] x1, y1, x2, y2;  // Segment endpoints in fixed-point
    reg [FP_WIDTH-1:0] dx, dy, d, ell_fp;
    
    // State transition
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result <= 8'd0;
        end else begin
            state <= next_state;
        end
    end
    
    // Next state logic
    always @(*) begin
        case (state)
            IDLE:    next_state = start ? LOAD : IDLE;
            LOAD:    next_state = INIT;
            INIT:    next_state = LOOP_I;
            LOOP_I:  next_state = (i < 4*num_rooms) ? LOOP_J : DONE;
            LOOP_J:  next_state = (j < 4*num_rooms) ? (i != j ? COMPUTE : LOOP_J) : LOOP_I;
            COMPUTE: next_state = UPDATE_MAX;
            UPDATE_MAX: next_state = LOOP_J;
            DONE:    next_state = IDLE;
            default: next_state = IDLE;
        endcase
    end
    
    // Datapath
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            i <= 6'd0;
            j <= 6'd0;
            max_hit <= 8'd0;
            current_hit <= 8'd0;
            done <= 1'b0;
            result <= 8'd0;
        end else begin
            case (state)
                LOAD: begin
                    // Load coordinates and ℓ from arr
                    integer k;
                    for (k = 0; k < 4*MAX_ROOMS; k = k + 1) begin
                        if (k < 4*num_rooms) begin
                            coords[k] <= arr[k];
                        end else begin
                            coords[k] <= 10'd0;
                        end
                    end
                    ell <= arr[4*num_rooms];
                end
                INIT: begin
                    i <= 6'd0;
                    j <= 6'd0;
                    max_hit <= 8'd0;
                end
                LOOP_I: begin
                    i <= i + 6'd1;
                    j <= 6'd0;
                end
                LOOP_J: begin
                    if (j < 4*num_rooms) begin
                        j <= j + 6'd1;
                    end
                end
                COMPUTE: begin
                    // Get coordinates of corners i and j
                    x1 <= {coords[i], 8'd0};
                    y1 <= {coords[i+1], 8'd0};
                    x2 <= {coords[j], 8'd0};
                    y2 <= {coords[j+1], 8'd0};
                    
                    // Compute direction vector (dx, dy) in fixed-point
                    dx <= x2 - x1;
                    dy <= y2 - y1;
                    
                    // Compute distance d = sqrt(dx^2 + dy^2)
                    // Using fixed-point arithmetic
                    reg [FP_WIDTH-1:0] dx_sq, dy_sq, sum_sq;
                    dx_sq <= dx * dx;
                    dy_sq <= dy * dy;
                    sum_sq <= dx_sq + dy_sq;
                    
                    // Simple approximation for sqrt (for synthesis)
                    // In real implementation, use iterative method
                    d <= sum_sq >> FRAC_BITS;
                    
                    // Compute unit vector (dx/d, dy/d)
                    // Scale to fixed-point
                    dx <= (dx << FRAC_BITS) / d;
                    dy <= (dy << FRAC_BITS) / d;
                    
                    // Compute endpoint: x2 = x1 + (dx)*ell, y2 = y1 + (dy)*ell
                    ell_fp <= {ell, 8'd0};
                    x2 <= x1 + (dx * ell_fp) >> FRAC_BITS;
                    y2 <= y1 + (dy * ell_fp) >> FRAC_BITS;
                    
                    // Count rectangles intersected by segment (x1,y1)-(x2,y2)
                    // Placeholder: actual implementation would check intersections
                    current_hit <= 8'd0;
                end
                UPDATE_MAX: begin
                    if (current_hit > max_hit) begin
                        max_hit <= current_hit;
                    end
                end
                DONE: begin
                    done <= 1'b1;
                    result <= max_hit;
                end
            endcase
        end
    end

endmodule