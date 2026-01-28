module sand_art(
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

    localparam [3:0] N = 8;
    localparam [3:0] M = 8;
    localparam [5:0] MAX_CYCLES = 6'd5000;

    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] BINARY_SEARCH = 3'd1;
    localparam [2:0] FEASIBILITY_CHECK = 3'd2;
    localparam [2:0] DONE_STATE = 3'd3;

    reg [2:0] state;
    reg [15:0] cycle_count;

    reg [31:0] low_D;
    reg [31:0] high_D;
    reg [31:0] mid_D;
    reg [31:0] best_D;

    reg [15:0] w;
    reg [15:0] h;
    reg [7:0][31:0] volume;
    reg [8:0][15:0] divider_x;
    reg [7:0][7:0][31:0] min_amount;
    reg [7:0][7:0][31:0] max_amount;

    reg [15:0] section_width [0:N-1];
    reg [31:0] total_volume;
    reg [31:0] avg_height;

    reg [31:0] H_low;
    reg [31:0] H_high;
    reg [31:0] section_min_vol [0:N-1];
    reg [31:0] section_max_vol [0:N-1];

    reg [31:0] section_min_sum [0:N-1];
    reg [31:0] section_max_sum [0:N-1];
    reg [31:0] total_min_sum;
    reg [31:0] total_max_sum;

    reg [31:0] color_used [0:M-1];
    reg [31:0] section_alloc [0:N-1][0:M-1];

    reg feasible;
    reg [3:0] section_idx;
    reg [3:0] color_idx;

    integer i, j;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            cycle_count <= 16'd0;
            done <= 1'b0;
            result <= 32'd0;
            low_D <= 32'd0;
            high_D <= 32'd0;
            mid_D <= 32'd0;
            best_D <= 32'd0;
            w <= 16'd0;
            h <= 16'd0;
            for (i = 0; i < M; i = i + 1) begin
                volume[i] <= 32'd0;
            end
            for (i = 0; i < N+1; i = i + 1) begin
                divider_x[i] <= 16'd0;
            end
            for (i = 0; i < N; i = i + 1) begin
                for (j = 0; j < M; j = j + 1) begin
                    min_amount[i][j] <= 32'd0;
                    max_amount[i][j] <= 32'd0;
                end
            end
            for (i = 0; i < N; i = i + 1) begin
                section_width[i] <= 16'd0;
            end
            total_volume <= 32'd0;
            avg_height <= 32'd0;
            H_low <= 32'd0;
            H_high <= 32'd0;
            for (i = 0; i < N; i = i + 1) begin
                section_min_vol[i] <= 32'd0;
                section_max_vol[i] <= 32'd0;
                section_min_sum[i] <= 32'd0;
                section_max_sum[i] <= 32'd0;
            end
            total_min_sum <= 32'd0;
            total_max_sum <= 32'd0;
            for (i = 0; i < M; i = i + 1) begin
                color_used[i] <= 32'd0;
            end
            for (i = 0; i < N; i = i + 1) begin
                for (j = 0; j < M; j = j + 1) begin
                    section_alloc[i][j] <= 32'd0;
                end
            end
            feasible <= 1'b0;
            section_idx <= 4'd0;
            color_idx <= 4'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 16'd0;
                    if (start) begin
                        w <= w_in;
                        h <= h_in;
                        for (i = 0; i < M; i = i + 1) begin
                            volume[i] <= volume_in[i];
                        end
                        for (i = 0; i < N+1; i = i + 1) begin
                            divider_x[i] <= divider_x_in[i];
                        end
                        for (i = 0; i < N; i = i + 1) begin
                            for (j = 0; j < M; j = j + 1) begin
                                min_amount[i][j] <= min_in[i][j];
                                max_amount[i][j] <= max_in[i][j];
                            end
                        end
                        for (i = 0; i < N; i = i + 1) begin
                            section_width[i] <= divider_x[i+1] - divider_x[i];
                        end
                        total_volume <= 32'd0;
                        for (i = 0; i < M; i = i + 1) begin
                            total_volume <= total_volume + volume[i];
                        end
                        avg_height <= total_volume / w;
                        low_D <= 32'd0;
                        high_D <= 32'd1000000;
                        best_D <= 32'd1000000;
                        state <= BINARY_SEARCH;
                    end
                end

                BINARY_SEARCH: begin
                    cycle_count <= cycle_count + 16'd1;
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= DONE_STATE;
                    end else begin
                        if (low_D <= high_D) begin
                            mid_D <= (low_D + high_D) / 2;
                            H_low <= avg_height - mid_D / 2;
                            H_high <= avg_height + mid_D / 2;
                            section_idx <= 4'd0;
                            state <= FEASIBILITY_CHECK;
                        end else begin
                            state <= DONE_STATE;
                        end
                    end
                end

                FEASIBILITY_CHECK: begin
                    cycle_count <= cycle_count + 16'd1;
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= DONE_STATE;
                    end else begin
                        if (section_idx == 0) begin
                            for (i = 0; i < N; i = i + 1) begin
                                section_min_vol[i] <= section_width[i] * H_low;
                                section_max_vol[i] <= section_width[i] * H_high;
                            end
                            for (i = 0; i < N; i = i + 1) begin
                                section_min_sum[i] <= 32'd0;
                                section_max_sum[i] <= 32'd0;
                                for (j = 0; j < M; j = j + 1) begin
                                    section_min_sum[i] <= section_min_sum[i] + min_amount[i][j];
                                    section_max_sum[i] <= section_max_sum[i] + max_amount[i][j];
                                end
                            end
                            total_min_sum <= 32'd0;
                            total_max_sum <= 32'd0;
                            for (i = 0; i < N; i = i + 1) begin
                                total_min_sum <= total_min_sum + section_min_sum[i];
                                total_max_sum <= total_max_sum + section_max_sum[i];
                            end
                            feasible <= 1'b1;
                            for (i = 0; i < N; i = i + 1) begin
                                if (section_min_sum[i] > section_max_vol[i] || section_max_sum[i] < section_min_vol[i]) begin
                                    feasible <= 1'b0;
                                end
                            end
                            if (total_min_sum > total_volume || total_max_sum < total_volume) begin
                                feasible <= 1'b0;
                            end
                            if (feasible) begin
                                best_D <= mid_D;
                                high_D <= mid_D - 32'd1;
                            end else begin
                                low_D <= mid_D + 32'd1;
                            end
                            state <= BINARY_SEARCH;
                        end
                    end
                end

                DONE_STATE: begin
                    result <= best_D;
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule