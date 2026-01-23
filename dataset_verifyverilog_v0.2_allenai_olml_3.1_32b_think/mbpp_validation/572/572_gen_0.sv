module remove_duplicates (
    input [7:0] data_in_0, input [7:0] data_in_1, input [7:0] data_in_2, input [7:0] data_in_3, input [7:0] data_in_4, input [7:0] data_in_5, input [7:0] data_in_6, input [7:0] data_in_7,
    input [2:0] valid_count,
    output [7:0] unique_0, output [7:0] unique_1, output [7:0] unique_2, output [7:0] unique_3, output [7:0] unique_4, output [7:0] unique_5, output [7:0] unique_6, output [7:0] unique_7,
    output [3:0] unique_count
);

wire active_0, active_1, active_2, active_3, active_4, active_5, active_6, active_7;
wire conflict_0, conflict_1, conflict_2, conflict_3, conflict_4, conflict_5, conflict_6, conflict_7;
wire temp_unique_0, temp_unique_1, temp_unique_2, temp_unique_3, temp_unique_4, temp_unique_5, temp_unique_6, temp_unique_7;
wire [2:0] rank_0, rank_1, rank_2, rank_3, rank_4, rank_5, rank_6, rank_7;
wire [7:0] selected_0, selected_1, selected_2, selected_3, selected_4, selected_5, selected_6, selected_7;

assign active_0 = (valid_count > 0) ? 1 : 0;
assign active_1 = (valid_count > 1) ? 1 : 0;
assign active_2 = (valid_count > 2) ? 1 : 0;
assign active_3 = (valid_count > 3) ? 1 : 0;
assign active_4 = (valid_count > 4) ? 1 : 0;
assign active_5 = (valid_count > 5) ? 1 : 0;
assign active_6 = (valid_count > 6) ? 1 : 0;
assign active_7 = (valid_count > 7) ? 1 : 0;

assign conflict_0 = (active_1 && (data_in_1 == data_in_0)) || (active_2 && (data_in_2 == data_in_0)) || (active_3 && (data_in_3 == data_in_0)) || (active_4 && (data_in_4 == data_in_0)) || (active_5 && (data_in_5 == data_in_0)) || (active_6 && (data_in_6 == data_in_0)) || (active_7 && (data_in_7 == data_in_0));
assign conflict_1 = (active_0 && (data_in_0 == data_in_1)) || (active_2 && (data_in_2 == data_in_1)) || (active_3 && (data_in_3 == data_in_1)) || (active_4 && (data_in_4 == data_in_1)) || (active_5 && (data_in_5 == data_in_1)) || (active_6 && (data_in_6 == data_in_1)) || (active_7 && (data_in_7 == data_in_1));
assign conflict_2 = (active_0 && (data_in_0 == data_in_2)) || (active_1 && (data_in_1 == data_in_2)) || (active_3 && (data_in_3 == data_in_2)) || (active_4 && (data_in_4 == data_in_2)) || (active_5 && (data_in_5 == data_in_2)) || (active_6 && (data_in_6 == data_in_2)) || (active_7 && (data_in_7 == data_in_2));
assign conflict_3 = (active_0 && (data_in_0 == data_in_3)) || (active_1 && (data_in_1 == data_in_3)) || (active_2 && (data_in_2 == data_in_3)) || (active_4 && (data_in_4 == data_in_3)) || (active_5 && (data_in_5 == data_in_3)) || (active_6 && (data_in_6 == data_in_3)) || (active_7 && (data_in_7 == data_in_3));
assign conflict_4 = (active_0 && (data_in_0 == data_in_4)) || (active_1 && (data_in_1 == data_in_4)) || (active_2 && (data_in_2 == data_in_4)) || (active_3 && (data_in_3 == data_in_4)) || (active_5 && (data_in_5 == data_in_4)) || (active_6 && (data_in_6 == data_in_4)) || (active_7 && (data_in_7 == data_in_4));
assign conflict_5 = (active_0 && (data_in_0 == data_in_5)) || (active_1 && (data_in_1 == data_in_5)) || (active_2 && (data_in_2 == data_in_5)) || (active_3 && (data_in_3 == data_in_5)) || (active_4 && (data_in_4 == data_in_5)) || (active_6 && (data_in_6 == data_in_5)) || (active_7 && (data_in_7 == data_in_5));
assign conflict_6 = (active_0 && (data_in_0 == data_in_6)) || (active_1 && (data_in_1 == data_in_6)) || (active_2 && (data_in_2 == data_in_6)) || (active_3 && (data_in_3 == data_in_6)) || (active_4 && (data_in_4 == data_in_6)) || (active_5 && (data_in_5 == data_in_6)) || (active_7 && (data_in_7 == data_in_6));
assign conflict_7 = (active_0 && (data_in_0 == data_in_7)) || (active_1 && (data_in_1 == data_in_7)) || (active_2 && (data_in_2 == data_in_7)) || (active_3 && (data_in_3 == data_in_7)) || (active_4 && (data_in_4 == data_in_7)) || (active_5 && (data_in_5 == data_in_7)) || (active_6 && (data_in_6 == data_in_7));

assign temp_unique_0 = active_0 & !conflict_0;
assign temp_unique_1 = active_1 & !conflict_1;
assign temp_unique_2 = active_2 & !conflict_2;
assign temp_unique_3 = active_3 & !conflict_3;
assign temp_unique_4 = active_4 & !conflict_4;
assign temp_unique_5 = active_5 & !conflict_5;
assign temp_unique_6 = active_6 & !conflict_6;
assign temp_unique_7 = active_7 & !conflict_7;

assign unique_count = temp_unique_0 + temp_unique_1 + temp_unique_2 + temp_unique_3 + temp_unique_4 + temp_unique_5 + temp_unique_6 + temp_unique_7;

assign rank_0 = 0;
assign rank_1 = rank_0 + temp_unique_0;
assign rank_2 = rank_1 + temp_unique_1;
assign rank_3 = rank_2 + temp_unique_2;
assign rank_4 = rank_3 + temp_unique_3;
assign rank_5 = rank_4 + temp_unique_4;
assign rank_6 = rank_5 + temp_unique_5;
assign rank_7 = rank_6 + temp_unique_6;

assign selected_0 = (temp_unique_0 && (rank_0 == 0)) ? data_in_0 : (temp_unique_1 && (rank_1 == 0)) ? data_in_1 : (temp_unique_2 && (rank_2 == 0)) ? data_in_2 : (temp_unique_3 && (rank_3 == 0)) ? data_in_3 : (temp_unique_4 && (rank_4 == 0)) ? data_in_4 : (temp_unique_5 && (rank_5 == 0)) ? data_in_5 : (temp_unique_6 && (rank_6 == 0)) ? data_in_6 : (temp_unique_7 && (rank_7 == 0)) ? data_in_7 : 8'h00;
assign selected_1 = (temp_unique_0 && (rank_0 == 1)) ? data_in_0 : (temp_unique_1 && (rank_1 == 1)) ? data_in_1 : (temp_unique_2 && (rank_2 == 1)) ? data_in_2 : (temp_unique_3 && (rank_3 == 1)) ? data_in_3 : (temp_unique_4 && (rank_4 == 1)) ? data_in_4 : (temp_unique_5 && (rank_5 == 1)) ? data_in_5 : (temp_unique_6 && (rank_6 == 1)) ? data_in_6 : (temp_unique_7 && (rank_7 == 1)) ? data_in_7 : 8'h00;
assign selected_2 = (temp_unique_0 && (rank_0 == 2)) ? data_in_0 : (temp_unique_1 && (rank_1 == 2)) ? data_in_1 : (temp_unique_2 && (rank_2 == 2)) ? data_in_2 : (temp_unique_3 && (rank_3 == 2)) ? data_in_3 : (temp_unique_4 && (rank_4 == 2)) ? data_in_4 : (temp_unique_5 && (rank_5 == 2)) ? data_in_5 : (temp_unique_6 && (rank_6 == 2)) ? data_in_6 : (temp_unique_7 && (rank_7 == 2)) ? data_in_7 : 8'h00;
assign selected_3 = (temp_unique_0 && (rank_0 == 3)) ? data_in_0 : (temp_unique_1 && (rank_1 == 3)) ? data_in_1 : (temp_unique_2 && (rank_2 == 3)) ? data_in_2 : (temp_unique_3 && (rank_3 == 3)) ? data_in_3 : (temp_unique_4 && (rank_4 == 3)) ? data_in_4 : (temp_unique_5 && (rank_5 == 3)) ? data_in_5 : (temp_unique_6 && (rank_6 == 3)) ? data_in_6 : (temp_unique_7 && (rank_7 == 3)) ? data_in_7 : 8'h00;
assign selected_4 = (temp_unique_0 && (rank_0 == 4)) ? data_in_0 : (temp_unique_1 && (rank_1 == 4)) ? data_in_1 : (temp_unique_2 && (rank_2 == 4)) ? data_in_2 : (temp_unique_3 && (rank_3 == 4)) ? data_in_3 : (temp_unique_4 && (rank_4 == 4)) ? data_in_4 : (temp_unique_5 && (rank_5 == 4)) ? data_in_5 : (temp_unique_6 && (rank_6 == 4)) ? data_in_6 : (temp_unique_7 && (rank_7 == 4)) ? data_in_7 : 8'h00;
assign selected_5 = (temp_unique_0 && (rank_0 == 5)) ? data_in_0 : (temp_unique_1 && (rank_1 == 5)) ? data_in_1 : (temp_unique_2 && (rank_2 == 5)) ? data_in_2 : (temp_unique_3 && (rank_3 == 5)) ? data_in_3 : (temp_unique_4 && (rank_4 == 5)) ? data_in_4 : (temp_unique_5 && (rank_5 == 5)) ? data_in_5 : (temp_unique_6 && (rank_6 == 5)) ? data_in_6 : (temp_unique_7 && (rank_7 == 5)) ? data_in_7 : 8'h00;
assign selected_6 = (temp_unique_0 && (rank_0 == 6)) ? data_in_0 : (temp_unique_1 && (rank_1 == 6)) ? data_in_1 : (temp_unique_2 && (rank_2 == 6)) ? data_in_2 : (temp_unique_3 && (rank_3 == 6)) ? data_in_3 : (temp_unique_4 && (rank_4 == 6)) ? data_in_4 : (temp_unique_5 && (rank_5 == 6)) ? data_in_5 : (temp_unique_6 && (rank_6 == 6)) ? data_in_6 : (temp_unique_7 && (rank_7 == 6)) ? data_in_7 : 8'h00;
assign selected_7 = (temp_unique_0 && (rank_0 == 7)) ? data_in_0 : (temp_unique_1 && (rank_1 == 7)) ? data_in_1 : (temp_unique_2 && (rank_2 == 7)) ? data_in_2 : (temp_unique_3 && (rank_3 == 7)) ? data_in_3 : (temp_unique_4 && (rank_4 == 7)) ? data_in_4 : (temp_unique_5 && (rank_5 == 7)) ? data_in_5 : (temp_unique_6 && (rank_6 == 7)) ? data_in_6 : (temp_unique_7 && (rank_7 == 7)) ? data_in_7 : 8'h00;

assign unique_0 = (0 < unique_count) ? selected_0 : 8'hFF;
assign unique_1 = (1 < unique_count) ? selected_1 : 8'hFF;
assign unique_2 = (2 < unique_count) ? selected_2 : 8'hFF;
assign unique_3 = (3 < unique_count) ? selected_3 : 8'hFF;
assign unique_4 = (4 < unique_count) ? selected_4 : 8'hFF;
assign unique_5 = (5 < unique_count) ? selected_5 : 8'hFF;
assign unique_6 = (6 < unique_count) ? selected_6 : 8'hFF;
assign unique_7 = (7 < unique_count) ? selected_7 : 8'hFF;
endmodule