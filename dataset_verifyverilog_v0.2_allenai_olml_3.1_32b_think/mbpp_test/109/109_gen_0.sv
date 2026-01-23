module odd_equivalent (
    input clk,
    input rst_n,
    input start,
    input [7:0] s,
    input [3:0] n,
    output reg [3:0] result,
    output reg done
);

reg [3:0] cycle_count;
reg [3:0] n_capture;
reg [7:0] s_capture;
reg start_triggered;

always_ff @(posedge clk) begin
    if (!rst_n) begin
        result <= 4'b0;
        done <= 1'b0;
        start_triggered <= 1'b0;
        s_capture <= 8'b0;
        n_capture <= 4'b0;
        cycle_count <= 4'b0;
    end else begin
        if (start) begin
            if (!start_triggered) begin
                s_capture <= s;
                n_capture <= n;
                start_triggered <= 1'b1;
            end
        end

        if (start_triggered) begin
            if (cycle_count < 10) begin
                if (cycle_count < n_capture) begin
                    [7:0] rotated = (s_capture << cycle_count) | (s_capture >> (8 - cycle_count));
                    rotated = rotated & 8'hFF;
                    if (^{rotated[7], rotated[6], rotated[5], rotated[4], rotated[3], rotated[2], rotated[1], rotated[0]}) begin
                        result <= result + 1;
                    end
                end
                cycle_count <= cycle_count + 1;
            end else begin
                done <= 1'b1;
            end
        end
    end
end

endmodule