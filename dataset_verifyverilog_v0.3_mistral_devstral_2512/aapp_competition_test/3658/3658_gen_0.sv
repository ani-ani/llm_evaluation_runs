module intersection_area (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [1:0] P,
    input wire [1:0] A,
    input wire [31:0] pine_x0, pine_y0,
    input wire [31:0] pine_x1, pine_y1,
    input wire [31:0] pine_x2, pine_y2,
    input wire [31:0] aspen_x0, aspen_y0,
    input wire [31:0] aspen_x1, aspen_y1,
    input wire [31:0] aspen_x2, aspen_y2,
    output reg [31:0] result,
    output reg done
);

// States
localparam [3:0] IDLE = 4'd0;
localparam [3:0] LOAD = 4'd1;
localparam [3:0] ORIENT = 4'd2;
localparam [3:0] PREP_CLIP = 4'd3;
localparam [3:0] CHECK_INSIDE = 4'd4;
localparam [3:0] COMPUTE_INTERSECTION = 4'd5;
localparam [3:0] ADD_VERTEX = 4'd6;
localparam [3:0] NEXT_EDGE = 4'd7;
localparam [3:0] NEXT_CLIP_EDGE = 4'd8;
localparam [3:0] CALC_AREA = 4'd9;
localparam [3:0] DONE_STATE = 4'd10;

// Registers
reg [3:0] state, next_state;
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
reg area_sign;
reg signed [63:0] cross_uv_reg, cross_vw_reg;
reg signed [31:0] int_x, int_y;
reg [5:0] div_cnt;
reg div_start;
reg signed [31:0] div_numer, div_denom, div_quot;
reg div_done;

// State transition
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        result <= 32'd0;
        done <= 1'b0;
        poly_cnt <= 3'd0;
        new_poly_cnt <= 3'd0;
        clip_edge_idx <= 3'd0;
        edge_idx <= 3'd0;
        vertex_idx <= 3'd0;
        area_sum <= 64'd0;
        area_sign <= 1'b0;
        div_start <= 1'b0;
        div_done <= 1'b0;
        int_x <= 32'd0;
        int_y <= 32'd0;
        div_cnt <= 6'd0;
        div_numer <= 32'd0;
        div_denom <= 32'd0;
        div_quot <= 32'd0;
    end else begin
        state <= next_state;
    end
end

