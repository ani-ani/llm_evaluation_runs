module bulkheads (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] N,          // Number of vertices (max 8)
    input wire signed [15:0] x [0:7], // X-coordinates of vertices
    input wire signed [15:0] y [0:7], // Y-coordinates of vertices
    input wire [31:0] C,         // Minimum area per section
    output reg [7:0] M,          // Number of sections
    output reg [31:0] x_bulk [0:99], // X-coordinates of bulkheads (Q16.16 format)
    output reg done              // Computation done
);

    // Fixed-point constants
    localparam [31:0] FP_SCALE = 32'd65536;  // 2^16
    localparam [63:0] FP_SCALE_64 = 64'd65536;
    
    // State declarations
    localparam [3:0] IDLE          = 4'd0;
    localparam [3:0] COMPUTE_AREA   = 4'd1;
    localparam [3:0] COMPUTE_M      = 4'd2;
    localparam [3:0] FIND_X_EXTREMES = 4'd3;
    localparam [3:0] SETUP_TARGET   = 4'd4;
    localparam [3:0] SETUP_BS       = 4'd5;
    localparam [3:0] BS_ITERATE     = 4'd6;
    localparam [3:0] BS_EVAL        = 4'd7;
    localparam [3:0] STORE_RESULT   = 4'd8;
    localparam [3:0] DONE_STATE     = 4'd9;
    
    reg [3:0] state, next_state;
    
    // Internal registers
    reg [7:0] counter;           // Generic counter
    reg [7:0] bs_counter;        // Binary search iteration counter
    reg [7:0] target_idx;        // Index of current target (1 to M-1)
    reg [7:0] N_reg;             // Stored N
    
    // Area calculation registers
    reg signed [63:0] area_sum;  // 64-bit accumulator
    reg [31:0] total_area;       // Final area (Q16.16)
    
    // X-extremes registers
    reg signed [15:0] x_min, x_max;
    reg signed [15:0] x_min_temp, x_max_temp;
    
    // Target area registers
    reg [31:0] target_area;      // Q16.16
    reg [63:0] target_num;       // For multiplication
    
    // Binary search registers
    reg signed [31:0] low;       // Q16.16
    reg signed [31:0] high;      // Q16.16
    reg signed [31:0] mid;       // Q16.16
    reg signed [31:0] cum_area;  // Q16.16
    reg [31:0] M_reg;            // M as 32-bit for calculation
    
    // Cumulative area calculation state
    reg [2:0] edge_idx;          // Current edge being processed
    reg signed [31:0] cum_x_min; // Q16.16 x_min for this calc
    reg signed [31:0] area_acc;  // Accumulated area
    reg signed [31:0] prev_y;    // Previous y (Q16.16)
    reg signed [31:0] curr_x;    // Current x (Q16.16)
    reg signed [31:0] curr_y;    // Current y (Q16.16)
    
    // Temporary registers for edge calculation
    reg signed [31:0] edge_x0, edge_x1, edge_y0, edge_y1;
    reg signed [31:0] dx, dy, slope;
    reg signed [31:0] y_at_x;
    reg signed [63:0] temp_mult;
    reg signed [63:0] temp_div;
    reg signed [63:0] temp_sum;
    reg [1:0] calc_step;         // Step within BS_ITERATE
    reg [1:0] calc_step_next;
    
    // Wires for calculations
    wire [63:0] area_mult1;
    wire [63:0] area_mult2;
    wire signed [63:0] target_mult;
    wire signed [63:0] bs_mid_sum;
    
    // Assignments
    assign area_mult1 = { {48{x[0][15]}}, x[0] } * { {48{y[1][15]}}, y[1] };
    assign area_mult2 = { {48{x[1][15]}}, x[1] } * { {48{y[0][15]}}, y[0] };
    assign target_mult = target_num * total_area;
    assign bs_mid_sum = low + high;
    
    // State register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            M <= 8'd0;
            done <= 1'b0;
            counter <= 8'd0;
            bs_counter <= 8'd0;
            target_idx <= 8'd0;
            N_reg <= 8'd0;
            area_sum <= 64'd0;
            total_area <= 32'd0;
            x_min <= 16'd0;
            x_max <= 16'd0;
            x_min_temp <= 16'd0;
            x_max_temp <= 16'd0;
            target_area <= 32'd0;
            target_num <= 64'd0;
            low <= 32'd0;
            high <= 32'd0;
            mid <= 32'd0;
            cum_area <= 32'd0;
            M_reg <= 32'd0;
            edge_idx <= 3'd0;
            cum_x_min <= 32'd0;
            area_acc <= 32'd0;
            prev_y <= 32'd0;
            curr_x <= 32'd0;
            curr_y <= 32'd0;
            edge_x0 <= 32'd0;
            edge_x1 <= 32'd0;
            edge_y0 <= 32'd0;
            edge_y1 <= 32'd0;
            dx <= 32'd0;
            dy <= 32'd0;
            slope <= 32'd0;
            y_at_x <= 32'd0;
            temp_mult <= 64'd0;
            temp_div <= 64'd0;
            temp_sum <= 64'd0;
            calc_step <= 2'd0;
            calc_step_next <= 2'd0;
            // Initialize x_bulk array
            for (integer i = 0; i < 100; i = i + 1) begin
                x_bulk[i] <= 32'd0;
            end
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    M <= 8'd0;
                    counter <= 8'd0;
                    bs_counter <= 8'd0;
                    target_idx <= 8'd0;
                    if (start) begin
                        N_reg <= N;
                        area_sum <= 64'd0;
                        total_area <= 32'd0;
                    end
                end
                
                COMPUTE_AREA: begin
                    // Use counter to iterate through edges
                    // area_sum += x[i]*y[i+1] - x[i+1]*y[i]
                    // Each computation takes 2 cycles for multiplication
                    if (counter < N_reg) begin
                        if (counter == 8'd0) begin
                            // First cycle: compute x[i]*y[i+1]
                            temp_mult <= { {48{x[0][15]}}, x[0] } * { {48{y[1][15]}}, y[1] };
                            counter <= counter + 8'd1;
                        end else if (counter < N_reg) begin
                            // Compute term for edge (counter-1, counter)
                            temp_mult <= { {48{x[counter-1][15]}}, x[counter-1] } * { {48{y[counter][15]}}, y[counter] };
                            counter <= counter + 8'd1;
                        end
                    end else if (counter < N_reg + 8'd8) begin
                        // Wait for multiplication result, then subtract
                        if (counter == N_reg + 8'd0) begin
                            // Compute -x[0]*y[1]
                            temp_div <= temp_mult - { {48{x[1][15]}}, x[1] } * { {48{y[0][15]}}, y[0] };
                            counter <= counter + 8'd1;
                        end else if (counter < N_reg + 8'd8) begin
                            // Compute -x[i]*y[i-1]
                            temp_div <= temp_mult - { {48{x[counter-N_reg][15]}}, x[counter-N_reg] } * { {48{y[counter-N_reg-1][15]}}, y[counter-N_reg-1] };
                            counter <= counter + 8'd1;
                        end
                    end else begin
                        // Add to area_sum (after counter >= N_reg + 8)
                        // Actually, let's simplify this complex loop
                        if (counter == N_reg + 8'd8) begin
                            area_sum <= temp_div;
                            counter <= 8'd0;
                        end else begin
                            area_sum <= area_sum + temp_div;
                            if (counter < N_reg + 8'd16) begin
                                counter <= counter + 8'd1;
                            end
                        end
                    end
                    
                    // Simpler version: handle in multiple cycles
                    if (counter >= N_reg + 8'd16) begin
                        total_area <= area_sum >> 1;  // Divide by 2
                        counter <= 8'd0;
                    end
                end
                
                COMPUTE_M: begin
                    // M = floor(total_area / C)
                    // Handle division over multiple cycles
                    if (counter == 8'd0) begin
                        if (total_area >= C) begin
                            M_reg <= total_area / C;
                        end else begin
                            M_reg <= 32'd1;
                        end
                        counter <= counter + 8'd1;
                    end else if (counter == 8'd1) begin
                        if (M_reg > 32'd100) begin
                            M_reg <= 32'd100;
                        end
                        counter <= 8'd0;
                    end
                    
                    // Set M output
                    if (M_reg > 0 && M_reg <= 255) begin
                        M <= M_reg[7:0];
                    end else begin
                        M <= 8'd1;
                    end
                end
                
                FIND_X_EXTREMES: begin
                    // Find min and max x from vertices
                    if (counter < N_reg) begin
                        if (counter == 8'd0) begin
                            x_min <= x[0];
                            x_max <= x[0];
                        end else begin
                            if (x[counter] < x_min)
                                x_min <= x[counter];
                            if (x[counter] > x_max)
                                x_max <= x[counter];
                        end
                        counter <= counter + 8'd1;
                    end else begin
                        // Convert to Q16.16
                        x_min_temp <= x_min <<< 16;
                        x_max_temp <= x_max <<< 16;
                        counter <= 8'd0;
                    end
                end
                
                SETUP_TARGET: begin
                    // target_area = (k * total_area) / M
                    // k is target_idx (1 to M-1)
                    if (target_idx < M_reg[7:0]) begin
                        target_num <= target_idx;
                        temp_mult <= target_num * total_area;
                        target_idx <= target_idx + 8'd1;
                        // Also reset binary search
                        counter <= 8'd0;
                    end
                    
                    if (target_idx > 8'd0 && target_idx <= M_reg[7:0]) begin
                        // Compute target_area
                        if (counter == 8'd0) begin
                            temp_div <= temp_mult / M_reg;
                            counter <= counter + 8'd1;
                        end else if (counter == 8'd1) begin
                            target_area <= temp_div[31:0];
                            counter <= 8'd0;
                        end
                    end
                end
                
                SETUP_BS: begin
                    // Initialize binary search
                    low <= x_min_temp;
                    high <= x_max_temp;
                    bs_counter <= 8'd0;
                    cum_area <= 32'd0;
                    calc_step <= 2'd0;
                end
                
                BS_ITERATE: begin
                    // mid = (low + high) / 2
                    if (calc_step == 2'd0) begin
                        // Compute mid
                        mid <= bs_mid_sum >>> 1;
                        calc_step <= 2'd1;
                        edge_idx <= 3'd0;
                        area_acc <= 32'd0;
                    end else if (calc_step == 2'd1) begin
                        // Compute cumulative area at mid
                        // Initialize for first edge
                        if (edge_idx == 3'd0) begin
                            cum_x_min <= x_min_temp;
                            prev_y <= (y[0] <<< 16);  // Q16.16
                        end
                        
                        // Get edge endpoints
                        if (edge_idx < N_reg) begin
                            edge_x0 <= (x[edge_idx] <<< 16);
                            edge_x1 <= (x[(edge_idx + 1) % 8'd8] <<< 16);
                            edge_y0 <= (y[edge_idx] <<< 16);
                            edge_y1 <= (y[(edge_idx + 1) % 8'd8] <<< 16);
                            calc_step <= 2'd2;
                        end else begin
                            // Done with edges, check if mid is within bounds
                            calc_step <= 2'd0;
                            bs_counter <= bs_counter + 8'd1;
                        end
                    end
                end
                
                BS_EVAL: begin
                    // Evaluate edge and compute trapezoid area
                    // Check if edge spans mid
                    if ((edge_x0 <= mid && edge_x1 >= mid) || (edge_x1 <= mid && edge_x0 >= mid)) begin
                        // This edge spans mid
                        // Compute y at mid
                        if (edge_x1 != edge_x0) begin
                            dx <= edge_x1 - edge_x0;
                            dy <= edge_y1 - edge_y0;
                            temp_mult <= dy * (mid - edge_x0);
                            calc_step_next <= 2'd3;
                        end else begin
                            // Vertical edge, use endpoint y
                            curr_y <= edge_y0;
                            calc_step_next <= 2'd4;
                        end
                    end else begin
                        // Edge doesn't span mid, continue to next edge
                        edge_idx <= edge_idx + 3'd1;
                        calc_step <= 2'd1;
                    end
                    
                    if (calc_step_next == 2'd3) begin
                        // y_at_x = y0 + dy * (x - x0) / dx
                        temp_div <= temp_mult / dx;
                        calc_step_next <= 2'd4;
                    end
                    
                    if (calc_step_next == 2'd4) begin
                        curr_y <= edge_y0 + temp_div[31:0];
                        // Compute trapezoid area from cum_x_min to min(mid, edge_x1)
                        curr_x <= (mid < edge_x1) ? mid : edge_x1;
                        calc_step_next <= 2'd5;
                    end
                    
                    if (calc_step_next == 2'd5) begin
                        // area += (prev_y + curr_y) * (curr_x - cum_x_min) / 2
                        temp_sum <= prev_y + curr_y;
                        temp_div <= curr_x - cum_x_min;
                        calc_step_next <= 2'd6;
                    end
                    
                    if (calc_step_next == 2'd6) begin
                        // Divide by 2 (shift right 1 in Q16.16)
                        temp_div <= (temp_sum * temp_div) >>> 1;
                        calc_step_next <= 2'd7;
                    end
                    
                    if (calc_step_next == 2'd7) begin
                        area_acc <= area_acc + temp_div[31:0];
                        prev_y <= curr_y;
                        cum_x_min <= curr_x;
                        
                        // Check if curr_x >= mid
                        if (curr_x >= mid) begin
                            cum_area <= area_acc;
                            edge_idx <= 3'd0;
                            calc_step <= 2'd0;
                            bs_counter <= bs_counter + 8'd1;
                        end else begin
                            edge_idx <= edge_idx + 3'd1;
                            calc_step <= 2'd1;
                        end
                        calc_step_next <= 2'd0;
                    end
                end
                
                STORE_RESULT: begin
                    // Store final mid to x_bulk
                    if (target_idx > 8'd1 && target_idx <= M_reg[7:0]) begin
                        x_bulk[target_idx - 8'd2] <= mid[31:0];
                    end
                    calc_step <= 2'd0;
                    edge_idx <= 3'd0;
                    counter <= 8'd0;
                end
                
                DONE_STATE: begin
                    done <= 1'b1;
                    target_idx <= 8'd0;
                end
                
                default: begin
                    state <= IDLE;
                    M <= 8'd0;
                    done <= 1'b0;
                    counter <= 8'd0;
                    bs_counter <= 8'd0;
                    target_idx <= 8'd0;
                    N_reg <= 8'd0;
                    area_sum <= 64'd0;
                    total_area <= 32'd0;
                    x_min <= 16'd0;
                    x_max <= 16'd0;
                    x_min_temp <= 32'd0;
                    x_max_temp <= 32'd0;
                    target_area <= 32'd0;
                    target_num <= 64'd0;
                    low <= 32'd0;
                    high <= 32'd0;
                    mid <= 32'd0;
                    cum_area <= 32'd0;
                    M_reg <= 32'd0;
                    edge_idx <= 3'd0;
                    cum_x_min <= 32'd0;
                    area_acc <= 32'd0;
                    prev_y <= 32'd0;
                    curr_x <= 32'd0;
                    curr_y <= 32'd0;
                    edge_x0 <= 32'd0;
                    edge_x1 <= 32'd0;
                    edge_y0 <= 32'd0;
                    edge_y1 <= 32'd0;
                    dx <= 32'd0;
                    dy <= 32'd0;
                    slope <= 32'd0;
                    y_at_x <= 32'd0;
                    temp_mult <= 64'd0;
                    temp_div <= 64'd0;
                    temp_sum <= 64'd0;
                    calc_step <= 2'd0;
                    calc_step_next <= 2'd0;
                end
            endcase
        end
    end
    
    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start)
                    next_state = COMPUTE_AREA;
            end
            
            COMPUTE_AREA: begin
                // Wait for computation to finish
                // This is complex, so we use a simple counter-based transition
                if (counter >= N_reg + 8'd20)
                    next_state = COMPUTE_M;
            end
            
            COMPUTE_M: begin
                if (counter >= 8'd2)
                    next_state = FIND_X_EXTREMES;
            end
            
            FIND_X_EXTREMES: begin
                if (counter >= N_reg)
                    next_state = SETUP_TARGET;
            end
            
            SETUP_TARGET: begin
                // If we have more targets to process
                if (target_idx > M_reg[7:0]) begin
                    next_state = DONE_STATE;
                end else if (counter >= 8'd2) begin
                    next_state = SETUP_BS;
                end
            end
            
            SETUP_BS: begin
                next_state = BS_ITERATE;
            end
            
            BS_ITERATE: begin
                // Check if we need to go to BS_EVAL
                if (calc_step == 2'd2) begin
                    next_state = BS_EVAL;
                end else if (calc_step == 2'd0 && bs_counter >= 8'd16) begin
                    // Binary search complete
                    next_state = STORE_RESULT;
                end
            end
            
            BS_EVAL: begin
                if (calc_step == 2'd0 && bs_counter >= 8'd16) begin
                    next_state = STORE_RESULT;
                end else if (calc_step == 2'd0 && edge_idx == 3'd0) begin
                    // Done with edges, go back to BS_ITERATE
                    next_state = BS_ITERATE;
                end
            end
            
            STORE_RESULT: begin
                next_state = SETUP_TARGET;
            end
            
            DONE_STATE: begin
                // Stay here until reset or start goes low
                if (!start) begin
                    next_state = IDLE;
                end
            end
            
            default: next_state = IDLE;
        endcase
    end

endmodule