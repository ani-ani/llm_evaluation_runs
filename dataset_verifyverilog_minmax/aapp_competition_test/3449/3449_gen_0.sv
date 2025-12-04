module club_fencing_cost(
    input clk,
    input rst_n,
    input start,
    input [3:0] B,
    input [2:0] H,
    input [2:0] R,
    input [2:0] C,
    input [15:0] grid,
    output reg [10:0] total_cost,
    output reg done
);

    localparam [2:0] IDLE = 3'd0,
                     CALC_LIGHTS = 3'd1,
                     FIND_DARK = 3'd2,
                     CALC_FENCES = 3'd3,
                     DONE_ST = 3'd4;
    
    reg [2:0] state;
    reg [3:0] grid_vals [0:15];
    reg [31:0] lights [0:15];
    reg [15:0] is_dark;
    
    reg [3:0] dest_idx, src_idx;
    reg [2:0] dest_r, dest_c, src_r, src_c;
    reg [31:0] light_accum;
    
    reg [5:0] div_iter;
    reg [47:0] div_numer;
    reg [31:0] div_result;
    reg [15:0] div_denom;
    
    reg [4:0] fence_idx;
    reg fence_horiz;
    
    reg [7:0] dx, dy;
    reg [15:0] dx2, dy2, h2, denom;
    reg [31:0] numer;
    reg [3:0] idx1, idx2;
    reg [2:0] fi, fj;
    
    integer k;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (k = 0; k < 16; k = k + 1)
                grid_vals[k] <= 4'd0;
        end else if (state == IDLE && start) begin
            grid_vals[0] <= grid[15:12];
            grid_vals[1] <= grid[11:8];
            grid_vals[2] <= grid[7:4];
            grid_vals[3] <= grid[3:0];
            for (k = 4; k < 16; k = k + 1)
                grid_vals[k] <= 4'd0;
        end
    end
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            total_cost <= 11'd0;
            dest_idx <= 4'd0;
            src_idx <= 4'd0;
            light_accum <= 32'd0;
            div_iter <= 6'd0;
            is_dark <= 16'd0;
            fence_idx <= 5'd0;
            fence_horiz <= 1'b1;
            for (k = 0; k < 16; k = k + 1)
                lights[k] <= 32'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= CALC_LIGHTS;
                        dest_idx <= 4'd0;
                        src_idx <= 4'd0;
                        light_accum <= 32'd0;
                        div_iter <= 6'd0;
                        for (k = 0; k < 16; k = k + 1)
                            lights[k] <= 32'd0;
                    end
                end
                
                CALC_LIGHTS: begin
                    dest_r = dest_idx >> 2;
                    dest_c = dest_idx[1:0];
                    src_r = src_idx >> 2;
                    src_c = src_idx[1:0];
                    
                    if (dest_r >= R || dest_c >= C) begin
                        if (dest_idx < 15) begin
                            dest_idx <= dest_idx + 1;
                            src_idx <= 4'd0;
                            light_accum <= 32'd0;
                        end else begin
                            state <= FIND_DARK;
                            dest_idx <= 4'd0;
                        end
                    end else if (div_iter == 0) begin
                        if (src_r >= R || src_c >= C) begin
                            lights[dest_idx] <= light_accum;
                            if (dest_idx < 15) begin
                                dest_idx <= dest_idx + 1;
                                src_idx <= 4'd0;
                                light_accum <= 32'd0;
                            end else begin
                                state <= FIND_DARK;
                                dest_idx <= 4'd0;
                            end
                        end else begin
                            dx = (dest_r > src_r) ? (dest_r - src_r) : (src_r - dest_r);
                            dy = (dest_c > src_c) ? (dest_c - src_c) : (src_c - dest_c);
                            dx2 = dx * dx;
                            dy2 = dy * dy;
                            h2 = H * H;
                            denom = dx2 + dy2 + h2;
                            if (denom == 0) denom = 1;
                            numer = {16'd0, grid_vals[src_idx]} << 16;
                            div_numer <= {16'd0, numer};
                            div_denom <= denom;
                            div_result <= 32'd0;
                            div_iter <= 6'd1;
                        end
                    end else if (div_iter <= 32) begin
                        if (div_numer[47:16] >= {16'd0, div_denom}) begin
                            div_numer <= (div_numer - ({16'd0, div_denom, 16'd0})) << 1;
                            div_result <= (div_result << 1) | 1;
                        end else begin
                            div_numer <= div_numer << 1;
                            div_result <= div_result << 1;
                        end
                        div_iter <= div_iter + 1;
                    end else begin
                        light_accum <= light_accum + div_result;
                        div_iter <= 6'd0;
                        src_idx <= src_idx + 1;
                    end
                end
                
                FIND_DARK: begin
                    if (dest_idx < 16) begin
                        dest_r = dest_idx >> 2;
                        dest_c = dest_idx[1:0];
                        if (dest_r < R && dest_c < C) begin
                            is_dark[dest_idx] <= (lights[dest_idx] < ({16'd0, B} << 16));
                        end
                        dest_idx <= dest_idx + 1;
                    end else begin
                        state <= CALC_FENCES;
                        fence_idx <= 5'd0;
                        fence_horiz <= 1'b1;
                        total_cost <= 11'd0;
                    end
                end
                
                CALC_FENCES: begin
                    if (fence_horiz) begin
                        fi = fence_idx >> 2;
                        fj = fence_idx[1:0];
                        if (fi < R && fj < C - 1) begin
                            idx1 = {fi, fj};
                            idx2 = {fi, fj + 2'd1};
                            if (is_dark[idx1] && is_dark[idx2])
                                total_cost <= total_cost + 11'd43;
                            else if (is_dark[idx1] || is_dark[idx2])
                                total_cost <= total_cost + 11'd11;
                        end
                        if (fence_idx < 15)
                            fence_idx <= fence_idx + 1;
                        else begin
                            fence_horiz <= 1'b0;
                            fence_idx <= 5'd0;
                        end
                    end else begin
                        fi = fence_idx >> 2;
                        fj = fence_idx[1:0];
                        if (fi < R - 1 && fj < C) begin
                            idx1 = {fi, fj};
                            idx2 = {fi + 2'd1, fj};
                            if (is_dark[idx1] && is_dark[idx2])
                                total_cost <= total_cost + 11'd43;
                            else if (is_dark[idx1] || is_dark[idx2])
                                total_cost <= total_cost + 11'd11;
                        end
                        if (fence_idx < 15)
                            fence_idx <= fence_idx + 1;
                        else
                            state <= DONE_ST;
                    end
                end
                
                DONE_ST: begin
                    done <= 1'b1;
                    if (!start)
                        state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end

endmodule