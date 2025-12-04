module toggle_case(
    input  [63:0] str_in,
    output [63:0] str_out
);

    wire [7:0] c0 = str_in[63:56];
    wire [7:0] c1 = str_in[55:48];
    wire [7:0] c2 = str_in[47:40];
    wire [7:0] c3 = str_in[39:32];
    wire [7:0] c4 = str_in[31:24];
    wire [7:0] c5 = str_in[23:16];
    wire [7:0] c6 = str_in[15:8];
    wire [7:0] c7 = str_in[7:0];

    function automatic [7:0] toggle_char(input [7:0] ch);
        begin
            if (ch >= 8'd65 && ch <= 8'd90)
                toggle_char = ch + 8'd32;
            else if (ch >= 8'd97 && ch <= 8'd122)
                toggle_char = ch - 8'd32;
            else
                toggle_char = ch;
        end
    endfunction

    assign str_out = { toggle_char(c0),
                       toggle_char(c1),
                       toggle_char(c2),
                       toggle_char(c3),
                       toggle_char(c4),
                       toggle_char(c5),
                       toggle_char(c6),
                       toggle_char(c7) };

endmodule