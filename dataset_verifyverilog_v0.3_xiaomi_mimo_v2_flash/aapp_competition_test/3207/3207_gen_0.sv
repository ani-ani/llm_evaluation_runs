module ChameleonTrack #(
    parameter N = 4,
    parameter K = 4,
    parameter L = 16,
    parameter FIXED_SHIFT = 8,
    parameter DATA_WIDTH = 16,
    parameter COLOR_WIDTH = 3,
    parameter DIST_WIDTH = 32,
    parameter TIME_WIDTH = 16,
    parameter IDX_WIDTH = 2
)(
    input  clk,
    input  rst_n,
    input  start,
    input  [N-1:0]          valid,
    input  [DATA_WIDTH-1:0] pos  [0:N-1],
    input  [COLOR_WIDTH-1:0] color[0:N-1],
    input  [N-1:0]          dir,
    output reg [DIST_WIDTH-1:0] total_dist[0:K-1],
    output reg done
);

    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] INIT = 2'd1;
    localparam [1:0] PROCESS = 2'd2;
    localparam [1:0] DONE_STATE = 2'd3;

    reg [1:0] state, next_state;
    reg [N-1:0] active_reg;
    reg [DATA_WIDTH-1:0] pos_reg [0:N-1];
    reg [COLOR_WIDTH-1:0] color_reg [0:N-1];
    reg [N-1:0] dir_reg;
    reg [DIST_WIDTH-1:0] personal_dist [0:N-1];
    reg [TIME_WIDTH-1:0] cycle_count;
    reg [TIME_WIDTH-1:0] max_time;
    reg [IDX_WIDTH-1:0] chameleon_idx;
    reg signed [TIME_WIDTH-1:0] time_to_event;
    reg [DIST_WIDTH-1:0] temp_dist;
    reg signed [DATA_WIDTH-1:0] pos_delta;
    reg signed [DATA_WIDTH-1:0] current_pos;
    reg signed [DATA_WIDTH-1:0] other_pos;
    reg collision_detected;
    reg fall_off_detected;
    reg processing_done;
    reg [COLOR_WIDTH-1:0] new_color;
    integer i;
    integer j;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            for (i = 0; i < N; i = i + 1) begin
                active_reg[i] <= 1'b0;
                pos_reg[i] <= 16'd0;
                color_reg[i] <= 3'd0;
                dir_reg[i] <= 1'b0;
                personal_dist[i] <= 32'd0;
            end
            for (i = 0; i < K; i = i + 1) begin
                total_dist[i] <= 32'd0;
            end
            cycle_count <= 16'd0;
            chameleon_idx <= 2'd0;
            time_to_event <= 16'hFFFF;
            temp_dist <= 32'd0;
            pos_delta <= 16'd0;
            current_pos <= 16'd0;
            other_pos <= 16'd0;
            collision_detected <= 1'b0;
            fall_off_detected <= 1'b0;
            processing_done <= 1'b0;
            new_color <= 3'd0;
            max_time <= 16'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 16'd0;
                    if (start) begin
                        state <= INIT;
                    end
                end

                INIT: begin
                    for (i = 0; i < N; i = i + 1) begin
                        if (valid[i]) begin
                            active_reg[i] <= 1'b1;
                            pos_reg[i] <= pos[i];
                            color_reg[i] <= color[i];
                            dir_reg[i] <= dir[i];
                            personal_dist[i] <= 32'd0;
                        end else begin
                            active_reg[i] <= 1'b0;
                        end
                    end
                    for (i = 0; i < K; i = i + 1) begin
                        total_dist[i] <= 32'd0;
                    end
                    chameleon_idx <= 2'd0;
                    processing_done <= 1'b0;
                    state <= PROCESS;
                end

                PROCESS: begin
                    if (processing_done) begin
                        state <= DONE_STATE;
                    end else begin
                        time_to_event <= 16'hFFFF;
                        collision_detected <= 1'b0;
                        fall_off_detected <= 1'b0;
                        
                        for (i = 0; i < N; i = i + 1) begin
                            if (active_reg[i]) begin
                                if (dir_reg[i]) begin
                                    pos_delta <= L * (16'd1 << FIXED_SHIFT) - pos_reg[i];
                                end else begin
                                    pos_delta <= pos_reg[i];
                                end
                                if (pos_delta < time_to_event && pos_delta >= 0) begin
                                    time_to_event <= pos_delta;
                                    chameleon_idx <= i[IDX_WIDTH-1:0];
                                    fall_off_detected <= 1'b1;
                                    collision_detected <= 1'b0;
                                end
                                
                                for (j = i + 1; j < N; j = j + 1) begin
                                    if (active_reg[j]) begin
                                        if (dir_reg[i] && !dir_reg[j] && pos_reg[i] < pos_reg[j]) begin
                                            pos_delta <= (pos_reg[j] - pos_reg[i]) >>> 1;
                                        end else if (!dir_reg[i] && dir_reg[j] && pos_reg[i] > pos_reg[j]) begin
                                            pos_delta <= (pos_reg[i] - pos_reg[j]) >>> 1;
                                        end else begin
                                            pos_delta <= 16'hFFFF;
                                        end
                                        if (pos_delta < time_to_event && pos_delta >= 0) begin
                                            time_to_event <= pos_delta;
                                            chameleon_idx <= i[IDX_WIDTH-1:0];
                                            fall_off_detected <= 1'b0;
                                            collision_detected <= 1'b1;
                                        end
                                    end
                                end
                            end
                        end
                        
                        if (time_to_event == 16'hFFFF || time_to_event == 16'd0) begin
                            processing_done <= 1'b1;
                        end else begin
                            for (i = 0; i < N; i = i + 1) begin
                                if (active_reg[i]) begin
                                    if (dir_reg[i]) begin
                                        pos_reg[i] <= pos_reg[i] + time_to_event;
                                    end else begin
                                        pos_reg[i] <= pos_reg[i] - time_to_event;
                                    end
                                    personal_dist[i] <= personal_dist[i] + time_to_event;
                                end
                            end
                            if (collision_detected) begin
                                for (j = 0; j < N; j = j + 1) begin
                                    if (active_reg[j] && j != chameleon_idx) begin
                                        if ((dir_reg[chameleon_idx] && !dir_reg[j] && pos_reg[chameleon_idx] < pos_reg[j]) ||
                                            (!dir_reg[chameleon_idx] && dir_reg[j] && pos_reg[chameleon_idx] > pos_reg[j])) begin
                                            new_color <= (color_reg[chameleon_idx] + color_reg[j]) % K;
                                            color_reg[chameleon_idx] <= color_reg[j];
                                            color_reg[j] <= new_color;
                                            dir_reg[chameleon_idx] <= ~dir_reg[chameleon_idx];
                                            dir_reg[j] <= ~dir_reg[j];
                                        end
                                    end
                                end
                            end else if (fall_off_detected) begin
                                if (active_reg[chameleon_idx]) begin
                                    total_dist[color_reg[chameleon_idx]] <= total_dist[color_reg[chameleon_idx]] + personal_dist[chameleon_idx];
                                    active_reg[chameleon_idx] <= 1'b0;
                                end
                            end
                        end
                    end
                end

                DONE_STATE: begin
                    done <= 1'b1;
                    if (!start) begin
                        state <= IDLE;
                    end
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule