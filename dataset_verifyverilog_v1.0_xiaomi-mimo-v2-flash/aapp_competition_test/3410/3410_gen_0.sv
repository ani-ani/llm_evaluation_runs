module convex_quadrilateral_sum(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [15:0] x [0:11],
    input wire [15:0] y [0:11],
    input wire [3:0] n,
    output reg [19:0] result,
    output reg done
);
    // Constants
    localparam [31:0] MODULUS = 32'd1000003;
    localparam [3:0] MAX_POINTS = 4'd12;
    localparam [7:0] MAX_COMBINATIONS = 8'd220; // C(12,4) = 495, but we handle iteratively
    localparam [7:0] MAX_ITERATIONS = 8'd200;
    
    // State declarations
    localparam [2:0] IDLE     = 3'd0;
    localparam [2:0] SETUP    = 3'd1;
    localparam [2:0] COMPUTE  = 3'd2;
    localparam [2:0] ACCUM    = 3'd3;
    localparam [2:0] MODULO   = 3'd4;
    localparam [2:0] FINISH   = 3'd5;
    
    reg [2:0] state;
    reg [2:0] next_state;
    
    // Index registers for combination generation
    reg [3:0] i, j, k, l;
    reg [7:0] cycle_count;
    reg [31:0] area_sum;
    reg [31:0] area_sum_next;
    
    // Temporary area calculation registers
    reg [31:0] temp_sum;
    reg [31:0] temp_sum_next;
    reg [2:0] point_idx;
    reg [31:0] acc_x, acc_y;
    reg [31:0] acc_x_next, acc_y_next;
    
    // Modulo variables
    reg [31:0] mod_temp;
    reg [31:0] mod_temp_next;
    
    // Computation registers for 4-point area
    reg signed [31:0] area_term1;
    reg signed [31:0] area_term2;
    reg signed [31:0] area_term3;
    reg signed [31:0] area_term4;
    reg signed [31:0] area_total;
    reg signed [31:0] abs_area;
    
    // Control signals
    reg area_calc_done;
    reg mod_done;
    
    // State register and next state logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 20'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            area_sum <= 32'd0;
            i <= 4'd0;
            j <= 4'd0;
            k <= 4'd0;
            l <= 4'd0;
            point_idx <= 3'd0;
            acc_x <= 32'd0;
            acc_y <= 32'd0;
            temp_sum <= 32'd0;
            mod_temp <= 32'd0;
            area_term1 <= 32'd0;
            area_term2 <= 32'd0;
            area_term3 <= 32'd0;
            area_term4 <= 32'd0;
            area_total <= 32'd0;
            abs_area <= 32'd0;
            mod_done <= 1'b0;
            area_calc_done <= 1'b0;
        end else begin
            state <= next_state;
            cycle_count <= cycle_count + 8'd1;
            area_sum <= area_sum_next;
            acc_x <= acc_x_next;
            acc_y <= acc_y_next;
            temp_sum <= temp_sum_next;
            mod_temp <= mod_temp_next;
            
            // Increment indices based on state
            if (state == COMPUTE && !area_calc_done) begin
                // Point indexing for area calculation
                point_idx <= point_idx + 3'd1;
                if (point_idx == 3'd3) begin
                    point_idx <= 3'd0;
                    area_calc_done <= 1'b1;
                end
            end
            
            if (state == COMPUTE && area_calc_done) begin
                // Move to next quadrilateral combination
                l <= l + 4'd1;
                if (l >= n - 4'd1) begin
                    l <= 4'd0;
                    k <= k + 4'd1;
                    if (k >= n - 4'd2) begin
                        k <= 4'd0;
                        j <= j + 4'd1;
                        if (j >= n - 4'd3) begin
                            j <= 4'd0;
                            i <= i + 4'd1;
                            if (i >= n - 4'd4) begin
                                i <= 4'd0;
                            end
                        end
                    end
                end
                area_calc_done <= 1'b0;
            end
            
            if (state == MODULO && !mod_done) begin
                // Subtraction-based modulo
                if (mod_temp >= MODULUS) begin
                    mod_temp <= mod_temp - MODULUS;
                end else begin
                    mod_done <= 1'b1;
                end
            end
            
            if (state == FINISH) begin
                result <= mod_temp[19:0];
                done <= 1'b1;
            end else if (state == IDLE) begin
                done <= 1'b0;
                mod_done <= 1'b0;
                cycle_count <= 8'd0;
                area_sum <= 32'd0;
                i <= 4'd0;
                j <= 4'd0;
                k <= 4'd0;
                l <= 4'd0;
                point_idx <= 3'd0;
                acc_x <= 32'd0;
                acc_y <= 32'd0;
                temp_sum <= 32'd0;
                mod_temp <= 32'd0;
                area_calc_done <= 1'b0;
            end
        end
    end
    
    // Next state and output logic
    always @(*) begin
        next_state = state;
        area_sum_next = area_sum;
        acc_x_next = acc_x;
        acc_y_next = acc_y;
        temp_sum_next = temp_sum;
        mod_temp_next = mod_temp;
        
        case (state)
            IDLE: begin
                if (start && n >= 4'd4 && n <= MAX_POINTS) begin
                    next_state = SETUP;
                end
            end
            
            SETUP: begin
                // Initialize for combination generation
                i = 4'd0;
                j = 4'd1;
                k = 4'd2;
                l = 4'd3;
                point_idx = 3'd0;
                acc_x_next = 32'd0;
                acc_y_next = 32'd0;
                temp_sum_next = 32'd0;
                next_state = COMPUTE;
            end
            
            COMPUTE: begin
                // Calculate twice area for current 4 points (i,j,k,l)
                // Use shoelace formula for polygon area (oriented)
                // 2*Area = sum over edges (x_curr*y_next - x_next*y_curr)
                
                if (!area_calc_done) begin
                    // Build polygon with points in order i,j,k,l,i
                    case (point_idx)
                        3'd0: begin // edge i -> j
                            acc_x_next = acc_x + (({16'd0, x[i]} * {16'd0, y[j]}) - ({16'd0, x[j]} * {16'd0, y[i]}));
                        end
                        3'd1: begin // edge j -> k
                            acc_x_next = acc_x + (({16'd0, x[j]} * {16'd0, y[k]}) - ({16'd0, x[k]} * {16'd0, y[j]}));
                        end
                        3'd2: begin // edge k -> l
                            acc_x_next = acc_x + (({16'd0, x[k]} * {16'd0, y[l]}) - ({16'd0, x[l]} * {16'd0, y[k]}));
                        end
                        3'd3: begin // edge l -> i
                            acc_x_next = acc_x + (({16'd0, x[l]} * {16'd0, y[i]}) - ({16'd0, x[i]} * {16'd0, y[l]}));
                            // Final area calculation
                            area_total = acc_x_next;
                            // Absolute value (since area should be positive)
                            if (area_total[31]) begin
                                abs_area = ~area_total + 32'd1; // Two's complement
                            end else begin
                                abs_area = area_total;
                            end
                            // Accumulate to sum
                            temp_sum_next = temp_sum + abs_area;
                        end
                    endcase
                end else begin
                    // Move to accumulation state
                    next_state = ACCUM;
                end
            end
            
            ACCUM: begin
                // Add current quadrilateral area to total sum
                area_sum_next = area_sum + temp_sum;
                temp_sum_next = 32'd0;
                acc_x_next = 32'd0;
                acc_y_next = 32'd0;
                
                // Check if all combinations processed
                if (i >= n - 4'd4 && j >= n - 4'd3 && k >= n - 4'd2 && l >= n - 4'd1) begin
                    next_state = MODULO;
                    mod_temp_next = area_sum_next;
                end else begin
                    next_state = COMPUTE;
                end
            end
            
            MODULO: begin
                // Divide by repeated subtraction (since modulus is constant)
                if (!mod_done) begin
                    // This loop continues in sequential logic
                    if (mod_temp < MODULUS) begin
                        next_state = FINISH;
                    end
                end else begin
                    next_state = FINISH;
                end
            end
            
            FINISH: begin
                next_state = IDLE;
            end
            
            default: begin
                next_state = IDLE;
                area_sum_next = 32'd0;
                acc_x_next = 32'd0;
                acc_y_next = 32'd0;
                temp_sum_next = 32'd0;
                mod_temp_next = 32'd0;
            end
        endcase
        
        // Safety timeout
        if (cycle_count >= MAX_ITERATIONS) begin
            next_state = MODULO;
            mod_temp_next = area_sum;
        end
    end
    
endmodule