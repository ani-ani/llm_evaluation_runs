module sorted_list_checker (
    input reg [3:0] length,
    input reg [63:0] lst,
    output reg is_sorted
);

always_comb begin
    case (length)
        4'd0, 4'd1: is_sorted = 1;
        4'd2: is_sorted = (lst[7:0] <= lst[15:8]);
        4'd3: begin
            is_sorted = (lst[7:0] <= lst[15:8]) && (lst[15:8] <= lst[23:16]) && !( (lst[7:0] == lst[15:8]) && (lst[15:8] == lst[23:16]) );
        end
        4'd4: begin
            is_sorted = (lst[7:0] <= lst[15:8]) && (lst[15:8] <= lst[23:16]) && (lst[23:16] <= lst[31:24]) && !( (lst[7:0] == lst[15:8]) && (lst[15:8] == lst[23:16]) ) && !( (lst[15:8] == lst[23:16]) && (lst[23:16] == lst[31:24]) );
        end
        4'd5: begin
            is_sorted = (lst[7:0] <= lst[15:8]) && (lst[15:8] <= lst[23:16]) && (lst[23:16] <= lst[31:24]) && (lst[31:24] <= lst[39:32]) && !( (lst[7:0] == lst[15:8]) && (lst[15:8] == lst[23:16]) ) && !( (lst[15:8] == lst[23:16]) && (lst[23:16] == lst[31:24]) ) && !( (lst[23:16] == lst[31:24]) && (lst[31:24] == lst[39:32]) );
        end
        4'd6: begin
            is_sorted = (lst[7:0] <= lst[15:8]) && (lst[15:8] <= lst[23:16]) && (lst[23:16] <= lst[31:24]) && (lst[31:24] <= lst[39:32]) && (lst[39:32] <= lst[47:40]) && !( (lst[7:0] == lst[15:8]) && (lst[15:8] == lst[23:16]) ) && !( (lst[15:8] == lst[23:16]) && (lst[23:16] == lst[31:24]) ) && !( (lst[23:16] == lst[31:24]) && (lst[31:24] == lst[39:32]) ) && !( (lst[31:24] == lst[39:32]) && (lst[39:32] == lst[47:40]) );
        end
        4'd7: begin
            is_sorted = (lst[7:0] <= lst[15:8]) && (lst[15:8] <= lst[23:16]) && (lst[23:16] <= lst[31:24]) && (lst[31:24] <= lst[39:32]) && (lst[39:32] <= lst[47:40]) && (lst[47:40] <= lst[55:48]) && !( (lst[7:0] == lst[15:8]) && (lst[15:8] == lst[23:16]) ) && !( (lst[15:8] == lst[23:16]) && (lst[23:16] == lst[31:24]) ) && !( (lst[23:16] == lst[31:24]) && (lst[31:24] == lst[39:32]) ) && !( (lst[31:24] == lst[39:32]) && (lst[39:32] == lst[47:40]) ) && !( (lst[39:32] == lst[47:40]) && (lst[47:40] == lst[55:48]) );
        end
        4'd8: begin
            is_sorted = (lst[7:0] <= lst[15:8]) && (lst[15:8] <= lst[23:16]) && (lst[23:16] <= lst[31:24]) && (lst[31:24] <= lst[39:32]) && (lst[39:32] <= lst[47:40]) && (lst[47:40] <= lst[55:48]) && (lst[55:48] <= lst[63:56]) && !( (lst[7:0] == lst[15:8]) && (lst[15:8] == lst[23:16]) ) && !( (lst[15:8] == lst[23:16]) && (lst[23:16] == lst[31:24]) ) && !( (lst[23:16] == lst[31:24]) && (lst[31:24] == lst[39:32]) ) && !( (lst[31:24] == lst[39:32]) && (lst[39:32] == lst[47:40]) ) && !( (lst[39:32] == lst[47:40]) && (lst[47:40] == lst[55:48]) ) && !( (lst[47:40] == lst[55:48]) && (lst[55:48] == lst[63:56]) );
        end
    endcase
end

endmodule