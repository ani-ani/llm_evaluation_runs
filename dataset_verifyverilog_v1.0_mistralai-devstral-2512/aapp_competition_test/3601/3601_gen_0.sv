module delivery_optimizer(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] misha_len,
    input wire [3:0] nadia_len,
    input wire signed [31:0] misha_pts_x [0:15],
    input wire signed [31:0] misha_pts_y [0:15],
    input wire signed [31:0] nadia_pts_x [0:15],
    input wire signed [31:0] nadia_pts_y [0:15],
    output reg signed [31:0] min_time,
    output reg done,
    output reg valid
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] LOAD_INPUTS = 2'd1;
    localparam [1:0] CALCULATE = 2'd2;
    localparam [1:0] OUTPUT = 2'd3;
    
    reg [1:0] state, next_state;
    
    // Internal registers
    reg [3:0] misha_idx;
    reg [3:0] nadia_idx;
    reg [3:0] misha_seg;
    reg [3:0] nadia_seg;
    reg [3:0] cycle_count;
    
    // Fixed-point arithmetic components
    reg signed [31:0] misha_x0, misha_y0, misha_x1, misha_y1;
    reg signed [31:0] nadia_x0, nadia_y0, nadia_x1, nadia_y1;
    reg signed [31:0] misha_dx, misha_dy, nadia_dx, nadia_dy;
    reg signed [31:0] misha_len_sq, nadia_len_sq;
    reg signed [31:0] current_time;
    reg signed [31:0] temp_min_time;
    reg found_valid;
    
    // Arithmetic helpers
    reg signed [63:0] mult_temp;
    reg signed [31:0] sqrt_input;
    reg signed [31:0] sqrt_result;
    reg [7:0] sqrt_iter;
    
    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            misha_idx <= 4'd0;
            nadia_idx <= 4'd0;
            misha_seg <= 4'd0;
            nadia_seg <= 4'd0;
            cycle_count <= 4'd0;
            misha_x0 <= 32'd0;
            misha_y0 <= 32'd0;
            misha_x1 <= 32'd0;
            misha_y1 <= 32'd0;
            nadia_x0 <= 32'd0;
            nadia_y0 <= 32'd0;
            nadia_x1 <= 32'd0;
            nadia_y1 <= 32'd0;
            misha_dx <= 32'd0;
            misha_dy <= 32'd0;
            nadia_dx <= 32'd0;
            nadia_dy <= 32'd0;
            misha_len_sq <= 32'd0;
            nadia_len_sq <= 32'd0;
            current_time <= 32'd0;
            temp_min_time <= 32'd0;
            found_valid <= 1'b0;
            sqrt_input <= 32'd0;
            sqrt_result <= 32'd0;
            sqrt_iter <= 8'd0;
            min_time <= 32'd0;
            done <= 1'b0;
            valid <= 1'b0;
        end else begin
            state <= next_state;
        end
    end
    
    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = LOAD_INPUTS;
                end
            end
            
            LOAD_INPUTS: begin
                next_state = CALCULATE;
            end
            
            CALCULATE: begin
                if (cycle_count >= 4'd255) begin
                    next_state = OUTPUT;
                end
            end
            
            OUTPUT: begin
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end
    
    // Main calculation logic
    always @(posedge clk) begin
        if (state == LOAD_INPUTS) begin
            // Initialize calculation
            misha_seg <= 4'd0;
            nadia_seg <= 4'd0;
            cycle_count <= 4'd0;
            temp_min_time <= 32'd0;
            found_valid <= 1'b0;
        end else if (state == CALCULATE) begin
            // Load segment data
            if (cycle_count == 4'd0) begin
                misha_x0 <= misha_pts_x[misha_seg];
                misha_y0 <= misha_pts_y[misha_seg];
                misha_x1 <= misha_pts_x[misha_seg + 4'd1];
                misha_y1 <= misha_pts_y[misha_seg + 4'd1];
                nadia_x0 <= nadia_pts_x[nadia_seg];
                nadia_y0 <= nadia_pts_y[nadia_seg];
                nadia_x1 <= nadia_pts_x[nadia_seg + 4'd1];
                nadia_y1 <= nadia_pts_y[nadia_seg + 4'd1];
                
                // Calculate segment vectors
                misha_dx <= misha_x1 - misha_x0;
                misha_dy <= misha_y1 - misha_y0;
                nadia_dx <= nadia_x1 - nadia_x0;
                nadia_dy <= nadia_y1 - nadia_y0;
                
                // Calculate squared lengths
                mult_temp = misha_dx * misha_dx;
                misha_len_sq <= mult_temp[63:32];
                mult_temp = misha_dy * misha_dy;
                misha_len_sq <= misha_len_sq + mult_temp[63:32];
                
                mult_temp = nadia_dx * nadia_dx;
                nadia_len_sq <= mult_temp[63:32];
                mult_temp = nadia_dy * nadia_dy;
                nadia_len_sq <= nadia_len_sq + mult_temp[63:32];
                
                // Check endpoints
                current_time <= check_endpoints();
                
                // Check intersection
                if (current_time < temp_min_time || !found_valid) begin
                    temp_min_time <= current_time;
                    found_valid <= 1'b1;
                end
            end
            
            // Increment counters
            cycle_count <= cycle_count + 4'd1;
            
            // Move to next segment pair
            if (cycle_count == 4'd10) begin
                nadia_seg <= nadia_seg + 4'd1;
                if (nadia_seg >= nadia_len - 4'd1) begin
                    nadia_seg <= 4'd0;
                    misha_seg <= misha_seg + 4'd1;
                    if (misha_seg >= misha_len - 4'd1) begin
                        cycle_count <= 4'd255;
                    end
                end
            end
        end else if (state == OUTPUT) begin
            min_time <= temp_min_time;
            valid <= found_valid;
            done <= 1'b1;
        end else begin
            done <= 1'b0;
        end
    end
    
    // Function to check segment endpoints
    function signed [31:0] check_endpoints;
        reg signed [31:0] min_t;
        reg signed [31:0] t_m, t_n;
        reg signed [31:0] dist_sq;
        
        min_t = 32'd0;
        
        // Check all combinations of endpoints
        // Misha at start, Nadia at start
        dist_sq = (misha_x0 - nadia_x0) * (misha_x0 - nadia_x0) + 
                  (misha_y0 - nadia_y0) * (misha_y0 - nadia_y0);
        t_m = 32'd0;
        t_n = 32'd0;
        if (t_n >= t_m) begin
            if (dist_sq < min_t || min_t == 32'd0) begin
                min_t = dist_sq;
            end
        end
        
        // Misha at start, Nadia at end
        dist_sq = (misha_x0 - nadia_x1) * (misha_x0 - nadia_x1) + 
                  (misha_y0 - nadia_y1) * (misha_y0 - nadia_y1);
        t_m = 32'd0;
        t_n = nadia_len_sq;
        if (t_n >= t_m) begin
            if (dist_sq < min_t || min_t == 32'd0) begin
                min_t = dist_sq;
            end
        end
        
        // Misha at end, Nadia at start
        dist_sq = (misha_x1 - nadia_x0) * (misha_x1 - nadia_x0) + 
                  (misha_y1 - nadia_y0) * (misha_y1 - nadia_y0);
        t_m = misha_len_sq;
        t_n = 32'd0;
        if (t_n >= t_m) begin
            if (dist_sq < min_t || min_t == 32'd0) begin
                min_t = dist_sq;
            end
        end
        
        // Misha at end, Nadia at end
        dist_sq = (misha_x1 - nadia_x1) * (misha_x1 - nadia_x1) + 
                  (misha_y1 - nadia_y1) * (misha_y1 - nadia_y1);
        t_m = misha_len_sq;
        t_n = nadia_len_sq;
        if (t_n >= t_m) begin
            if (dist_sq < min_t || min_t == 32'd0) begin
                min_t = dist_sq;
            end
        end
        
        check_endpoints = min_t;
    endfunction
    
    // Fixed-point square root (simplified for synthesis)
    always @(posedge clk) begin
        if (sqrt_input != 32'd0 && state == CALCULATE) begin
            sqrt_result <= 32'd0;
            sqrt_iter <= 8'd0;
        end else if (sqrt_iter < 8'd16 && state == CALCULATE) begin
            // Simple iterative approximation
            sqrt_result <= sqrt_result + (sqrt_input - sqrt_result * sqrt_result) / (2 * sqrt_result);
            sqrt_iter <= sqrt_iter + 8'd1;
        end
    end

endmodule