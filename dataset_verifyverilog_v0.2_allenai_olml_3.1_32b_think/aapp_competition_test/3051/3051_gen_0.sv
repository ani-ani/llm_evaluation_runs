module fog_catcher (
    input clk,
    input rst_n,
    input start,
    input [4:0] fog_count,
    input [15:0] fog_day [0:15],
    input [7:0] fog_l [0:15],
    input [7:0] fog_r [0:15],
    input [7:0] fog_h [0:15],
    output reg [7:0] missed_count,
    output reg done)
;

    localparam IDLE = 3'b000;
    localparam LOAD_FOG = 3'b001;
    localparam CHECK_CONTAINMENT = 3'b010;
    localparam ADD_NET = 3'b011;
    localparam UPDATE_COUNTER = 3'b100;
    localparam DONE = 3'b101;

    reg [2:0] state;
    reg [3:0] fog_index;
    reg [3:0] current_net_count;
    reg [7:0] current_l, current_r, current_h;
    reg [7:0] net_l [0:15], net_r [0:15], net_h [0:15];
    reg [7:0] missed_count_reg;

    reg is_covered;

    always @(posedge clk) begin
        if (!rst_n) begin
            state <= IDLE;
            fog_index <= 4'd0;
            current_net_count <= 4'd0;
            current_l <= 8'd0;
            current_r <= 8'd0;
            current_h <= 8'd0;
            net_l[0] <= 8'd0; net_l[1] <= 8'd0; net_l[2] <= 8'd0; net_l[3] <= 8'd0;
            net_l[4] <= 8'd0; net_l[5] <= 8'd0; net_l[6] <= 8'd0; net_l[7] <= 8'd0;
            net_l[8] <= 8'd0; net_l[9] <= 8'd0; net_l[10] <= 8'd0; net_l[11] <= 8'd0;
            net_l[12] <= 8'd0; net_l[13] <= 8'd0; net_l[14] <= 8'd0; net_l[15] <= 8'd0;
            net_r[0] <= 8'd0; net_r[1] <= 8'd0; net_r[2] <= 8'd0; net_r[3] <= 8'd0;
            net_r[4] <= 8'd0; net_r[5] <= 8'd0; net_r[6] <= 8'd0; net_r[7] <= 8'd0;
            net_r[8] <= 8'd0; net_r[9] <= 8'd0; net_r[10] <= 8'd0; net_r[11] <= 8'd0;
            net_r[12] <= 8'd0; net_r[13] <= 8'd0; net_r[14] <= 8'd0; net_r[15] <= 8'd0;
            net_h[0] <= 8'd0; net_h[1] <= 8'd0; net_h[2] <= 8'd0; net_h[3] <= 8'd0;
            net_h[4] <= 8'd0; net_h[5] <= 8'd0; net_h[6] <= 8'd0; net_h[7] <= 8'd0;
            net_h[8] <= 8'd0; net_h[9] <= 8'd0; net_h[10] <= 8'd0; net_h[11] <= 8'd0;
            net_h[12] <= 8'd0; net_h[13] <= 8'd0; net_h[14] <= 8'd0; net_h[15] <= 8'd0;
            missed_count_reg <= 8'd0;
            done <= 1'b0;
        end else begin
            done <= 1'b0;
            case (state)
                IDLE: begin
                    if (start) begin
                        state <= LOAD_FOG;
                    end else begin
                        state <= IDLE;
                    end
                end
                LOAD_FOG: begin
                    current_l <= fog_l[fog_index];
                    current_r <= fog_r[fog_index];
                    current_h <= fog_h[fog_index];
                    if (fog_index < fog_count) begin
                        state <= CHECK_CONTAINMENT;
                    end else begin
                        state <= DONE;
                    end
                end
                CHECK_CONTAINMENT: begin
                    is_covered = 1'b0;
                    if (current_net_count > 0) begin
                        is_covered = (current_l >= net_l[0] && current_r <= net_r[0] && current_h <= net_h[0]);
                    end
                    if (current_net_count > 1) begin
                        is_covered = is_covered || (current_l >= net_l[1] && current_r <= net_r[1] && current_h <= net_h[1]);
                    end
                    if (current_net_count > 2) begin
                        is_covered = is_covered || (current_l >= net_l[2] && current_r <= net_r[2] && current_h <= net_h[2]);
                    end
                    if (current_net_count > 3) begin
                        is_covered = is_covered || (current_l >= net_l[3] && current_r <= net_r[3] && current_h <= net_h[3]);
                    end
                    if (current_net_count > 4) begin
                        is_covered = is_covered || (current_l >= net_l[4] && current_r <= net_r[4] && current_h <= net_h[4]);
                    end
                    if (current_net_count > 5) begin
                        is_covered = is_covered || (current_l >= net_l[5] && current_r <= net_r[5] && current_h <= net_h[5]);
                    end
                    if (current_net_count > 6) begin
                        is_covered = is_covered || (current_l >= net_l[6] && current_r <= net_r[6] && current_h <= net_h[6]);
                    end
                    if (current_net_count > 7) begin
                        is_covered = is_covered || (current_l >= net_l[7] && current_r <= net_r[7] && current_h <= net_h[7]);
                    end
                    if (current_net_count > 8) begin
                        is_covered = is_covered || (current_l >= net_l[8] && current_r <= net_r[8] && current_h <= net_h[8]);
                    end
                    if (current_net_count > 9) begin
                        is_covered = is_covered || (current_l >= net_l[9] && current_r <= net_r[9] && current_h <= net_h[9]);
                    end
                    if (current_net_count > 10) begin
                        is_covered = is_covered || (current_l >= net_l[10] && current_r <= net_r[10] && current_h <= net_h[10]);
                    end
                    if (current_net_count > 11) begin
                        is_covered = is_covered || (current_l >= net_l[11] && current_r <= net_r[11] && current_h <= net_h[11]);
                    end
                    if (current_net_count > 12) begin
                        is_covered = is_covered || (current_l >= net_l[12] && current_r <= net_r[12] && current_h <= net_h[12]);
                    end
                    if (current_net_count > 13) begin
                        is_covered = is_covered || (current_l >= net_l[13] && current_r <= net_r[13] && current_h <= net_h[13]);
                    end
                    if (current_net_count > 14) begin
                        is_covered = is_covered || (current_l >= net_l[14] && current_r <= net_r[14] && current_h <= net_h[14]);
                    end
                    if (current_net_count > 15) begin
                        is_covered = is_covered || (current_l >= net_l[15] && current_r <= net_r[15] && current_h <= net_h[15]);
                    end
                    if (is_covered) begin
                        fog_index <= fog_index + 1;
                        if (fog_index < fog_count) begin
                            state <= LOAD_FOG;
                        end else begin
                            state <= DONE;
                        end
                    end else begin
                        state <= ADD_NET;
                    end
                end
                ADD_NET: begin
                    if (current_net_count < 16) begin
                        net_l[current_net_count] <= current_l;
                        net_r[current_net_count] <= current_r;
                        net_h[current_net_count] <= current_h;
                        current_net_count <= current_net_count + 1;
                    end
                    state <= UPDATE_COUNTER;
                end
                UPDATE_COUNTER: begin
                    missed_count_reg <= missed_count_reg + 1;
                    fog_index <= fog_index + 1;
                    if (fog_index < fog_count) begin
                        state <= LOAD_FOG;
                    end else begin
                        state <= DONE;
                    end
                end
                DONE: begin
                    state <= DONE;
                end
            endcase

            if (state == DONE) begin
                done <= 1'b1;
            end else begin
                done <= 1'b0;
            end

            missed_count <= missed_count_reg;
        end
    end

endmodule