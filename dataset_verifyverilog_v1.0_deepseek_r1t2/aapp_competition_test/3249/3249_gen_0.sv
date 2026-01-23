module bulkheads (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] N,
    input wire signed [15:0] x [0:7],
    input wire signed [15:0] y [0:7],
    input wire [31:0] C,
    output reg [7:0] M,
    output reg [31:0] x_bulk [0:99],
    output reg done
);

    // States
    localparam [2:0] IDLE            = 3'd0;
    localparam [2:0] COMPUTE_AREA    = 3'd1;
    localparam [2:0] COMPUTE_M       = 3'd2;
    localparam [2:0] COMPUTE_TARGET  = 3'd3;
    localparam [2:0] BINARY_SEARCH   = 3'd4;
    localparam [2:0] STORE_RESULT    = 3'd5;
    localparam [2:0] DONE_STATE      = 3'd6;
    
    reg [2:0] state, next_state;
    reg [3:0] vertex_idx;
    reg [63:0] area_sum;
    reg [31:0] total_area;
    
    // Binary search registers
    reg [3:0] iteration;
    reg [31:0] target_area;          // Q16.16
    reg [31:0] current_k;
    reg [31:0] low, high;
    reg signed [31:0] x_min, x_max;
    reg [31:0] mid;
    
    // Cumulative area calc
    reg signed [15:0] current_x;
    reg [63:0] cumulative_sum;
    
    // Find x_min/x_max
    integer i;
    always @(*) begin
        x_min = x[0];
        x_max = x[0];
        for (i = 1; i < 8; i = i + 1) begin
            if (i < N) begin
                x_min = (x[i] < x_min) ? x[i] : x_min;
                x_max = (x[i] > x_max) ? x[i] : x_max;
            end
        end
    end
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all registers
            state <= IDLE;
            M <= 8'd0;
            done <= 1'b0;
            total_area <= 32'd0;
            vertex_idx <= 4'd0;
            area_sum <= 64'd0;
            iteration <= 4'd0;
            current_k <= 32'd0;
            target_area <= 32'd0;
            low <= 32'd0;
            high <= 32'd0;
            mid <= 32'd0;
            
            // Clear x_bulk array
            for (i = 0; i < 100; i = i + 1) begin
                x_bulk[i] <= 32'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        vertex_idx <= 4'd0;
                        area_sum <= 64'd0;
                        state <= COMPUTE_AREA;
                    end
                end
                
                COMPUTE_AREA: begin
                    // Shoelace formula implementation
                    if (vertex_idx < N) begin
                        if (vertex_idx == N-1) begin
                            area_sum <= area_sum + (x[vertex_idx] * y[0] - x[0] * y[vertex_idx]);
                        end else begin
                            area_sum <= area_sum + (x[vertex_idx] * y[vertex_idx+1] - x[vertex_idx+1] * y[vertex_idx]);
                        end
                        vertex_idx <= vertex_idx + 1;
                    end else begin
                        // Absolute value and divide by 2
                        if (area_sum[63]) begin
                            total_area <= ((-area_sum) >> 1);
                        end else begin
                            total_area <= (area_sum >> 1);
                        end
                        state <= COMPUTE_M;
                    end
                end
                
                COMPUTE_M: begin
                    if (total_area >= C) begin
                        M <= (total_area / C >= 100) ? 8'd100 : (total_area / C);
                    end else begin
                        M <= 8'd1;
                    end
                    
                    if ((total_area / C) == 0) begin
                        state <= DONE_STATE;
                    end else begin
                        current_k <= 32'd1;
                        state <= COMPUTE_TARGET;
                    end
                end
                
                COMPUTE_TARGET: begin
                    if (current_k < M) begin
                        // target_area = (current_k * total_area) / M
                        target_area <= (current_k * total_area) / M;
                        low <= x_min;
                        high <= x_max;
                        iteration <= 4'd0;
                        state <= BINARY_SEARCH;
                    end else begin
                        state <= DONE_STATE;
                    end
                end
                
                BINARY_SEARCH: begin
                    mid <= (low + high) >> 1;  // (low+high)/2
                    current_x <= mid[31:16];   // Q16.16 integer part
                    cumulative_sum <= 64'd0;
                    vertex_idx <= 4'd0;
                    state <= BINARY_SEARCH_CALC;
                end
                
                BINARY_SEARCH_CALC: begin
                    // Trapezoidal area calc
                    if (vertex_idx < N) begin
                        integer next_idx = (vertex_idx == N-1) ? 0 : vertex_idx+1;
                        
                        // Check if edge spans current_x
                        if ((x[vertex_idx] <= current_x && current_x <= x[next_idx]) ||
                            (x[next_idx] <= current_x && current_x <= x[vertex_idx])) begin
                            // Linearly interpolate y
                            reg signed [31:0] dx = x[next_idx] - x[vertex_idx];
                            reg signed [31:0] dy = y[next_idx] - y[vertex_idx];
                            reg signed [31:0] y_interp = y[vertex_idx] + ((current_x - x[vertex_idx]) * dy) / dx;
                            
                            // Assume upper/lower based on CCW (update cumulative area)
                            cumulative_sum <= cumulative_sum + y_interp;
                        end
                        vertex_idx <= vertex_idx + 1;
                    end else begin
                        // Complete cumulative calc
                        iteration <= iteration + 1;
                        
                        if (cumulative_sum < (target_area << 16)) begin
                            low <= mid;
                        end else begin
                            high <= mid;
                        end
                        
                        if (iteration == 4'd15) begin
                            state <= STORE_RESULT;
                        end else begin
                            state <= BINARY_SEARCH;
                        end
                    end
                end
                
                STORE_RESULT: begin
                    x_bulk[current_k-1] <= mid;
                    current_k <= current_k + 1;
                    state <= COMPUTE_TARGET;
                end
                
                DONE_STATE: begin
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule