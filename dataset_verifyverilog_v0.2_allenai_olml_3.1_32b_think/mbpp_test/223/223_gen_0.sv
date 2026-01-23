module majority_check (
   input [2:0] n,
   input [7:0][7:0] arr,
   input [7:0] x,
   output reg result
);

wire cond_0_less_n;
wire first_occurrence_0;
wire cond_1_less_n;
wire first_occurrence_1;
wire cond_2_less_n;
wire first_occurrence_2;
wire cond_3_less_n;
wire first_occurrence_3;
wire cond_4_less_n;
wire first_occurrence_4;
wire cond_5_less_n;
wire first_occurrence_5;
wire cond_6_less_n;
wire first_occurrence_6;
wire cond_7_less_n;
wire first_occurrence_7;

assign cond_0_less_n = (0 < n);
assign first_occurrence_0 = cond_0_less_n && (arr[0] == x) && 1'b1;

assign cond_1_less_n = (1 < n);
assign first_occurrence_1 = cond_1_less_n && (arr[1] == x) && (arr[0] < x);

assign cond_2_less_n = (2 < n);
assign first_occurrence_2 = cond_2_less_n && (arr[2] == x) && (arr[1] < x);

assign cond_3_less_n = (3 < n);
assign first_occurrence_3 = cond_3_less_n && (arr[3] == x) && (arr[2] < x);

assign cond_4_less_n = (4 < n);
assign first_occurrence_4 = cond_4_less_n && (arr[4] == x) && (arr[3] < x);

assign cond_5_less_n = (5 < n);
assign first_occurrence_5 = cond_5_less_n && (arr[5] == x) && (arr[4] < x);

assign cond_6_less_n = (6 < n);
assign first_occurrence_6 = cond_6_less_n && (arr[6] == x) && (arr[5] < x);

assign cond_7_less_n = (7 < n);
assign first_occurrence_7 = cond_7_less_n && (arr[7] == x) && (arr[6] < x);

assign first_idx = 
   first_occurrence_0 ? 0 :
   first_occurrence_1 ? 1 :
   first_occurrence_2 ? 2 :
   first_occurrence_3 ? 3 :
   first_occurrence_4 ? 4 :
   first_occurrence_5 ? 5 :
   first_occurrence_6 ? 6 :
   first_occurrence_7 ? 7 :
   8;

assign half_n = n >> 1;
assign check_idx = first_idx + half_n;
assign valid_index = check_idx < n;

assign result = (first_idx != 8) && valid_index && (arr[check_idx] == x);

endmodule