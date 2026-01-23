module sublist_checker(input [7:0] main_list [0:7], input [7:0] sub_list [0:3], input [2:0] sub_len, output reg is_sublist);
assign is_sublist = 1'b0;
always @(*) begin
    if (sub_len == 0) begin
        is_sublist = 1'b1;
    end else if (sub_len > 8) begin
        is_sublist = 1'b0;
    end else begin
        case (sub_len)
            1: begin
                is_sublist = (main_list[0] == sub_list[0]) | (main_list[1] == sub_list[0]) | (main_list[2] == sub_list[0]) | (main_list[3] == sub_list[0]) | (main_list[4] == sub_list[0]) | (main_list[5] == sub_list[0]) | (main_list[6] == sub_list[0]) | (main_list[7] == sub_list[0]);
            end
            2: begin
                is_sublist = (main_list[0] == sub_list[0] && main_list[1] == sub_list[1]) | (main_list[1] == sub_list[0] && main_list[2] == sub_list[1]) | (main_list[2] == sub_list[0] && main_list[3] == sub_list[1]) | (main_list[3] == sub_list[0] && main_list[4] == sub_list[1]) | (main_list[4] == sub_list[0] && main_list[5] == sub_list[1]) | (main_list[5] == sub_list[0] && main_list[6] == sub_list[1]) | (main_list[6] == sub_list[0] && main_list[7] == sub_list[1]);
            end
            3: begin
                is_sublist = (main_list[0] == sub_list[0] && main_list[1] == sub_list[1] && main_list[2] == sub_list[2]) | (main_list[1] == sub_list[0] && main_list[2] == sub_list[1] && main_list[3] == sub_list[2]) | (main_list[2] == sub_list[0] && main_list[3] == sub_list[1] && main_list[4] == sub_list[2]) | (main_list[3] == sub_list[0] && main_list[4] == sub_list[1] && main_list[5] == sub_list[2]) | (main_list[4] == sub_list[0] && main_list[5] == sub_list[1] && main_list[6] == sub_list[2]) | (main_list[5] == sub_list[0] && main_list[6] == sub_list[1] && main_list[7] == sub_list[2]);
            end
            4: begin
                is_sublist = (main_list[0] == sub_list[0] && main_list[1] == sub_list[1] && main_list[2] == sub_list[2] && main_list[3] == sub_list[3]) | (main_list[1] == sub_list[0] && main_list[2] == sub_list[1] && main_list[3] == sub_list[2] && main_list[4] == sub_list[3]) | (main_list[2] == sub_list[0] && main_list[3] == sub_list[1] && main_list[4] == sub_list[2] && main_list[5] == sub_list[3]) | (main_list[3] == sub_list[0] && main_list[4] == sub_list[1] && main_list[5] == sub_list[2] && main_list[6] == sub_list[3]) | (main_list[4] == sub_list[0] && main_list[5] == sub_list[1] && main_list[6] == sub_list[2] && main_list[7] == sub_list[3]);
            end
        endcase
    end
end
endmodule