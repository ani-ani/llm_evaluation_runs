module lifeguard_position (
    input clk,
    input rst_n,
    input start,
    input signed [7:0] swimmer_x [0:7],
    input signed [7:0] swimmer_y [0:7],
    input [3:0] num_swimmers,
    output reg signed [15:0] lifeguard1_x,
    output reg signed [15:0] lifeguard1_y,
    output reg signed [15:0] lifeguard2_x,
    output reg signed [15:0] lifeguard2_y,
    output reg done
);

    // State declarations
    localparam [3:0] IDLE        = 4'd0;
    localparam [3:0] INIT_LG1    = 4'd1;
    localparam [3:0] SETUP_LOOP  = 4'd2;
    localparam [3:0] CALC_DIST1  = 4'd3;
    localparam [3:0] CALC_DIST2  = 4'd4;
    localparam [3:0] COMPARE     = 4'd5;
    localparam [3:0] CHECK_COUNT = 4'd6;
    localparam [3:0] UPDATE_LG2  = 4'd7;
    localparam [3:0] FINISH      = 4'd8;

    // Registers
    reg [3:0] state;
    reg [3:0] next_state;
    reg [3:0] idx;
    reg [3:0] count;
    reg [2:0] adjust_step;
    reg [7:0] cycle_count;
    
    // Intermediate registers for calculations
    reg signed [8:0] dist1; // Max 127+127=254 -> fits in 9 bits
    reg signed [8:0] dist2;
    reg signed [15:0] d1_reg [0:7]; // Store for debugging/logic if needed, or recompute
    reg signed [15:0] d2_reg [0:7];
    
    // Control signals
    reg calc_done;
    localparam [7:0] MAX_CYCLES = 8'd200;
    localparam signed [15:0] LARGE_OFFSET = 16'sd1000;
    localparam signed [15:0] ADJUST_AMOUNT = 16'sd100;

    // State transition logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end

    // Next state and output logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            lifeguard1_x <= 16'sd0;
            lifeguard1_y <= 16'sd0;
            lifeguard2_x <= 16'sd0;
            lifeguard2_y <= 16'sd0;
            done <= 1'b0;
            idx <= 4'd0;
            count <= 4'd0;
            adjust_step <= 3'd0;
            cycle_count <= 8'd0;
            dist1 <= 9'sd0;
            dist2 <= 9'sd0;
            calc_done <= 1'b0;
        end else begin
            // Defaults
            done <= 1'b0;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    adjust_step <= 3'd0;
                    if (start) begin
                        next_state <= INIT_LG1;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                INIT_LG1: begin
                    // Fix Lifeguard 1 at (0, 0)
                    lifeguard1_x <= 16'sd0;
                    lifeguard1_y <= 16'sd0;
                    // Initialize LG2 with large offset
                    lifeguard2_x <= LARGE_OFFSET;
                    lifeguard2_y <= LARGE_OFFSET;
                    next_state <= SETUP_LOOP;
                end

                SETUP_LOOP: begin
                    idx <= 4'd0;
                    count <= 4'd0;
                    calc_done <= 1'b0;
                    cycle_count <= cycle_count + 8'd1;
                    next_state <= CALC_DIST1;
                end

                CALC_DIST1: begin
                    // Calculate Manhattan distance to Lifeguard 1 (0,0)
                    // dist1 = |x| + |y|
                    if (swimmer_x[idx] < 0) begin
                        dist1 <= -swimmer_x[idx];
                    end else begin
                        dist1 <= swimmer_x[idx];
                    end
                    // We use a combinational trick for abs, or do it in two cycles
                    // Let's do Y in next cycle or combinational logic if we trust synthesis
                    // To be safe and simple:
                    if (swimmer_y[idx] < 0) begin
                        dist1 <= dist1 - swimmer_y[idx]; // Add -y
                    end else begin
                        dist1 <= dist1 + swimmer_y[idx];
                    end
                    next_state <= CALC_DIST2;
                end

                CALC_DIST2: begin
                    // Calculate Manhattan distance to Lifeguard 2 (X, Y)
                    // dist2 = |x - X| + |y - Y|
                    // We assume lifeguard2 coordinates are computed in UPDATE_LG2
                    // Here we just use the current lifeguard2 values
                    if (swimmer_x[idx] < lifeguard2_x) begin
                        dist2 <= lifeguard2_x - swimmer_x[idx];
                    end else begin
                        dist2 <= swimmer_x[idx] - lifeguard2_x;
                    end
                    
                    if (swimmer_y[idx] < lifeguard2_y) begin
                        dist2 <= dist2 - lifeguard2_y + swimmer_y[idx]; // -|y-Y| logic is tricky in one pipe
                        // Let's do full calculation for Y separately in logic or just rely on synthesis
                        // Simpler: assign dist2_final
                    end
                    // Let's use a cleaner combinational calculation for the condition check
                    // rather than pipelining the abs logic which is error prone in simple FSM
                    next_state <= COMPARE;
                end

                COMPARE: begin
                    // Check if d2 < d1
                    // To avoid complex pipelining of abs, we compute distances again or use registered values
                    // Let's use simple combinational logic evaluation here for the comparison
                    // Re-calculate distances combinatorially for the comparison phase
                    begin
                        reg signed [8:0] d1_comb;
                        reg signed [8:0] d2_comb;
                        reg signed [8:0] dx1, dy1;
                        reg signed [8:0] dx2, dy2;

                        // d1 = |x| + |y|
                        dx1 = (swimmer_x[idx] < 0) ? -swimmer_x[idx] : swimmer_x[idx];
                        dy1 = (swimmer_y[idx] < 0) ? -swimmer_y[idx] : swimmer_y[idx];
                        d1_comb = dx1 + dy1;

                        // d2 = |x - X| + |y - Y|
                        dx2 = (swimmer_x[idx] < lifeguard2_x) ? (lifeguard2_x - swimmer_x[idx]) : (swimmer_x[idx] - lifeguard2_x);
                        dy2 = (swimmer_y[idx] < lifeguard2_y) ? (lifeguard2_y - swimmer_y[idx]) : (swimmer_y[idx] - lifeguard2_y);
                        d2_comb = dx2 + dy2;

                        if (d2_comb < d1_comb) begin
                            count <= count + 4'd1;
                        end
                    end
                    
                    if (idx == num_swimmers - 4'd1) begin
                        next_state <= CHECK_COUNT;
                    end else begin
                        idx <= idx + 4'd1;
                        next_state <= CALC_DIST1; // Loop back to calculate next distance
                    end
                end

                CHECK_COUNT: begin
                    // Check if count == num_swimmers / 2
                    // Logic: num_swimmers >> 1
                    if (count == (num_swimmers >> 1)) begin
                        next_state <= FINISH;
                    end else begin
                        next_state <= UPDATE_LG2;
                    end
                end

                UPDATE_LG2: begin
                    // Adjust LG2 position to find a valid split
                    // We try a few offsets. If we fail, we try a different strategy.
                    // Strategy: Place LG2 at sum of coordinates or a large fixed value.
                    // Current strategy: Try offsets in X, then Y, then X+Y.
                    
                    if (adjust_step == 3'd0) begin
                        lifeguard2_x <= lifeguard2_x - ADJUST_AMOUNT;
                        adjust_step <= 3'd1;
                    end else if (adjust_step == 3'd1) begin
                        lifeguard2_x <= lifeguard2_x + (ADJUST_AMOUNT * 2);
                        adjust_step <= 3'd2;
                    end else if (adjust_step == 3'd2) begin
                        lifeguard2_y <= lifeguard2_y - ADJUST_AMOUNT;
                        adjust_step <= 3'd3;
                    end else if (adjust_step == 3'd3) begin
                        lifeguard2_y <= lifeguard2_y + (ADJUST_AMOUNT * 2);
                        adjust_step <= 3'd4;
                    end else if (adjust_step == 3'd4) begin
                        // Backup: Calculate average position of swimmers
                        // This requires summation, handled by a counter or pre-calculated.
                        // For this simplified implementation, we will reset to (0,0)
                        lifeguard2_x <= 16'sd0;
                        lifeguard2_y <= 16'sd0;
                        adjust_step <= 3'd5;
                    end else begin
                        // Try diagonal
                        lifeguard2_x <= 16'sd50;
                        lifeguard2_y <= 16'sd50;
                        adjust_step <= 3'd6;
                    end

                    if (cycle_count >= MAX_CYCLES) begin
                        // Timeout fallback
                        lifeguard2_x <= 16'sd100;
                        lifeguard2_y <= 16'sd100;
                        next_state <= FINISH;
                    end else begin
                        next_state <= SETUP_LOOP; // Retry calculation with new position
                    end
                end

                FINISH: begin
                    done <= 1'b1;
                    next_state <= IDLE;
                end

                default: next_state <= IDLE;
            endcase
        end
    end

endmodule