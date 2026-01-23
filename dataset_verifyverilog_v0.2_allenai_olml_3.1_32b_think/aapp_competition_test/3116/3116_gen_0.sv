module min_cylinder_volume (
    input clk,
    input rst_n,
    input start,
    input [4:0] num_points,
    input [63:0] points [0:7],
    output reg [63:0] min_volume,
    output reg done
);

    reg [7:0] state;
    reg [7:0] i, j, k;
    reg [31:0] min_volume_reg;
    reg done_reg;

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            state <= 8'd0;
            i <= 8'd0;
            j <= 8'd0;
            k <= 8'd0;
            min_volume_reg <= 32'd0xFFFFFFFF;
            done_reg <= 1'b0;
        end else begin
            state <= state;
            done_reg <= done;
            if (state == 8'd0) begin
                if (start) state <= 8'd1;
            end else if (state == 8'd1) begin
                min_volume_reg <= 32'd0xFFFFFFFF;
                state <= 8'd2;
            end else if (state == 8'd2) begin
                if (i < num_points - 2) begin
                    i <= i + 1;
                    j <= i + 1;
                    k <= j + 1;
                    state <= 8'd3;
                end else begin
                    state <= 8'd7;
                    done_reg <= 1'b1;
                end
            end else if (state == 8'd3) begin
                if (j < num_points - 1) begin
                    k <= j + 1;
                    state <= 8'd4;
                end else begin
                    i <= i + 1;
                    j <= i + 1;
                    k <= j + 1;
                    state <= 8'd3;
                end
            end else if (state == 8'd4) begin
                if (k < num_points) begin
                    state <= 8'd5;
                end else begin
                    j <= j + 1;
                    k <= j + 1;
                    state <= 8'd3;
                end
            end else if (state == 8'd5) begin
                state <= 8'd6;
            end else if (state == 8'd6) begin
                state <= 8'd4;
            end
        end
    end

    assign min_volume = {32'b0, min_volume_reg};
    assign done = done_reg;

endmodule