// Next state logic
always @(*) begin
    next_state = state;
    case (state)
        IDLE: if (start) next_state = LOAD;
        LOAD: next_state = ORIENT;
        ORIENT: if (P >= 3 && A >= 3) next_state = PREP_CLIP; else next_state = DONE_STATE;
        PREP_CLIP: begin
            if (clip_edge_idx < 3) next_state = CHECK_INSIDE;
            else next_state = CALC_AREA;
        end
        CHECK_INSIDE: begin
            if (edge_idx < poly_cnt) next_state = COMPUTE_INTERSECTION;
            else next_state = NEXT_CLIP_EDGE;
        end
        COMPUTE_INTERSECTION: begin
            if (div_done) next_state = ADD_VERTEX;
            else next_state = COMPUTE_INTERSECTION;
        end
        ADD_VERTEX: next_state = NEXT_EDGE;
        NEXT_EDGE: begin
            if (edge_idx < poly_cnt) next_state = CHECK_INSIDE;
            else next_state = NEXT_CLIP_EDGE;
        end
        NEXT_CLIP_EDGE: begin
            if (clip_edge_idx < 3) next_state = PREP_CLIP;
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
        area_sign <= 1'b0;
        div_start <= 1'b0;
        div_done <= 1'b0;
        int_x <= 32'd0;
        int_y <= 32'd0;
        div_cnt <= 6'd0;
        div_numer <= 32'd0;
        div_denom <= 32'd0;
        div_quot <= 32'd0;
    end else begin
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
                poly_cnt <= 3'd3;
                new_poly_cnt <= 3'd0;
                clip_edge_idx <= 3'd0;
                edge_idx <= 3'd0;
                area_sum <= 64'd0;
                area_sign <= 1'b0;
            end

            ORIENT: begin
                // Orient triangle A to CCW
                if (P >= 3) begin
                    if ( ((triA_x[1] - triA_x[0]) * (triA_y[2] - triA_y[0]) - 
                          (triA_y[1] - triA_y[0]) * (triA_x[2] - triA_x[0])) < 0 ) begin
                        // swap vertices 1 and 2
                        triA_x[1] <= triA_x[2]; triA_y[1] <= triA_y[2];
                        triA_x[2] <= triA_x[1]; triA_y[2] <= triA_y[1];
                    end
                end
                // Orient triangle B to CCW
                if (A >= 3) begin
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
                clip_edge_idx <= clip_edge_idx + 3'd1;
                clip_start_x <= triB_x[clip_edge_idx];
                clip_start_y <= triB_y[clip_edge_idx];
                // next vertex, wrap around
                if (clip_edge_idx == 2) begin
                    clip_end_x <= triB_x[0];
                    clip_end_y <= triB_y[0];
                end else begin
                    clip_end_x <= triB_x[clip_edge_idx+1];
                    clip_end_y <= triB_y[clip_edge_idx+1];
                end
                new_poly_cnt <= 3'd0;
                edge_idx <= 3'd0;
            end

            CHECK_INSIDE: begin
                // Set current edge from polygon
                edge_start_x <= poly_x[edge_idx];
                edge_start_y <= poly_y[edge_idx];
                if (edge_idx == poly_cnt-1) begin
                    edge_end_x <= poly_x[0];
                    edge_end_y <= poly_y[0];
                end else begin
                    edge_end_x <= poly_x[edge_idx+1];
                    edge_end_y <= poly_y[edge_idx+1];
                end
            end

            COMPUTE_INTERSECTION: begin
                // Compute cross products
                cross_uv_reg <= (clip_end_x - clip_start_x)*(edge_end_y - edge_start_y) - 
                               (clip_end_y - clip_start_y)*(edge_end_x - edge_start_x);
                cross_vw_reg <= (clip_end_x - clip_start_x)*(edge_start_y - clip_start_y) - 
                               (clip_end_y - clip_start_y)*(edge_start_x - clip_start_x);
                // If edge crosses, need division
                if (cross_uv_reg != 0) begin
                    div_numer <= cross_vw_reg[31:0];
                    div_denom <= cross_uv_reg[31:0];
                    div_start <= 1'b1;
                end
            end

            ADD_VERTEX: begin
                // Add vertices to new_poly
                if (new_poly_cnt < 6) begin
                    new_poly_x[new_poly_cnt] <= edge_start_x;
                    new_poly_y[new_poly_cnt] <= edge_start_y;
                    new_poly_cnt <= new_poly_cnt + 3'd1;
                end
                edge_idx <= edge_idx + 3'd1;
            end

            NEXT_EDGE: begin
                // Move to next edge
                if (edge_idx == poly_cnt) begin
                    // Finished all edges, replace polygon
                    poly_cnt <= new_poly_cnt;
                    for (integer i = 0; i < 6; i = i + 1) begin
                        poly_x[i] <= new_poly_x[i];
                        poly_y[i] <= new_poly_y[i];
                    end
                end
            end

            NEXT_CLIP_EDGE: begin
                // Prepare for next clip edge
            end

            CALC_AREA: begin
                // Compute area of final polygon using shoelace
                area_sum <= 64'd0;
                for (integer i = 0; i < 6; i = i + 1) begin
                    if (i < poly_cnt) begin
                        if (i == poly_cnt-1) begin
                            area_sum <= area_sum + (poly_x[i] * poly_y[0] - poly_x[0] * poly_y[i]);
                        end else begin
                            area_sum <= area_sum + (poly_x[i] * poly_y[i+1] - poly_x[i+1] * poly_y[i]);
                        end
                    end
                end
                // Absolute value and scale
                if (area_sum[63]) begin
                    area_sum <= -area_sum;
                end
                result <= area_sum[63:32];
            end

            DONE_STATE: begin
                done <= 1'b1;
                if (!start) done <= 1'b0;
            end
        endcase
    end
end

endmodule