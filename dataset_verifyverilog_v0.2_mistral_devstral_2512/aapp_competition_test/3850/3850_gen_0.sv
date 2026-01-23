module key_assignment (
  input [9:0] p,
  input [9:0] people0,
  input [9:0] people1,
  input [9:0] key0,
  input [9:0] key1,
  input [9:0] key2,
  input [9:0] key3,
  output [10:0] result
);

  // Window 0: keys 0,1 assigned to people 0,1
  wire [9:0] dist0_0 = (people0 > key0) ? (people0 - key0) : (key0 - people0);
  wire [9:0] dist0_1 = (people1 > key1) ? (people1 - key1) : (key1 - people1);
  wire [9:0] dist0_2 = (key0 > p) ? (key0 - p) : (p - key0);
  wire [9:0] dist0_3 = (key1 > p) ? (key1 - p) : (p - key1);
  wire [10:0] time0_0 = dist0_0 + dist0_2;
  wire [10:0] time0_1 = dist0_1 + dist0_3;
  wire [10:0] max_time0 = (time0_0 > time0_1) ? time0_0 : time0_1;

  // Window 1: keys 1,2 assigned to people 0,1
  wire [9:0] dist1_0 = (people0 > key1) ? (people0 - key1) : (key1 - people0);
  wire [9:0] dist1_1 = (people1 > key2) ? (people1 - key2) : (key2 - people1);
  wire [9:0] dist1_2 = (key1 > p) ? (key1 - p) : (p - key1);
  wire [9:0] dist1_3 = (key2 > p) ? (key2 - p) : (p - key2);
  wire [10:0] time1_0 = dist1_0 + dist1_2;
  wire [10:0] time1_1 = dist1_1 + dist1_3;
  wire [10:0] max_time1 = (time1_0 > time1_1) ? time1_0 : time1_1;

  // Window 2: keys 2,3 assigned to people 0,1
  wire [9:0] dist2_0 = (people0 > key2) ? (people0 - key2) : (key2 - people0);
  wire [9:0] dist2_1 = (people1 > key3) ? (people1 - key3) : (key3 - people1);
  wire [9:0] dist2_2 = (key2 > p) ? (key2 - p) : (p - key2);
  wire [9:0] dist2_3 = (key3 > p) ? (key3 - p) : (p - key3);
  wire [10:0] time2_0 = dist2_0 + dist2_2;
  wire [10:0] time2_1 = dist2_1 + dist2_3;
  wire [10:0] max_time2 = (time2_0 > time2_1) ? time2_0 : time2_1;

  // Find minimum of all window max times
  wire [10:0] min_time1 = (max_time0 < max_time1) ? max_time0 : max_time1;
  assign result = (min_time1 < max_time2) ? min_time1 : max_time2;

endmodule