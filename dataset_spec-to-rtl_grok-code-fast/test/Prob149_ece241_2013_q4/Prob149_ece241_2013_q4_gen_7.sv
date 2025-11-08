module TopModule(
    input clk,
    input reset,
    input [2:0] s,
    output fr2,
    output fr1,
    output fr0,
    output dfr
);

    reg [2:0] prev_s;
    reg dfr_reg;
    assign dfr = dfr_reg;

    always_ff @(posedge clk) begin
        if (reset) begin
            prev_s <= 3'b0;
            dfr_reg <= 1'b1;
        end else begin
            prev_s <= s;
            if (s != prev_s) begin
                int new_level = s[0] ? (s[1] ? (s[2] ? 3 : 2) : 1) : 0;
                int prev_level = prev_s[0] ? (prev_s[1] ? (prev_s[2] ? 3 : 2) : 1) : 0;
                dfr_reg <= (new_level > prev_level);
            end
        end
    end

    wire [1:0] level;
    assign level = s[0] ? (s[1] ? (s[2] ? 2'd3 : 2'd2) : 2'd1) : 2'd0;
    assign fr0 = 1'b0;
    assign fr1 = 1'b0;
    assign fr2 = 1'b0;
    // Wait, mistake, fr follow the levels
    assign fr0 = 1'b1; // level <= 3 always? No
    assign fr0 = (level == 0 || level == 1 || level == 2);
    assign fr1 = (level == 0 || level == 1);
    assign fr2 = (level == 0);

endmodule