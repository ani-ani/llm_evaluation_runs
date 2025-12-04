module max_length_element (
    input reg [7:0] element0_0, element0_1, element0_2, element0_3,
    input reg [7:0] element1_0, element1_1, element1_2, element1_3,
    input reg [7:0] element2_0, element2_1, element2_2, element2_3,
    input reg [7:0] element3_0, element3_1, element3_2, element3_3,
    input reg [3:0] valid_mask0, valid_mask1, valid_mask2, valid_mask3,
    output logic [1:0] max_index,
    output logic [2:0] max_length
);

    logic [2:0] count0, count1, count2, count3;
    logic [2:0] internal_max;

    assign count0 = $countones(valid_mask0);
    assign count1 = $countones(valid_mask1);
    assign count2 = $countones(valid_mask2);
    assign count3 = $countones(valid_mask3);

    assign internal_max = (count0 >= count1 && count0 >= count2 && count0 >= count3) ? count0 :
                          (count1 >= count2 && count1 >= count3) ? count1 :
                          (count2 >= count3) ? count2 :
                          count3;

    assign max_index = (count0 == internal_max) ? 2'b00 :
                       (count1 == internal_max) ? 2'b01 :
                       (count2 == internal_max) ? 2'b10 :
                       2'b11;

    assign max_length = internal_max;

endmodule