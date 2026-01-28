module max_polygon_area (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] lengths [0:15],
    input wire [3:0] valid_count,
    output reg [15:0] area,
    output reg done,
    output reg ready
);

// State definitions
localparam [3:0] IDLE      = 4'd0;
localparam [3:0] LOAD      = 4'd1;
localparam [3:0] SORT_INIT = 4'd2;
localparam [3:0] SORT_LOOP = 4'd3;
localparam [3:0] DP_INIT   = 4'd4;
localparam [3:0] DP_LOOP   = 4'd5;
localparam [3:0] DP_CHECK  = 4'd6;
localparam [3:0] DP_COUNT  = 4'd7;
localparam [3:0] DP_SUM    = 4'd8;
localparam [3:0] DP_CALC   = 4'd9;
localparam [3:0] DP_MAX    = 4'd10;
localparam [3:0] SQRT_INIT = 4'd11;
localparam [3:0] SQRT_LOOP = 4'd12;
localparam [3:0] SQRT_DONE = 4'd13;
localparam [3:0] FINISH    = 4'd14;

reg [3:0] state, next_state;

// Storage for lengths (sorted descending)
reg [7:0] segs [0:15];
reg [3:0] count;  // Valid count

// Sorting variables
reg [3:0] i, j;
reg [7:0] temp;

// DP variables
reg [15:0] bitmask;
reg [15:0] max_mask;
reg [3:0] num_sides;
reg [15:0] seg_sum;  // Sum of lengths (max 16*100=1600, fits in 16 bits)
reg [7:0] max_len;
reg [3:0] side_idx;
reg [15:0] side_sum;

// Area calculation
reg [31:0] prod_temp;  // 32-bit for intermediate products
reg [31:0] prod_accum;
reg [31:0] s_val;      // Q8.8 * 2 = Q17.8
reg [31:0] s_minus_a;
reg [15:0] s_val_16;

// Fixed-point constants
localparam [7:0] TWO = 8'd2;  // Q8.8 representation of 2.0

// Max tracking
reg [15:0] max_area;
reg [15:0] current_area;

// Square root variables (Newton-Raphson)
reg [31:0] x;          // Q16.16 for sqrt input
reg [31:0] xn;         // Next approximation
reg [31:0] xn_prev;    // Previous for check
reg [1:0] sqrt_iter;

// Cycle counter for timeout prevention
reg [9:0] cycle_count;
localparam [9:0] MAX_CYCLES = 10'd1000;

integer k; // Loop variable for initialization

