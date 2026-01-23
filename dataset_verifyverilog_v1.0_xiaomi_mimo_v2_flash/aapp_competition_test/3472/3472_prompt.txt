module warlords_add_lines (
    input [7:0] type_in,      // bit i: 0=horizontal, 1=vertical
    input [7:0] coord_in [7:0], // coordinate for each line (8 lines, 8-bit each)
    input [7:0] valid_in,     // valid mask for lines
    input [3:0] warlords,     // number of warlords (1-8)
    output reg [3:0] result,
    output reg done           // always 1 (combinational output valid)
);

    // Internal variables for counting distinct lines
    reg [3:0] h_count, v_count;
    integer i, j;
    reg is_first_h, is_first_v;
    wire [3:0] n;
    wire [3:0] I;

    // Count distinct horizontal and vertical lines
    always @(*) begin
        h_count = 0;
        v_count = 0;
        for (i = 0; i < 8; i = i + 1) begin
            if (valid_in[i]) begin
                if (type_in[i] == 1'b0) begin
                    // horizontal line
                    is_first_h = 1'b1;
                    for (j = 0; j < i; j = j + 1) begin
                        if (valid_in[j] && type_in[j] == 1'b0 && coord_in[j] == coord_in[i]) begin
                            is_first_h = 1'b0;
                        end
                    end
                    if (is_first_h) h_count = h_count + 1;
                end else begin
                    // vertical line
                    is_first_v = 1'b1;
                    for (j = 0; j < i; j = j + 1) begin
                        if (valid_in[j] && type_in[j] == 1'b1 && coord_in[j] == coord_in[i]) begin
                            is_first_v = 1'b0;
                        end
                    end
                    if (is_first_v) v_count = v_count + 1;
                end
            end
        end
    end

    assign n = h_count + v_count;

    // Compute I (number of infinite sectors)
    assign I = (h_count > 0 && v_count > 0) ? (h_count + v_count) * 2 :
               (h_count > 0) ? h_count + 1 :
               (v_count > 0) ? v_count + 1 : 1;

    // Compute result
    always @(*) begin
        done = 1'b1; // combinational output always valid
        if (I >= warlords) begin
            result = 0;
        end else begin
            if (n == 0) begin
                // No lines: need ceil(warlords / 2)
                result = (warlords + 1) >> 1;
            end else begin
                // Each added line adds 2 infinite sectors
                result = (warlords - I + 1) >> 1;
            end
        end
    end

endmodule