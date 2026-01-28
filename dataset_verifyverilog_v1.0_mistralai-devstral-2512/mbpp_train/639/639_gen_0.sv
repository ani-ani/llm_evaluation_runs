module name_filter(
    input [7:0] names [0:5][7:0],
    input [3:0] len,
    output reg [15:0] result,
    output reg done
);

    integer i, j;
    reg [15:0] total;
    reg [7:0] current_char;
    reg [3:0] name_length;
    reg valid_name;

    always @(*) begin
        total = 16'd0;
        done = 1'b1;

        for (i = 0; i < len; i = i + 1) begin
            valid_name = 1'b1;
            name_length = 4'd0;

            // Check first character is uppercase (A-Z)
            current_char = names[i][0];
            if (current_char < 8'd65 || current_char > 8'd90) begin
                valid_name = 1'b0;
            end

            // Check remaining characters are lowercase or null
            if (valid_name) begin
                for (j = 1; j < 8; j = j + 1) begin
                    current_char = names[i][j];
                    if (current_char == 8'd0) begin
                        // Null terminator found, stop counting
                        break;
                    end else if (current_char < 8'd97 || current_char > 8'd122) begin
                        valid_name = 1'b0;
                    end else begin
                        name_length = name_length + 4'd1;
                    end
                end

                // Count first character if valid
                if (valid_name) begin
                    name_length = name_length + 4'd1;
                    total = total + name_length;
                end
            end
        end

        result = total;
    end
endmodule