module camera_coverage (
    input clk,
    input rst_n,
    input start,
    input [2:0] n,
    input [2:0] k,
    input [7:0] a_i [0:7],
    input [7:0] b_i [0:7],
    output reg [3:0] result,
    output reg done,
    output reg impossible
);

    reg [2:0] state;
    reg [2:0] n_reg;
    reg [2:0] k_reg;
    reg [7:0] a_reg [0:7];
    reg [7:0] b_reg [0:7];
    reg [7:0] camera_masks [0:7];
    reg [7:0] subset_counter;
    reg [2:0] min_cameras;
    reg found;
    reg [3:0] result_reg;
    reg done_reg;
    reg impossible_reg;

    initial begin
        state <= 3'd0;
        n_reg <= 3'd0;
        k_reg <= 3'd0;
        a_reg <= 8'd0;
        b_reg <= 8'd0;
        camera_masks <= 8'd0;
        subset_counter <= 8'd0;
        min_cameras <= 3'd0;
        found <= 1'b0;
        done_reg <= 1'b0;
        impossible_reg <= 1'b0;
        result_reg <= 4'd0;
    end

    function automatic [7:0] compute_mask;
        input [7:0] a, b;
        input [2:0] n;
        reg [7:0] mask;
        if (a <= b) begin
            if (b > n) begin
                if (a > n) begin
                    mask = 8'd0;
                end else begin
                    reg [3:0] len = n - a + 1;
                    mask = ((1 << len) - 1) << (a - 1);
                end
            end else begin
                if (a > b) begin
                    mask = 8'd0;
                end else begin
                    reg [3:0] len = b - a + 1;
                    mask = ((1 << len) - 1) << (a - 1);
                end
            end
        end else begin
            if (a > n) begin
                if (b >= 1) begin
                    mask = (1 << b) - 1;
                end else begin
                    mask = 8'd0;
                end
            end else begin
                reg [3:0] len1 = n - a + 1;
                reg [7:0] mask1 = ((1 << len1) - 1) << (a - 1);
                if (b >= 1) begin
                    reg [3:0] len2 = b;
                    reg [7:0] mask2 = (1 << len2) - 1;
                    mask = mask1 | mask2;
                end else begin
                    mask = mask1;
                end
            end
        end
        return mask;
    endfunction

    always @(posedge clk or !rst_n) begin
        if (!rst_n) begin
            state <= 3'd0;
            n_reg <= 3'd0;
            k_reg <= 3'd0;
            a_reg[0] <= 8'd0;
            b_reg[0] <= 8'd0;
            a_reg[1] <= 8'd0;
            b_reg[1] <= 8'd0;
            a_reg[2] <= 8'd0;
            b_reg[2] <= 8'd0;
            a_reg[3] <= 8'd0;
            b_reg[3] <= 8'd0;
            a_reg[4] <= 8'd0;
            b_reg[4] <= 8'd0;
            a_reg[5] <= 8'd0;
            b_reg[5] <= 8'd0;
            a_reg[6] <= 8'd0;
            b_reg[6] <= 8'd0;
            a_reg[7] <= 8'd0;
            b_reg[7] <= 8'd0;
            camera_masks[0] <= 8'd0;
            camera_masks[1] <= 8'd0;
            camera_masks[2] <= 8'd0;
            camera_masks[3] <= 8'd0;
            camera_masks[4] <= 8'd0;
            camera_masks[5] <= 8'd0;
            camera_masks[6] <= 8'd0;
            camera_masks[7] <= 8'd0;
            subset_counter <= 8'd0;
            min_cameras <= 3'd0;
            found <= 1'b0;
            done_reg <= 1'b0;
            impossible_reg <= 1'b0;
            result_reg <= 4'd0;
        end else begin
            case(state)
                3'd0: begin
                    if (start == 1) state <= 3'd1;
                    done_reg <= 1'b0;
                    impossible_reg <= 1'b0;
                    result_reg <= 4'd0;
                end
                3'd1: begin
                    n_reg <= n;
                    k_reg <= k;
                    a_reg[0] <= a_i[0];
                    b_reg[0] <= b_i[0];
                    if (k_reg > 1) a_reg[1] <= a_i[1] else a_reg[1] <= 8'd0;
                    if (k_reg > 1) b_reg[1] <= b_i[1] else b_reg[1] <= 8'd0;
                    if (k_reg > 2) a_reg[2] <= a_i[2] else a_reg[2] <= 8'd0;
                    if (k_reg > 2) b_reg[2] <= b_i[2] else b_reg[2] <= 8'd0;
                    if (k_reg > 3) a_reg[3] <= a_i[3] else a_reg[3] <= 8'd0;
                    if (k_reg > 3) b_reg[3] <= b_i[3] else b_reg[3] <= 8'd0;
                    if (k_reg > 4) a_reg[4] <= a_i[4] else a_reg[4] <= 8'd0;
                    if (k_reg > 4) b_reg[4] <= b_i[4] else b_reg[4] <= 8'd0;
                    if (k_reg > 5) a_reg[5] <= a_i[5] else a_reg[5] <= 8'd0;
                    if (k_reg > 5) b_reg[5] <= b_i[5] else b_reg[5] <= 8'd0;
                    if (k_reg > 6) a_reg[6] <= a_i[6] else a_reg[6] <= 8'd0;
                    if (k_reg > 6) b_reg[6] <= b_i[6] else b_reg[6] <= 8'd0;
                    if (k_reg > 7) a_reg[7] <= a_i[7] else a_reg[7] <= 8'd0;
                    if (k_reg > 7) b_reg[7] <= b_i[7] else b_reg[7] <= 8'd0;
                    camera_masks[0] = compute_mask(a_reg[0], b_reg[0], n_reg);
                    if (k_reg > 1) camera_masks[1] = compute_mask(a_reg[1], b_reg[1], n_reg);
                    if (k_reg > 2) camera_masks[2] = compute_mask(a_reg[2], b_reg[2], n_reg);
                    if (k_reg > 3) camera_masks[3] = compute_mask(a_reg[3], b_reg[3], n_reg);
                    if (k_reg > 4) camera_masks[4] = compute_mask(a_reg[4], b_reg[4], n_reg);
                    if (k_reg > 5) camera_masks[5] = compute_mask(a_reg[5], b_reg[5], n_reg);
                    if (k_reg > 6) camera_masks[6] = compute_mask(a_reg[6], b_reg[6], n_reg);
                    if (k_reg > 7) camera_masks[7] = compute_mask(a_reg[7], b_reg[7], n_reg);
                    state <= 3'd2;
                end
                3'd2: begin
                    if (subset_counter < (1 << k_reg)) begin
                        reg [2:0] cnt;
                        cnt = 0;
                        if (subset_counter & 1) cnt = cnt + 1;
                        if (subset_counter & 2) cnt = cnt + 1;
                        if (subset_counter & 4) cnt = cnt + 1;
                        if (subset_counter & 8) cnt = cnt + 1;
                        if (subset_counter & 16) cnt = cnt + 1;
                        if (subset_counter & 32) cnt = cnt + 1;
                        if (subset_counter & 64) cnt = cnt + 1;
                        if (subset_counter & 128) cnt = cnt + 1;
                        if (cnt >= min_cameras) begin
                            subset_counter <= subset_counter + 1;
                        end else begin
                            reg [7:0] current_or;
                            current_or = 0;
                            if (subset_counter & 1 && k_reg > 0) current_or |= camera_masks[0];
                            if (subset_counter & 2 && k_reg > 1) current_or |= camera_masks[1];
                            if (subset_counter & 4 && k_reg > 2) current_or |= camera_masks[2];
                            if (subset_counter & 8 && k_reg > 3) current_or |= camera_masks[3];
                            if (subset_counter & 16 && k_reg > 4) current_or |= camera_masks[4];
                            if (subset_counter & 32 && k_reg > 5) current_or |= camera_masks[5];
                            if (subset_counter & 64 && k_reg > 6) current_or |= camera_masks[6];
                            if (subset_counter & 128 && k_reg > 7) current_or |= camera_masks[7];
                            if (current_or & ((1 << n_reg) - 1) == (1 << n_reg) - 1) begin
                                if (cnt < min_cameras) begin
                                    min_cameras <= cnt;
                                    found <= 1;
                                end
                            end
                        end
                        subset_counter <= subset_counter + 1;
                    end else begin
                        if (found) begin
                            state <= 3'd3;
                            result_reg <= min_cameras;
                            impossible_reg <= 1'b0;
                        end else begin
                            state <= 3'd3;
                            impossible_reg <= 1'b1;
                            result_reg <= 4'd0;
                        end
                        done_reg <= 1'b1;
                    end
                end
                3'd3: begin
                    done_reg <= 1'b1;
                    result_reg <= result_reg;
                    impossible_reg <= impossible_reg;
                end
            endcase

            result = result_reg;
            done = done_reg;
            impossible = impossible_reg;
        end
    end

endmodule