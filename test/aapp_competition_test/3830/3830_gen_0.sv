module returnable_rooms_counter(
  input  [15:0] belt_states,
  output [3:0]  count
);

  wire [1:0] room [7:0];
  assign room[0] = belt_states[1:0];
  assign room[1] = belt_states[3:2];
  assign room[2] = belt_states[5:4];
  assign room[3] = belt_states[7:6];
  assign room[4] = belt_states[9:8];
  assign room[5] = belt_states[11:10];
  assign room[6] = belt_states[13:12];
  assign room[7] = belt_states[15:14];

  wire all_right = (room[0] == 2'b01) & (room[1] == 2'b01) & (room[2] == 2'b01) &
                   (room[3] == 2'b01) & (room[4] == 2'b01) & (room[5] == 2'b01) &
                   (room[6] == 2'b01) & (room[7] == 2'b01);

  wire all_left  = (room[0] == 2'b10) & (room[1] == 2'b10) & (room[2] == 2'b10) &
                   (room[3] == 2'b10) & (room[4] == 2'b10) & (room[5] == 2'b10) &
                   (room[6] == 2'b10) & (room[7] == 2'b10);

  wire [7:0] is_dash;
  assign is_dash[0] = (room[0] == 2'b00);
  assign is_dash[1] = (room[1] == 2'b00);
  assign is_dash[2] = (room[2] == 2'b00);
  assign is_dash[3] = (room[3] == 2'b00);
  assign is_dash[4] = (room[4] == 2'b00);
  assign is_dash[5] = (room[5] == 2'b00);
  assign is_dash[6] = (room[6] == 2'b00);
  assign is_dash[7] = (room[7] == 2'b00);

  wire [7:0] returnable;
  assign returnable[0] = is_dash[0] | is_dash[7];
  assign returnable[1] = is_dash[1] | is_dash[0];
  assign returnable[2] = is_dash[2] | is_dash[1];
  assign returnable[3] = is_dash[3] | is_dash[2];
  assign returnable[4] = is_dash[4] | is_dash[3];
  assign returnable[5] = is_dash[5] | is_dash[4];
  assign returnable[6] = is_dash[6] | is_dash[5];
  assign returnable[7] = is_dash[7] | is_dash[6];

  wire [3:0] partial_count = returnable[0] + returnable[1] + returnable[2] + returnable[3] +
                             returnable[4] + returnable[5] + returnable[6] + returnable[7];

  assign count = (all_right | all_left) ? 4'd8 : partial_count;

endmodule