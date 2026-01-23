module planet_orbits ( input [63:0] planet1, input [63:0] planet2, output reg [7:0] result_valid, output reg [2:0] result_count, output reg invalid );
parameter vector mercury = {8'h4d, 8'h65, 8'h72, 8'h63, 8'h75, 8'h72, 8'h79, 8'h20};
parameter vector venus = {8'h56, 8'h65, 8'h6e, 8'h75, 8'h73, 8'h20, 8'h20, 8'h20};
parameter vector earth = {8'h45, 8'h61, 8'h72, 8'h74, 8'h68, 8'h20, 8'h20, 8'h20};
parameter vector mars = {8'h4d, 8'h61, 8'h72, 8'h73, 8'h20, 8'h20, 8'h20, 8'h20};
parameter vector jupiter = {8'h4a, 8'h75, 8'h70, 8'h69, 8'h74, 8'h65, 8'h72, 8'h20};
parameter vector saturn = {8'h53, 8'h61, 8'h74, 8'h75, 8'h72, 8'h6e, 8'h20, 8'h20};
parameter vector uranus = {8'h55, 8'h72, 8'h61, 8'h6e, 8'h75, 8'h73, 8'h20, 8'h20};
parameter vector neptune = {8'h4e, 8'h65, 8'h70, 8'h74, 8'h75, 8'h6e, 8'h65, 8'h20};
always @(*) begin
    reg [2:0] index1, index2;
    reg invalid_p1, invalid_p2;
    invalid_p1 = 1'b1;
    invalid_p2 = 1'b1;
    index1 = 3'b111;
    index2 = 3'b111;

    // Check planet1
    if (planet1 == mercury) begin
        index1 = 3'b000;
        invalid_p1 = 1'b0;
    end else if (planet1 == venus) begin
        index1 = 3'b001;
        invalid_p1 = 1'b0;
    end else if (planet1 == earth) begin
        index1 = 3'b010;
        invalid_p1 = 1'b0;
    end else if (planet1 == mars) begin
        index1 = 3'b011;
        invalid_p1 = 1'b0;
    end else if (planet1 == jupiter) begin
        index1 = 3'b100;
        invalid_p1 = 1'b0;
    end else if (planet1 == saturn) begin
        index1 = 3'b101;
        invalid_p1 = 1'b0;
    end else if (planet1 == uranus) begin
        index1 = 3'b110;
        invalid_p1 = 1'b0;
    end else if (planet1 == neptune) begin
        index1 = 3'b111;
        invalid_p1 = 1'b0;
    end

    // Check planet2
    if (planet2 == mercury) begin
        index2 = 3'b000;
        invalid_p2 = 1'b0;
    end else if (planet2 == venus) begin
        index2 = 3'b001;
        invalid_p2 = 1'b0;
    end else if (planet2 == earth) begin
        index2 = 3'b010;
        invalid_p2 = 1'b0;
    end else if (planet2 == mars) begin
        index2 = 3'b011;
        invalid_p2 = 1'b0;
    end else if (planet2 == jupiter) begin
        index2 = 3'b100;
        invalid_p2 = 1'b0;
    end else if (planet2 == saturn) begin
        index2 = 3'b101;
        invalid_p2 = 1'b0;
    end else if (planet2 == uranus) begin
        index2 = 3'b110;
        invalid_p2 = 1'b0;
    end else if (planet2 == neptune) begin
        index2 = 3'b111;
        invalid_p2 = 1'b0;
    end

    invalid = invalid_p1 | invalid_p2;

    if (invalid) begin
        result_valid = 8'b0;
        result_count = 3'b0;
    end else begin
        if (index1 == index2) begin
            result_valid = 8'b0;
            result_count = 3'b0;
        end else begin
            reg [2:0] min_idx, max_idx;
            min_idx = (index1 < index2) ? index1 : index2;
            max_idx = (index1 > index2) ? index1 : index2;

            result_valid[0] = 0;
            result_valid[1] = (1 > min_idx) && (1 < max_idx);
            result_valid[2] = (2 > min_idx) && (2 < max_idx);
            result_valid[3] = (3 > min_idx) && (3 < max_idx);
            result_valid[4] = (4 > min_idx) && (4 < max_idx);
            result_valid[5] = (5 > min_idx) && (5 < max_idx);
            result_valid[6] = (6 > min_idx) && (6 < max_idx);
            result_valid[7] = 0;

            result_count = 0;
            if (result_valid[1]) result_count = result_count + 1;
            if (result_valid[2]) result_count = result_count + 1;
            if (result_valid[3]) result_count = result_count + 1;
            if (result_valid[4]) result_count = result_count + 1;
            if (result_valid[5]) result_count = result_count + 1;
            if (result_valid[6]) result_count = result_count + 1;
        end
    end
end
endmodule