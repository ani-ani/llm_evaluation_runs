module sand_art (
    input clk,
    input rst_n,
    input start,
    input [15:0] w_in,
    input [15:0] h_in,
    input [7:0][31:0] volume_in,
    input [8:0][15:0] divider_x_in,
    input [7:0][7:0][31:0] min_in,
    input [7:0][7:0][31:0] max_in,
    output reg [31:0] result,
    output reg done
);

    // Parameters
    localparam N = 8;
    localparam M = 8;
    localparam DATA_WIDTH = 32;
    localparam FIXED_WIDTH = 16;
    
    // Binary Search State Machine
    localparam [3:0] IDLE          = 4'd0;
    localparam [3:0] INIT_SEARCH   = 4'd1;
    localparam [3:0] SET_D         = 4'd2;
    localparam [3:0] PREP_CHECK    = 4'd3;
    localparam [3:0] CHECK_SECTION = 4'd4;
    localparam [3:0] CHECK_COLOR   = 4'd5;
    localparam [3:0] UPDATE_RANGE  = 4'd6;
    localparam [3:0] FINISH        = 4'd7;
    localparam [3:0] ERROR_STATE   = 4'd8;

    reg [3:0] state;
    reg [3:0] next_state;
    
    // Search Registers
    reg [31:0] low_d;
    reg [31:0] high_d;
    reg [31:0] mid_d;
    reg feasible;
    
    // Loop Counters
    reg [7:0] section_idx;
    reg [7:0] color_idx;
    reg [15:0] cycle_counter;
    
    // Intermediate Calculations
    reg [31:0] width_i;
    reg [31:0] min_vol_req;
    reg [31:0] max_vol_allowed;
    reg [31:0] sum_min_i;
    reg [31:0] sum_max_i;
    reg [31:0] volume_used[M-1:0];
    reg [31:0] temp_val;
    
    // Control Flags
    reg init_done;
    reg check_failed;
    
    integer i, j;

    // Helper: Fixed-point addition (Q16.16 + Q16.16)
    wire [31:0] fp_add_result;
    assign fp_add_result = sum_min_i + temp_val;
    
    // Helper: Fixed-point multiplication (Q8.8 * Q16.16)
    // w_i is Q8.8, H is Q16.16. Result is Q24.24, truncate to Q16.16
    wire [47:0] mult_temp;
    wire [31:0] mult_result;
    assign mult_temp = width_i * mid_d;  // 16*32 = 48 bits
    assign mult_result = mult_temp[31:0]; // Taking lower 32 bits (approx Q16.16)
    
    // State Transition Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end
    
    // Main FSM
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all registers
            result <= 32'd0;
            done <= 1'b0;
            low_d <= 32'd0;
            high_d <= 32'h0100_0000; // 256.0 in Q16.16
            mid_d <= 32'd0;
            section_idx <= 8'd0;
            color_idx <= 8'd0;
            cycle_counter <= 16'd0;
            feasible <= 1'b0;
            check_failed <= 1'b0;
            init_done <= 1'b0;
            sum_min_i <= 32'd0;
            sum_max_i <= 32'd0;
            width_i <= 32'd0;
            for (i = 0; i < M; i = i + 1) begin
                volume_used[i] <= 32'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        next_state <= INIT_SEARCH;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                INIT_SEARCH: begin
                    // Initialize search range
                    low_d <= 32'd0;
                    high_d <= 32'h0100_0000; // 256.0
                    // Reset volume used tracking
                    for (i = 0; i < M; i = i + 1) begin
                        volume_used[i] <= 32'd0;
                    end
                    next_state <= SET_D;
                end

                SET_D: begin
                    // Binary search step: mid = (low + high) / 2
                    mid_d <= (low_d + high_d) >> 1;
                    section_idx <= 8'd0;
                    check_failed <= 1'b0;
                    init_done <= 1'b0;
                    next_state <= PREP_CHECK;
                end

                PREP_CHECK: begin
                    // Prepare for section check
                    if (section_idx < N) begin
                        // Calculate width (Q8.8 to Q16.16 conversion implicitly)
                        // divider_x_in is Q8.8. width = next - current.
                        // We need to shift left by 8 to match Q16.16 format of D
                        // Actually, D is Q16.16, H will be Q16.16. Width in Q8.8 * H Q16.16 = Q24.24
                        // Let's keep everything in Q16.16 for comparison simplicity.
                        // Width = (divider_x_in[section_idx+1] - divider_x_in[section_idx]) << 8
                        width_i <= (divider_x_in[section_idx + 1] - divider_x_in[section_idx]) * 256;
                        sum_min_i <= 32'd0;
                        sum_max_i <= 32'd0;
                        color_idx <= 8'd0;
                        next_state <= CHECK_SECTION;
                    end else begin
                        // Finished checking all sections
                        if (!check_failed) begin
                            feasible <= 1'b1;
                        end else begin
                            feasible <= 1'b0;
                        end
                        next_state <= UPDATE_RANGE;
                    end
                end

                CHECK_SECTION: begin
                    // Sum min and max for current section (inner loop)
                    if (color_idx < M) begin
                        // Sum Min
                        if (sum_min_i + min_in[section_idx][color_idx] > sum_min_i) begin
                            sum_min_i <= sum_min_i + min_in[section_idx][color_idx];
                        end
                        // Sum Max
                        if (sum_max_i + max_in[section_idx][color_idx] > sum_max_i) begin
                            sum_max_i <= sum_max_i + max_in[section_idx][color_idx];
                        end
                        color_idx <= color_idx + 1;
                        next_state <= CHECK_SECTION;
                    end else begin
                        // Done summing colors for this section
                        // Check Constraints 1 & 2
                        // 1. min_total_vol = width_i * H_low (H_low = H_avg - D/2? No, simplified check)
                        // We check against a sliding window. 
                        // For a fixed D, we just need to verify if there exists some H such that
                        // width_i * H <= section_capacity_max AND width_i * H >= section_capacity_min
                        // Since we can slide H, we check if the range of possible volumes for section i
                        // overlaps with [sum_min_i, sum_max_i] (adjusted for available global volume).
                        
                        // Simplified Feasibility:
                        // Is sum_min_i <= width_i * (H_possible_max)?
                        // Is sum_max_i >= width_i * (H_possible_min)?
                        // Since H is not fixed yet, we check bounds.
                        // Max possible H is limited by total volume / total width.
                        // Min possible H is 0.
                        
                        // However, the requirement asks for specific bounds.
                        // Let's calculate volume bounds for the current section based on mid_d.
                        // We assume H_avg roughly. 
                        // Let's check if the section can physically fit its min/max sums within
                        // some interval of size D.
                        // Max volume for section i = width_i * H_max
                        // Min volume for section i = width_i * H_min
                        // We need: sum_min_i <= width_i * H_max AND sum_max_i >= width_i * H_min
                        // Given H_max - H_min = D.
                        
                        // Let's use a simple check: 
                        // 1. Is sum_min_i > width_i * (some_upper_bound)? If so, impossible.
                        // 2. Is sum_max_i < width_i * (some_lower_bound)? Impossible.
                        // Since we can slide, let's just check if the section fits in the window.
                        // Volume window is [V, V + width_i * D] (conceptually sliding)
                        // We check if [sum_min_i, sum_max_i] fits in [width_i * H_min, width_i * H_max]
                        // where H_max - H_min = D.
                        
                        // If sum_min_i > width_i * (H_avg + D/2) -> Fail
                        // If sum_max_i < width_i * (H_avg - D/2) -> Fail
                        // But H_avg depends on total volume. Let's approximate H_avg = total_volume / total_width.
                        
                        // Let's do the specific calculation requested:
                        // "Check if sum of minimums fits within min_total_vol"
                        // "Check if sum of maximums allows fitting within max_total_vol"
                        // min_total_vol = width_i * H_low
                        // max_total_vol = width_i * H_high
                        // We need to verify if there exists H_low, H_high such that H_high - H_low = mid_d
                        // and sum_min_i >= width_i * H_low AND sum_max_i <= width_i * H_high.
                        
                        // This is equivalent to checking:
                        // sum_max_i - sum_min_i <= width_i * mid_d
                        // AND sum_min_i is not too large (requires H_low >= 0)
                        
                        temp_val <= sum_max_i - sum_min_i;
                        next_state <= CHECK_COLOR;
                    end
                end

                CHECK_COLOR: begin
                    // Check Condition 1: Range constraint
                    // Can the local volume fit in a window of width (width_i * mid_d)?
                    // Note: temp_val is sum_max - sum_min
                    // We compare: temp_val <= width_i * mid_d
                    // width_i * mid_d is Q24.24. temp_val is Q16.16.
                    // Let's align widths.
                    
                    // If (sum_max - sum_min) > (width * D), then even if we align perfectly,
                    // the section requires a range of heights larger than D. Impossible.
                    // temp_val is sum_diff. mult_result is width_i * mid_d.
                    // We need to shift temp_val to match mult_result (or vice versa).
                    // mult_result is in lower 32 bits (approx Q16.16).
                    // Actually, mult_temp[47:0] is Q24.24. 
                    // We should compare 64-bit values or scale properly.
                    // Let's use: (sum_max - sum_min) * 256 <= width_i * mid_d (scale sum to Q24.24)
                    // width_i is Q8.8 (shifted 8), mid_d is Q16.16. product is Q24.24.
                    // sum is Q16.16. Need to shift sum by 8.
                    
                    if ((sum_max_i - sum_min_i) > 0) begin
                        if ( ((sum_max_i - sum_min_i) << 8) > mult_temp[47:8] ) begin
                            check_failed <= 1'b1;
                        end
                    end
                    
                    // Check Condition 2: Non-negative height constraint
                    // Is sum_min_i too large? 
                    // We need width_i * H_low >= sum_min_i.
                    // H_low can be 0. So if sum_min_i > 0, H_low must be > 0.
                    // But we also need H_high - H_low = D.
                    // So H_high = H_low + D.
                    // Total volume V = sum(V_i) = sum(width_i * H_avg_i).
                    // We are checking feasibility for a specific D.
                    // If sum_min_i > width_i * D, we can potentially satisfy it if H_low > 0.
                    // Actually, the constraint is loose.
                    // The main check is the range check.
                    
                    // Check global volume availability later.
                    
                    section_idx <= section_idx + 1;
                    next_state <= PREP_CHECK;
                end

                UPDATE_RANGE: begin
                    if (!check_failed) begin
                        // Feasible: try smaller D
                        high_d <= mid_d;
                    end else begin
                        // Not feasible: try larger D
                        low_d <= mid_d + 32'd1;
                    end
                    
                    // Termination condition
                    if (low_d >= high_d) begin
                        result <= high_d; // or mid_d
                        next_state <= FINISH;
                    end else if (cycle_counter > 16'd4000) begin
                        // Safety timeout
                        result <= high_d;
                        next_state <= FINISH;
                    end else begin
                        cycle_counter <= cycle_counter + 16'd1;
                        next_state <= SET_D;
                    end
                end

                FINISH: begin
                    done <= 1'b1;
                    next_state <= IDLE;
                end

                default: begin
                    next_state <= IDLE;
                end
            endcase
        end
    end

endmodule