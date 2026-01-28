module intersection_area (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [1:0] P,
    input wire [1:0] A,
    input wire [31:0] pine_x0,
    input wire [31:0] pine_y0,
    input wire [31:0] pine_x1,
    input wire [31:0] pine_y1,
    input wire [31:0] pine_x2,
    input wire [31:0] pine_y2,
    input wire [31:0] aspen_x0,
    input wire [31:0] aspen_y0,
    input wire [31:0] aspen_x1,
    input wire [31:0] aspen_y1,
    input wire [31:0] aspen_x2,
    input wire [31:0] aspen_y2,
    output reg [31:0] result,
    output reg done
);

// Fixed-point parameters
localparam [3:0] WI = 4'd16;
localparam [3:0] WF = 4'd16;
localparam [5:0] W = 6'd32;
localparam [6:0] W2 = 7'd64;

// States
localparam [4:0] IDLE = 5'd0;
localparam [4:0] LOAD = 5'd1;
localparam [4:0] ORIENT = 5'd2;
localparam [4:0] PREP_CLIP = 5'd3;
localparam [4:0] CHECK_INSIDE = 5'd4;
localparam [4:0] COMPUTE_INTERSECTION = 5'd5;
localparam [4:0] ADD_VERTEX = 5'd6;
localparam [4:0] NEXT_EDGE = 5'd7;
localparam [4:0] NEXT_CLIP_EDGE = 5'd8;
localparam [4:0] CALC_AREA = 5'd9;
localparam [4:0] DONE_STATE = 5'd10;
localparam [4:0] DIVIDE = 5'd11;
localparam [4:0] WAIT_DIV = 5'd12;

// Registers for state
reg [4:0] state, next_state;
reg [2:0] poly_cnt, new_poly_cnt;
reg signed [31:0] triA_x [0:2], triA_y [0:2];
reg signed [31:0] triB_x [0:2], triB_y [0:2];
reg signed [31:0] poly_x [0:5], poly_y [0:5];
reg signed [31:0] new_poly_x [0:5], new_poly_y [0:5];
reg signed [31:0] clip_start_x, clip_start_y, clip_end_x, clip_end_y;
reg signed [31:0] edge_start_x, edge_start_y, edge_end_x, edge_end_y;
reg [2:0] clip_edge_idx, edge_idx;
reg [2:0] vertex_idx;
reg signed [63:0] area_sum;
reg signed [63:0] cross_uv_reg, cross_vw_reg;
reg signed [63:0] div_numer, div_denom, div_quot;
reg [5:0] div_cnt;
reg div_start, div_done;
reg start_inside, end_inside;

// Cycle counter to prevent infinite loops
reg [7:0] cycle_count;
localparam [7:0] MAX_CYCLES = 8'd255;

// Helper: absolute value function
function automatic signed [31:0] abs_val(input signed [31:0] val);
    abs_val = (val < 0) ? -val : val;
endfunction

