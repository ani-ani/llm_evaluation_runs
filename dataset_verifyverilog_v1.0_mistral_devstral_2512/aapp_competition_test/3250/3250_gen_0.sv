module divisibility_hack_checker(
    input [3:0] b,
    input [3:0] d,
    output reg yes_no
);
    
    always @(*) begin
        case (d)
            4'd2:  yes_no = (b[0] == 1'b0);
            4'd3:  yes_no = (b[0] == b[1]);
            4'd5:  yes_no = (b[0] == 1'b0);
            4'd7:  yes_no = (b[0] == b[1] == b[2]);
            4'd11: yes_no = (b[0] == b[1] == b[3]);
            4'd13: yes_no = (b[0] == b[1] == b[2] == b[3]);
            default: yes_no = 1'b0;
        endcase
    end
    
endmodule