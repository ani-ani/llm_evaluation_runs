module returnable_rooms_counter(input [15:0] belt_states, output [3:0] count);
  wire all_right = (belt_states == 16'b0101010101010101);
  wire all_left = (belt_states == 16'b1010101010101010);
  wire [7:0] returnable;
  
  assign returnable[0] = (belt_states[1:0] == 2'b00) || (belt_states[15:14] == 2'b00);
  assign returnable[1] = (belt_states[3:2] == 2'b00) || (belt_states[1:0] == 2'b00);
  assign returnable[2] = (belt_states[5:4] == 2'b00) || (belt_states[3:2] == 2'b00);
  assign returnable[3] = (belt_states[7:6] == 2'b00) || (belt_states[5:4] == 2'b00);
  assign returnable[4] = (belt_states[9:8] == 2'b00) || (belt_states[7:6] == 2'b00);
  assign returnable[5] = (belt_states[11:10] == 2'b00) || (belt_states[9:8] == 2'b00);
  assign returnable[6] = (belt_states[13:12] == 2'b00) || (belt_states[11:10] == 2'b00);
  assign returnable[7] = (belt_states[15:14] == 2'b00) || (belt_states[13:12] == 2'b00);
  
  wire [3:0] count_temp = returnable[0] + returnable[1] + returnable[2] + returnable[3] +
                         returnable[4] + returnable[5] + returnable[6] + returnable[7];
  
  assign count = (all_right || all_left) ? 4'd8 : count_temp;
endmodule