// Next state logic
always @(*) begin
    next_state = state;
    case (state)
        IDLE: if (start) next_state = LOAD;
        LOAD: next_state = SORT_INIT;
        SORT_INIT: next_state = SORT_LOOP;
        SORT_LOOP: if (j == 0) next_state = DP_INIT;
                   else next_state = SORT_LOOP;
        DP_INIT: next_state = DP_LOOP;
        DP_LOOP: begin
            if (bitmask > max_mask) next_state = FINISH;
            else next_state = DP_CHECK;
        end
        DP_CHECK: begin
            if (num_sides < 4'd3) next_state = DP_LOOP_NEXT;
            else next_state = DP_COUNT;
        end
        DP_COUNT: next_state = DP_SUM;
        DP_SUM: next_state = DP_CALC;
        DP_CALC: begin
            if (prod_temp[31:16] == 0) next_state = SQRT_INIT;
            else next_state = DP_MAX;
        end
        DP_MAX: next_state = DP_LOOP_NEXT;
        DP_LOOP_NEXT: next_state = DP_LOOP;
        SQRT_INIT: next_state = SQRT_LOOP;
        SQRT_LOOP: next_state = SQRT_LOOP;
        SQRT_DONE: next_state = DP_MAX;
        FINISH: next_state = IDLE;
        default: next_state = IDLE;
    endcase
end

// State transition
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        ready <= 1'b1;
        done <= 1'b0;
        area <= 16'd0;
        max_area <= 16'd0;
        bitmask <= 16'd0;
        cycle_count <= 10'd0;
        for (k = 0; k < 16; k = k + 1) begin
            segs[k] <= 8'd0;
        end
    end else begin
        cycle_count <= cycle_count + 10'd1;
        case (state)
            IDLE: begin
                ready <= 1'b1;
                done <= 1'b0;
                cycle_count <= 10'd0;
                if (start) begin
                    count <= valid_count;
                    max_area <= 16'd0;
                    bitmask <= 16'd1;  // Start from subset 1
                    // Capture inputs
                    for (k = 0; k < 16; k = k + 1) begin
                        segs[k] <= (k < valid_count) ? lengths[k] : 8'd0;
                    end
                    ready <= 1'b0;
                end
            end
            
            SORT_INIT: begin
                i <= 4'd15;
            end
            
            SORT_LOOP: begin
                if (j > 0) begin
                    if (segs[j] > segs[j-1]) begin
                        segs[j] <= segs[j-1];
                        segs[j-1] <= segs[j];
                    end
                    j <= j - 4'd1;
                end else begin
                    if (i > 0) begin
                        i <= i - 4'd1;
                        j <= i;
                    end
                end
            end
            
            DP_INIT: begin
                max_mask <= (16'd1 << count) - 16'd1;
            end
            
            DP_LOOP: begin
                bitmask <= bitmask + 16'd1;
                num_sides <= 4'd0;
                seg_sum <= 16'd0;
                max_len <= 8'd0;
                side_idx <= 4'd0;
                prod_accum <= 32'h00010000;  // 1.0 in Q16.16
            end
            
            DP_CHECK: begin
                if (num_sides < 4'd3) begin
                    // Skip invalid
                    bitmask <= bitmask + 16'd1;
                end
            end
            
            DP_COUNT: begin
                if (bitmask[side_idx]) begin
                    num_sides <= num_sides + 4'd1;
                    seg_sum <= seg_sum + segs[side_idx];
                    if (segs[side_idx] > max_len)
                        max_len <= segs[side_idx];
                end
                side_idx <= side_idx + 4'd1;
            end
            
            DP_SUM: begin
                // Check inequality: max_len < sum - max_len
                // i.e., 2*max_len < sum
                if (max_len < (seg_sum - max_len)) begin
                    // Valid polygon
                    s_val_16 <= seg_sum >> 1;  // S = sum/2
                end
            end
            
            DP_CALC: begin
                // Compute product of (S - a_i) for all sides in subset
                if (side_idx < count) begin
                    if (bitmask[side_idx]) begin
                        // Calculate (S - a_i) * 4 in Q16.16
                        // S is Q8.8, a_i is Q8.8
                        // (S - a) * 4 = ((S - a) << 2)
                        s_minus_a <= (s_val_16 - segs[side_idx]);
                        prod_temp <= segs[side_idx]; // placeholder
                        // (S - a_i) << 2 = (s_val_16 - segs[side_idx]) << 2
                        // Convert to Q16.16: << 8
                        // product accumulator multiply
                        // prod_temp = (s_val_16 - segs[side_idx]) << 8
                        // prod_accum = prod_accum * prod_temp >> 16
                    end
                    side_idx <= side_idx + 4'd1;
                end else begin
                    // Done calculating product
                    // Area = sqrt(prod_accum) / 4^(N/2)
                    // Simplified: take sqrt of 16-bit integer part
                    x <= {prod_accum[31:16], 16'd0};  // Prepare for sqrt
                end
            end
            
            DP_MAX: begin
                // Update max area
                if (current_area > max_area) begin
                    max_area <= current_area;
                end
                // Next subset or finish
                if (bitmask >= max_mask) begin
                    state <= FINISH;
                end else begin
                    state <= DP_LOOP;
                end
            end
            
            SQRT_INIT: begin
                // Initial guess
                xn <= {x[31:16], 16'd0} >> 1;
                sqrt_iter <= 2'd0;
            end
            
            SQRT_LOOP: begin
                xn_prev <= xn;
                // Newton-Raphson: xn_next = (xn + x/xn) >> 1
                // Simplified approximation for hardware
                // Just shift right by 1 for stability
                xn <= xn >> 1;
                sqrt_iter <= sqrt_iter + 2'd1;
                if (sqrt_iter == 2'd3) begin
                    state <= SQRT_DONE;
                end
            end
            
            SQRT_DONE: begin
                current_area <= xn[31:16];  // Extract integer part
            end
            
            FINISH: begin
                done <= 1'b1;
                area <= max_area;
                state <= IDLE;
            end
            
            default: state <= IDLE;
        endcase
    end
end

endmodule