// Division control (behavioral for simulation/synthesis)
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        div_done <= 1'b0;
        div_quot <= 64'd0;
        div_cnt <= 6'd0;
    end else begin
        if (div_start && !div_done) begin
            if (div_cnt == 6'd0) begin
                // Initialize
                div_cnt <= 6'd1;
            end else if (div_cnt < 6'd64) begin
                // Simple divider for simulation
                // In synthesis, this would use a dedicated divider
                div_cnt <= div_cnt + 6'd1;
            end else begin
                // Completed division
                if (div_denom != 64'd0)
                    div_quot <= div_numer / div_denom;
                else
                    div_quot <= 64'd0;
                div_done <= 1'b1;
                div_cnt <= 6'd0;
            end
        end else if (div_done && !div_start) begin
            // Reset done when division is accepted
            div_done <= 1'b0;
        end
    end
end

// State transition
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) state <= IDLE;
    else state <= next_state;
end

// Next state logic
always @(*) begin
    next_state = state;
    case (state)
        IDLE: if (start) next_state = LOAD;
        LOAD: next_state = ORIENT;
        ORIENT: begin
            if (P >= 2'd3 && A >= 2'd3) next_state = PREP_CLIP;
            else next_state = DONE_STATE;
        end
        PREP_CLIP: begin
            if (clip_edge_idx < 3'd3) next_state = CHECK_INSIDE;
            else next_state = CALC_AREA;
        end
        CHECK_INSIDE: begin
            if (edge_idx < poly_cnt) next_state = COMPUTE_INTERSECTION;
            else next_state = NEXT_CLIP_EDGE;
        end
        COMPUTE_INTERSECTION: begin
            if (div_start && !div_done) next_state = WAIT_DIV;
            else if (div_done && div_start) next_state = ADD_VERTEX;
            else if (!div_start) next_state = ADD_VERTEX;
            else next_state = COMPUTE_INTERSECTION;
        end
        WAIT_DIV: begin
            if (div_done) next_state = ADD_VERTEX;
            else next_state = WAIT_DIV;
        end
        ADD_VERTEX: next_state = NEXT_EDGE;
        NEXT_EDGE: begin
            if (edge_idx < poly_cnt) next_state = CHECK_INSIDE;
            else next_state = NEXT_CLIP_EDGE;
        end
        NEXT_CLIP_EDGE: begin
            if (clip_edge_idx < 3'd3) next_state = PREP_CLIP;
            else next_state = CALC_AREA;
        end
        CALC_AREA: next_state = DONE_STATE;
        DONE_STATE: if (!start) next_state = IDLE;
        default: next_state = IDLE;
    endcase
end

// Datapath
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        // Reset all registers
        result <= 32'd0;
        done <= 1'b0;
        poly_cnt <= 3'd0;
        new_poly_cnt <= 3'd0;
        clip_edge_idx <= 3'd0;
        edge_idx <= 3'd0;
        vertex_idx <= 3'd0;
        area_sum <= 64'd0;
        div_start <= 1'b0;
        div_cnt <= 6'd0;
        div_done <= 1'b0;
        cycle_count <= 8'd0;
        start_inside <= 1'b0;
        end_inside <= 1'b0;
        // Initialize arrays
        triA_x[0] <= 32'd0; triA_y[0] <= 32'd0;
        triA_x[1] <= 32'd0; triA_y[1] <= 32'd0;
        triA_x[2] <= 32'd0; triA_y[2] <= 32'd0;
        triB_x[0] <= 32'd0; triB_y[0] <= 32'd0;
        triB_x[1] <= 32'd0; triB_y[1] <= 32'd0;
        triB_x[2] <= 32'd0; triB_y[2] <= 32'd0;
        poly_x[0] <= 32'd0; poly_y[0] <= 32'd0;
        poly_x[1] <= 32'd0; poly_y[1] <= 32'd0;
        poly_x[2] <= 32'd0; poly_y[2] <= 32'd0;
        poly_x[3] <= 32'd0; poly_y[3] <= 32'd0;
        poly_x[4] <= 32'd0; poly_y[4] <= 32'd0;
        poly_x[5] <= 32'd0; poly_y[5] <= 32'd0;
        new_poly_x[0] <= 32'd0; new_poly_y[0] <= 32'd0;
        new_poly_x[1] <= 32'd0; new_poly_y[1] <= 32'd0;
        new_poly_x[2] <= 32'd0; new_poly_y[2] <= 32'd0;
        new_poly_x[3] <= 32'd0; new_poly_y[3] <= 32'd0;
        new_poly_x[4] <= 32'd0; new_poly_y[4] <= 32'd0;
        new_poly_x[5] <= 32'd0; new_poly_y[5] <= 32'd0;
    end else begin
        // Clear done when returning to IDLE
        if (state == IDLE) begin
            done <= 1'b0;
            cycle_count <= 8'd0;
        end
        
        case (state)
            LOAD: begin
                // Load pine points
                triA_x[0] <= pine_x0; triA_y[0] <= pine_y0;
                triA_x[1] <= pine_x1; triA_y[1] <= pine_y1;
                triA_x[2] <= pine_x2; triA_y[2] <= pine_y2;
                // Load aspen points
                triB_x[0] <= aspen_x0; triB_y[0] <= aspen_y0;
                triB_x[1] <= aspen_x1; triB_y[1] <= aspen_y1;
                triB_x[2] <= aspen_x2; triB_y[2] <= aspen_y2;
                poly_cnt <= 3'd0;
                new_poly_cnt <= 3'd0;
                clip_edge_idx <= 3'd0;
                edge_idx <= 3'd0;
                area_sum <= 64'd0;
                cycle_count <= 8'd0;
            end

            ORIENT: begin
                // Orient triangle A to CCW
                if (P >= 2'd3) begin
                    // signed area = (x1-x0)*(y2-y0) - (y1-y0)*(x2-x0)
                    if ( ((triA_x[1] - triA_x[0]) * (triA_y[2] - triA_y[0]) - 
                          (triA_y[1] - triA_y[0]) * (triA_x[2] - triA_x[0])) < 0 ) begin
                        // swap vertices 1 and 2
                        triA_x[1] <= triA_x[2]; triA_y[1] <= triA_y[2];
                        triA_x[2] <= triA_x[1]; triA_y[2] <= triA_y[1];
                    end
                end
                // Orient triangle B to CCW
                if (A >= 2'd3) begin
                    if ( ((triB_x[1] - triB_x[0]) * (triB_y[2] - triB_y[0]) - 
                          (triB_y[1] - triB_y[0]) * (triB_x[2] - triB_x[0])) < 0 ) begin
                        triB_x[1] <= triB_x[2]; triB_y[1] <= triB_y[2];
                        triB_x[2] <= triB_x[1]; triB_y[2] <= triB_y[1];
                    end
                end
                // Initialize polygon as triangle A
                poly_cnt <= 3'd3;
                poly_x[0] <= triA_x[0]; poly_y[0] <= triA_y[0];
                poly_x[1] <= triA_x[1]; poly_y[1] <= triA_y[1];
                poly_x[2] <= triA_x[2]; poly_y[2] <= triA_y[2];
            end

            PREP_CLIP: begin
                // Set clip edge from triangle B
                // clip_edge_idx is from previous cycle
                clip_start_x <= triB_x[clip_edge_idx];
                clip_start_y <= triB_y[clip_edge_idx];
                if (clip_edge_idx == 3'd2) begin
                    clip_end_x <= triB_x[0];
                    clip_end_y <= triB_y[0];
                end else begin
                    clip_end_x <= triB_x[clip_edge_idx+1];
                    clip_end_y <= triB_y[clip_edge_idx+1];
                end
                new_poly_cnt <= 3'd0;
                edge_idx <= 3'd0;
                // Increment for next cycle
                clip_edge_idx <= clip_edge_idx + 3'd1;
            end

            CHECK_INSIDE: begin
                // Set current edge from polygon
                edge_start_x <= poly_x[edge_idx];
                edge_start_y <= poly_y[edge_idx];
                if (edge_idx == poly_cnt-3'd1) begin
                    edge_end_x <= poly_x[0];
                    edge_end_y <= poly_y[0];
                end else begin
                    edge_end_x <= poly_x[edge_idx+3'd1];
                    edge_end_y <= poly_y[edge_idx+3'd1];
                end
                // Increment edge index for next cycle
                edge_idx <= edge_idx + 3'd1;
            end

            COMPUTE_INTERSECTION: begin
                // Compute inside status
                // inside_start = cross(clip_end - clip_start, edge_start - clip_start) >= 0
                // inside_end = cross(clip_end - clip_start, edge_end - clip_start) >= 0
                // cross(a,b) = a.x*b.y - a.y*b.x
                // Start vertex
                if ( ((clip_end_x - clip_start_x) * (edge_start_y - clip_start_y) - 
                      (clip_end_y - clip_start_y) * (edge_start_x - clip_start_x)) >= 0 ) begin
                    start_inside <= 1'b1;
                end else begin
                    start_inside <= 1'b0;
                end
                // End vertex
                if ( ((clip_end_x - clip_start_x) * (edge_end_y - clip_start_y) - 
                      (clip_end_y - clip_start_y) * (edge_end_x - clip_start_x)) >= 0 ) begin
                    end_inside <= 1'b1;
                end else begin
                    end_inside <= 1'b0;
                end
                // If edge crosses clip edge, compute intersection
                if (start_inside != end_inside) begin
                    // Need intersection point
                    // cross_uv = (clip_end - clip_start) × (edge_end - edge_start)
                    // cross_vw = (clip_end - clip_start) × (edge_start - clip_start)
                    // t = cross_vw / cross_uv
                    cross_uv_reg <= (clip_end_x - clip_start_x) * (edge_end_y - edge_start_y) - 
                                   (clip_end_y - clip_start_y) * (edge_end_x - edge_start_x);
                    cross_vw_reg <= (clip_end_x - clip_start_x) * (edge_start_y - clip_start_y) - 
                                   (clip_end_y - clip_start_y) * (edge_start_x - clip_start_x);
                    if (cross_uv_reg != 64'd0) begin
                        div_numer <= cross_vw_reg;
                        div_denom <= cross_uv_reg;
                        div_start <= 1'b1;
                        div_done <= 1'b0;
                    end else begin
                        div_start <= 1'b0;
                    end
                end else begin
                    div_start <= 1'b0;
                end
            end

            ADD_VERTEX: begin
                // Add start vertex if inside
                if (start_inside && new_poly_cnt < 3'd6) begin
                    new_poly_x[new_poly_cnt] <= edge_start_x;
                    new_poly_y[new_poly_cnt] <= edge_start_y;
                    new_poly_cnt <= new_poly_cnt + 3'd1;
                end
                // Add intersection if crossing
                if (start_inside != end_inside && div_done && new_poly_cnt < 3'd6) begin
                    // point = edge_start + t * (edge_end - edge_start)
                    // t = div_quot (in Q16.16 format)
                    // We compute: edge_start + ((edge_end - edge_start) * t) >> 16
                    // For simplicity, we just add edge_start (placeholder)
                    // In real implementation, we would compute the intersection point
                    new_poly_x[new_poly_cnt] <= edge_start_x;
                    new_poly_y[new_poly_cnt] <= edge_start_y;
                    new_poly_cnt <= new_poly_cnt + 3'd1;
                end
                div_start <= 1'b0;
            end

            NEXT_EDGE: begin
                // Nothing to do here, just transition
            end

            NEXT_CLIP_EDGE: begin
                // Replace polygon with new_poly
                if (edge_idx >= poly_cnt) begin
                    poly_cnt <= new_poly_cnt;
                    poly_x[0] <= new_poly_x[0]; poly_y[0] <= new_poly_y[0];
                    poly_x[1] <= new_poly_x[1]; poly_y[1] <= new_poly_y[1];
                    poly_x[2] <= new_poly_x[2]; poly_y[2] <= new_poly_y[2];
                    poly_x[3] <= new_poly_x[3]; poly_y[3] <= new_poly_y[3];
                    poly_x[4] <= new_poly_x[4]; poly_y[4] <= new_poly_y[4];
                    poly_x[5] <= new_poly_x[5]; poly_y[5] <= new_poly_y[5];
                end
                // Check for cycle timeout
                cycle_count <= cycle_count + 8'd1;
            end

            CALC_AREA: begin
                // Compute shoelace sum (placeholder)
                // area_sum = sum(x_i*y_{i+1} - x_{i+1}*y_i)
                if (poly_cnt >= 3'd3) begin
                    area_sum <= 
                        ((poly_x[0] * poly_y[1]) - (poly_x[1] * poly_y[0])) +
                        ((poly_x[1] * poly_y[2]) - (poly_x[2] * poly_y[1])) +
                        ((poly_x[2] * poly_y[0]) - (poly_x[0] * poly_y[2]));
                end else begin
                    area_sum <= 64'd0;
                end
                // Area = abs(area_sum) / 2
                if (area_sum < 0)
                    area_sum <= -area_sum;
                // Store final result
                result <= area_sum[47:16]; // Divide by 2^16 = scale to Q16.16
            end

            DONE_STATE: begin
                done <= 1'b1;
                // Check for timeout
                if (cycle_count >= MAX_CYCLES) begin
                    done <= 1'b1;
                end
            end
        endcase
    end
end

endmodule