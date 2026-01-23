module complex_angle (
    input clk,
    input rst_n, // active low
    input start,
    input signed [15:0] a,
    input signed [15:0] b,
    output reg signed [31:0] angle,
    output reg done
);

reg [2:0] state, next_state;
localparam IDLE = 3'd0, CALCULATING =3'd1, DONE=3'd2;

reg [31:0] x, y;
reg [31:0] angle_reg;
reg [3:0] iter_cnt;

localparam [31:0] theta_i_values [16] = {
    32'h0000C9A9, 32'h000752F2, 32'h0003E5A, 32'h0001FF8, 32'h000FF3B,
    32'h00000800, 32'h00000400, 32'h00000200, 32'h00000100, 32'h00000080,
    32'h00000040, 32'h00000020, 32'h00000010, 32'h00000008, 32'h00000004,
    32'h00000002
};

always @(*) begin
    next_state = state;
    done = (state == DONE);

    case(state)
        IDLE: begin
            if (!rst_n) begin
                x <= 32'd0;
                y <= 32'd0;
                angle_reg <= 32'd0;
                iter_cnt <= 4'd0;
            end else if (start) begin
                x <= a << 16;
                y <= b << 16;
                angle_reg <= 32'd0;
                iter_cnt <= 4'd0;
                next_state = CALCULATING;
            end
        end
        CALCULATING: begin
            if (iter_cnt < 16) begin
                if (y[31] == 0) begin
                    x = x + (y >> iter_cnt);
                    y = y - (x >> iter_cnt);
                    angle_reg = angle_reg + theta_i_values[iter_cnt];
                end else begin
                    x = x - (y >> iter_cnt);
                    y = y + (x >> iter_cnt);
                    angle_reg = angle_reg - theta_i_values[iter_cnt];
                end
                iter_cnt = iter_cnt + 1;
                next_state = CALCULATING;
            end else begin
                next_state = DONE;
                done = 1'b1;
                if (a == 0 && b > 0) begin
                    angle_reg = 32'h0001921F;
                end
            end
        end
        DONE: begin
            if (!rst_n) begin
                done = 1'b0;
            end
        end
    endcase
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        x <= 32'd0;
        y <= 32'd0;
        angle_reg <= 32'd0;
        iter_cnt <= 4'd0;
        done <= 1'b0;
        angle <= 32'd0;
    end else begin
        state <= next_state;
        angle <= angle_reg;
        if (state == IDLE && start) begin
            x <= a << 16;
            y <= b << 16;
            angle_reg <= 32'd0;
            iter_cnt <= 4'd0;
            next_state <= CALCULATING;
        end
        if (state == CALCULATING && iter_cnt < 16) begin
            if (y[31] == 0) begin
                x <= x + (y >> iter_cnt);
                y <= y - (x >> iter_cnt);
                angle_reg <= angle_reg + theta_i_values[iter_cnt];
            end else begin
                x <= x - (y >> iter_cnt);
                y <= y + (x >> iter_cnt);
                angle_reg <= angle_reg - theta_i_values[iter_cnt];
            end
            iter_cnt <= iter_cnt + 1;
        end
    end
end

endmodule