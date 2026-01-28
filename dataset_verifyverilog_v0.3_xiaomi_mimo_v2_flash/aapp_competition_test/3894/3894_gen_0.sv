module LiegesOfLegendre (
    input [7:0] arr_0,
    input [7:0] arr_1,
    input [7:0] arr_2,
    input [7:0] arr_3,
    input [7:0] arr_4,
    input [7:0] arr_5,
    input [7:0] arr_6,
    input [7:0] arr_7,
    input [7:0] k,
    output winner
);

// Internal signals for Grundy numbers
wire [1:0] g0, g1, g2, g3, g4, g5, g6, g7;
wire [1:0] xor_result;

// Grundy units for each pile
grundy_unit gu0(.pile(arr_0), .k(k), .grundy(g0));
grundy_unit gu1(.pile(arr_1), .k(k), .grundy(g1));
grundy_unit gu2(.pile(arr_2), .k(k), .grundy(g2));
grundy_unit gu3(.pile(arr_3), .k(k), .grundy(g3));
grundy_unit gu4(.pile(arr_4), .k(k), .grundy(g4));
grundy_unit gu5(.pile(arr_5), .k(k), .grundy(g5));
grundy_unit gu6(.pile(arr_6), .k(k), .grundy(g6));
grundy_unit gu7(.pile(arr_7), .k(k), .grundy(g7));

// XOR all grundy values
assign xor_result = ((((((g0 ^ g1) ^ g2) ^ g3) ^ g4) ^ g5) ^ g6) ^ g7;

// Winner if XOR non-zero
assign winner = (xor_result != 2'd0);

endmodule

module grundy_unit (
    input [7:0] pile,
    input [7:0] k,
    output [1:0] grundy
);

wire k_odd = k[0];

// Count trailing zeros (d) - Priority encoder
reg [2:0] d;
always @(*) begin
    casez (pile[7:0])
        8'b???????1: d = 3'd0;
        8'b??????10: d = 3'd1;
        8'b?????100: d = 3'd2;
        8'b????1000: d = 3'd3;
        8'b???10000: d = 3'd4;
        8'b??100000: d = 3'd5;
        8'b?1000000: d = 3'd6;
        8'b10000000: d = 3'd7;
        default: d = 3'd0;
    endcase
end

// Compute 3 << d using 9-bit (max 3<<7 = 384 < 512)
wire [8:0] three_shl_d;
assign three_shl_d = 9'd3 << d;

// Check if pile equals 3 * 2^d
wire is_3times_power_of_2;
assign is_3times_power_of_2 = (three_shl_d[8] == 1'b0) && (pile == three_shl_d[7:0]);

// Condition: (pile == 3<<d) ^ (d[0])
wire cond;
assign cond = is_3times_power_of_2 ^ d[0];

// k even case (y)
wire [1:0] g_even;
assign g_even = (pile < 8'd3) ? pile[1:0] : {1'b0, pile[0] ^ 1'b1};

// k odd case (x)
wire [1:0] g_odd;
assign g_odd = (pile < 8'd4) ? pile[1:0] :
               (pile[0] == 1'b1) ? 2'd0 :
               (cond) ? 2'd1 : 2'd2;

// Select based on k parity
assign grundy = k_odd ? g_odd : g_even;

endmodule