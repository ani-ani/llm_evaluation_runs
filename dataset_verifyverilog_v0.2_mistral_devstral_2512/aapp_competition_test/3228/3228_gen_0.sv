module gondola_scheduler (
  input [7:0] arrival_times_0,
  input [7:0] arrival_times_1,
  input [7:0] arrival_times_2,
  input [7:0] arrival_times_3,
  input [7:0] arrival_times_4,
  input [7:0] arrival_times_5,
  input [7:0] arrival_times_6,
  input [7:0] arrival_times_7,
  input [3:0] valid_skiers,
  input [4:0] T,
  input [2:0] G,
  output [15:0] total_waiting_time
);

  wire [7:0] departure_interval = (2*T + G - 1) / G;
  wire [15:0] wait_time_0 = (valid_skiers[0]) ? (((arrival_times_0 + departure_interval - 1) / departure_interval) * departure_interval - arrival_times_0) : 0;
  wire [15:0] wait_time_1 = (valid_skiers[1]) ? (((arrival_times_1 + departure_interval - 1) / departure_interval) * departure_interval - arrival_times_1) : 0;
  wire [15:0] wait_time_2 = (valid_skiers[2]) ? (((arrival_times_2 + departure_interval - 1) / departure_interval) * departure_interval - arrival_times_2) : 0;
  wire [15:0] wait_time_3 = (valid_skiers[3]) ? (((arrival_times_3 + departure_interval - 1) / departure_interval) * departure_interval - arrival_times_3) : 0;
  wire [15:0] wait_time_4 = (valid_skiers[4]) ? (((arrival_times_4 + departure_interval - 1) / departure_interval) * departure_interval - arrival_times_4) : 0;
  wire [15:0] wait_time_5 = (valid_skiers[5]) ? (((arrival_times_5 + departure_interval - 1) / departure_interval) * departure_interval - arrival_times_5) : 0;
  wire [15:0] wait_time_6 = (valid_skiers[6]) ? (((arrival_times_6 + departure_interval - 1) / departure_interval) * departure_interval - arrival_times_6) : 0;
  wire [15:0] wait_time_7 = (valid_skiers[7]) ? (((arrival_times_7 + departure_interval - 1) / departure_interval) * departure_interval - arrival_times_7) : 0;

  assign total_waiting_time = wait_time_0 + wait_time_1 + wait_time_2 + wait_time_3 + wait_time_4 + wait_time_5 + wait_time_6 + wait_time_7;

endmodule