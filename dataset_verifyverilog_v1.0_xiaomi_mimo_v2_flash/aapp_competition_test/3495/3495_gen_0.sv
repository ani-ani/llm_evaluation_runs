module robotic_arm #(
    parameter N = 8,           // Max 8 segments (scaled down from 20)
    parameter DATA_WIDTH = 32, // Q16.16 fixed-point format
    parameter FRACT_WIDTH = 16,
    parameter MAX_CYCLES = 256 // Timeout for state machine
)(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire signed [DATA_WIDTH-1:0] target_x,
    input wire signed [DATA_WIDTH-1:0] target_y,
    input wire [DATA_WIDTH-1:0] segment_lengths [0:N-1],
    
    output reg signed [DATA_WIDTH-1:0] x_coords [0:N-1],
    output reg signed [DATA_WIDTH-1:0] y_coords [0:N-1],
    output reg done
);

// State definitions
localparam [2:0] IDLE = 3'd0;
localparam [2:0] CALC_SUM = 3'd1;
localparam [2:0] CALC_DIST = 3'd2;
localparam [2:0] CALC_DIR = 3'd3;
localparam [2:0] COMPUTE_POS = 3'd4;
localparam [2:0] FINISHED = 3'd5;

// Registers and wires
reg [2:0] state, next_state;
reg [7:0] idx, next_idx;          // Segment counter
reg signed [DATA_WIDTH-1:0] sum_lengths, next_sum_lengths;
reg signed [DATA_WIDTH-1:0] target_dist, next_target_dist;
reg signed [DATA_WIDTH-1:0] angle_sin, next_angle_sin;
reg signed [DATA_WIDTH-1:0] angle_cos, next_angle_cos;
reg signed [DATA_WIDTH-1:0] acc_x, next_acc_x;  // Accumulated x position
reg signed [DATA_WIDTH-1:0] acc_y, next_acc_y;  // Accumulated y position
reg signed [DATA_WIDTH-1:0] scale_factor, next_scale_factor;
reg [7:0] cycle_count, next_cycle_count;

// Combinational logic for state transition
always @(*) begin
    next_state = state;
    next_idx = idx;
    next_sum_lengths = sum_lengths;
    next_target_dist = target_dist;
    next_angle_sin = angle_sin;
    next_angle_cos = angle_cos;
    next_acc_x = acc_x;
    next_acc_y = acc_y;
    next_scale_factor = scale_factor;
    next_cycle_count = cycle_count;
    done = 1'b0;

    case (state)
        IDLE: begin
            if (start) begin
                next_state = CALC_SUM;
                next_idx = 8'd0;
                next_sum_lengths = 32'd0;
                next_cycle_count = 8'd0;
            end
        end

        CALC_SUM: begin
            if (idx < N) begin
                next_sum_lengths = sum_lengths + segment_lengths[idx];
                next_idx = idx + 8'd1;
            end else begin
                next_state = CALC_DIST;
                next_idx = 8'd0;
            end
        end

        CALC_DIST: begin
            // Calculate target distance = sqrt(x² + y²)
            // Simplified: use Manhattan distance for hardware
            // For Q16.16: dist = (abs(x) + abs(y)) / 2
            if (cycle_count == 8'd0) begin
                if (target_x > 32'd0) begin
                    next_target_dist = target_x;
                end else begin
                    next_target_dist = -target_x;
                end
                if (target_y > 32'd0) begin
                    next_target_dist = next_target_dist + target_y;
                end else begin
                    next_target_dist = next_target_dist - target_y;
                end
                next_target_dist = next_target_dist >>> 1;
                next_cycle_count = cycle_count + 8'd1;
            end else if (cycle_count == 8'd1) begin
                // Check if reachable
                if (target_dist <= sum_lengths) begin
                    next_scale_factor = target_dist; // Will divide by sum later
                    next_state = CALC_DIR;
                end else begin
                    // Unreachable - point straight to target
                    next_angle_cos = target_x;
                    next_angle_sin = target_y;
                    next_state = COMPUTE_POS;
                end
                next_cycle_count = 8'd0;
                next_idx = 8'd0;
            end
        end

        CALC_DIR: begin
            // Calculate direction vector (cos, sin) normalized
            // For Q16.16, we use x/dist and y/dist
            if (cycle_count == 8'd0) begin
                // Scale factor = target_dist / sum_lengths
                // For simplicity, approximate: scale = target_dist / (sum_lengths / 2)
                next_scale_factor = target_dist * 2;
                // Avoid divide by zero and use simple shift approximation
                if (sum_lengths > 32'd0) begin
                    next_scale_factor = next_scale_factor / (sum_lengths >> 8);
                end else begin
                    next_scale_factor = 32'd0;
                end
                next_angle_cos = target_x;
                next_angle_sin = target_y;
                next_cycle_count = cycle_count + 8'd1;
            end else if (cycle_count == 8'd1) begin
                // Normalize direction
                if (target_dist > 32'd0) begin
                    next_angle_cos = (target_x * 2) / (target_dist + 1);
                    next_angle_sin = (target_y * 2) / (target_dist + 1);
                end else begin
                    next_angle_cos = 32'd0;
                    next_angle_sin = 32'd0;
                end
                next_cycle_count = 8'd0;
                next_state = COMPUTE_POS;
            end
        end

        COMPUTE_POS: begin
            if (idx < N) begin
                // Calculate segment length (scaled or original)
                reg signed [DATA_WIDTH-1:0] seg_len;
                if (target_dist <= sum_lengths) begin
                    // Reachable: scale segment length
                    seg_len = (segment_lengths[idx] * scale_factor) >>> FRACT_WIDTH;
                end else begin
                    // Unreachable: full length
                    seg_len = segment_lengths[idx];
                end

                // Calculate delta = length * direction
                next_acc_x = acc_x + ((seg_len * angle_cos) >>> FRACT_WIDTH);
                next_acc_y = acc_y + ((seg_len * angle_sin) >>> FRACT_WIDTH);
                
                // Store coordinates (will be assigned in sequential block)
                x_coords[idx] <= next_acc_x;
                y_coords[idx] <= next_acc_y;
                
                next_idx = idx + 8'd1;
            end else begin
                next_state = FINISHED;
            end
        end

        FINISHED: begin
            done = 1'b1;
            if (!start) begin
                next_state = IDLE;
            end
        end

        default: next_state = IDLE;
    endcase
end

// Sequential logic
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        idx <= 8'd0;
        sum_lengths <= 32'd0;
        target_dist <= 32'd0;
        angle_sin <= 32'd0;
        angle_cos <= 32'd0;
        acc_x <= 32'd0;
        acc_y <= 32'd0;
        scale_factor <= 32'd0;
        cycle_count <= 8'd0;
        done <= 1'b0;
        // Clear output arrays
        for (integer i = 0; i < N; i = i + 1) begin
            x_coords[i] <= 32'd0;
            y_coords[i] <= 32'd0;
        end
    end else begin
        state <= next_state;
        idx <= next_idx;
        sum_lengths <= next_sum_lengths;
        target_dist <= next_target_dist;
        angle_sin <= next_angle_sin;
        angle_cos <= next_angle_cos;
        acc_x <= next_acc_x;
        acc_y <= next_acc_y;
        scale_factor <= next_scale_factor;
        cycle_count <= next_cycle_count;
    end
end

endmodule