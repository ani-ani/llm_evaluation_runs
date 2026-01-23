module max_minions_attack (
    input clk,
    input rst_n,
    input start,
    input [1:0] n,
    input [3:0] m,
    input [15:0] R,
    input [15:0] village_x_0, village_y_0, village_r_0,
    input [15:0] village_x_1, village_y_1, village_r_1,
    input [15:0] minion_x_0, minion_y_0,
    input [15:0] minion_x_1, minion_y_1,
    input [15:0] minion_x_2, minion_y_2,
    input [15:0] minion_x_3, minion_y_3,
    input [15:0] minion_x_4, minion_y_4,
    input [15:0] minion_x_5, minion_y_5,
    input [15:0] minion_x_6, minion_y_6,
    input [15:0] minion_x_7, minion_y_7,
    output reg [7:0] max_count,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] CHECK_VILLAGE = 3'd1;
    localparam [2:0] CHECK_VILLAGE_DONE = 3'd2;
    localparam [2:0] COUNT_MINIONS = 3'd3;
    localparam [2:0] UPDATE_MAX = 3'd4;
    localparam [2:0] NEXT_CANDIDATE = 3'd5;
    localparam [2:0] DONE_STATE = 3'd6;

    // Registers
    reg [2:0] state;
    reg [3:0] cand_idx;
    reg [1:0] village_idx;
    reg valid;
    reg [7:0] current_count;
    reg [31:0] R_sq;
    reg [31:0] vr_plus_R_sq;
    reg [31:0] dist_sq;
    reg [15:0] dx, dy;

    // Storage for inputs
    reg [15:0] village_x [0:1];
    reg [15:0] village_y [0:1];
    reg [15:0] village_r [0:1];
    reg [15:0] minion_x [0:7];
    reg [15:0] minion_y [0:7];

    // Combinational: cover count for current candidate
    reg [3:0] cover_count;
    always @(*) begin
        cover_count = 4'd0;
        for (integer k = 0; k < 8; k = k + 1) begin
            if (k < m) begin
                reg [15:0] dx_temp, dy_temp;
                reg [31:0] dsq_temp;
                dx_temp = (minion_x[cand_idx] > minion_x[k]) ? (minion_x[cand_idx] - minion_x[k]) : (minion_x[k] - minion_x[cand_idx]);
                dy_temp = (minion_y[cand_idx] > minion_y[k]) ? (minion_y[cand_idx] - minion_y[k]) : (minion_y[k] - minion_y[cand_idx]);
                dsq_temp = dx_temp * dx_temp + dy_temp * dy_temp;
                if (dsq_temp <= R_sq) begin
                    cover_count = cover_count + 1;
                end
            end
        end
    end

    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            max_count <= 8'd0;
            cand_idx <= 4'd0;
            village_idx <= 2'd0;
            valid <= 1'b0;
            current_count <= 8'd0;
            R_sq <= 32'd0;
            vr_plus_R_sq <= 32'd0;
            dx <= 16'd0;
            dy <= 16'd0;
            // Load inputs into arrays
            village_x[0] <= village_x_0; village_y[0] <= village_y_0; village_r[0] <= village_r_0;
            village_x[1] <= village_x_1; village_y[1] <= village_y_1; village_r[1] <= village_r_1;
            minion_x[0] <= minion_x_0; minion_y[0] <= minion_y_0;
            minion_x[1] <= minion_x_1; minion_y[1] <= minion_y_1;
            minion_x[2] <= minion_x_2; minion_y[2] <= minion_y_2;
            minion_x[3] <= minion_x_3; minion_y[3] <= minion_y_3;
            minion_x[4] <= minion_x_4; minion_y[4] <= minion_y_4;
            minion_x[5] <= minion_x_5; minion_y[5] <= minion_y_5;
            minion_x[6] <= minion_x_6; minion_y[6] <= minion_y_6;
            minion_x[7] <= minion_x_7; minion_y[7] <= minion_y_7;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        R_sq <= R * R;
                        cand_idx <= 4'd0;
                        village_idx <= 2'd0;
                        valid <= 1'b1;
                        current_count <= 8'd0;
                        state <= CHECK_VILLAGE;
                    end
                end

                CHECK_VILLAGE: begin
                    if (minion_x[cand_idx] >= village_x[village_idx])
                        dx <= minion_x[cand_idx] - village_x[village_idx];
                    else
                        dx <= village_x[village_idx] - minion_x[cand_idx];
                    if (minion_y[cand_idx] >= village_y[village_idx])
                        dy <= minion_y[cand_idx] - village_y[village_idx];
                    else
                        dy <= village_y[village_idx] - minion_y[cand_idx];
                    vr_plus_R_sq <= (village_r[village_idx] + R) * (village_r[village_idx] + R);
                    state <= CHECK_VILLAGE_DONE;
                end

                CHECK_VILLAGE_DONE: begin
                    dist_sq <= dx * dx + dy * dy;
                    if (dist_sq < vr_plus_R_sq) begin
                        valid <= 1'b0;
                    end
                    if (village_idx + 1 < n) begin
                        village_idx <= village_idx + 1;
                        state <= CHECK_VILLAGE;
                    end else begin
                        if (valid) begin
                            current_count <= cover_count;
                            state <= UPDATE_MAX;
                        end else begin
                            state <= NEXT_CANDIDATE;
                        end
                    end
                end

                UPDATE_MAX: begin
                    if (current_count > max_count) begin
                        max_count <= current_count;
                    end
                    state <= NEXT_CANDIDATE;
                end

                NEXT_CANDIDATE: begin
                    if (cand_idx + 1 < m) begin
                        cand_idx <= cand_idx + 1;
                        village_idx <= 2'd0;
                        valid <= 1'b1;
                        state <= CHECK_VILLAGE;
                    end else begin
                        state <= DONE_STATE;
                    end
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