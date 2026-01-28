module rear_extract(
    input [7:0] tuple_0_elem_0,
    input [7:0] tuple_0_elem_1,
    input [7:0] tuple_0_elem_2,
    input [7:0] tuple_1_elem_0,
    input [7:0] tuple_1_elem_1,
    input [7:0] tuple_1_elem_2,
    input [7:0] tuple_2_elem_0,
    input [7:0] tuple_2_elem_1,
    input [7:0] tuple_2_elem_2,
    
    output reg [7:0] rear_0,
    output reg [7:0] rear_1,
    output reg [7:0] rear_2
);
    always @(*) begin
        rear_0 = tuple_0_elem_2;
        rear_1 = tuple_1_elem_2;
        rear_2 = tuple_2_elem_2;
    end
endmodule