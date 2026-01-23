module key_assignment(
    input [9:0] p,
    input [9:0] people0,
    input [9:0] people1,
    input [9:0] key0,
    input [9:0] key1,
    input [9:0] key2,
    input [9:0] key3,
    output [10:0] result
);
    // Window 0: keys 0, 1
    wire [9:0] dist_p0_k0 = (people0 > key0) ? (people0 - key0) : (key0 - people0);
    wire [9:0] dist_k0_p = (key0 > p) ? (key0 - p) : (p - key0);
    wire [10:0] time0_0 = dist_p0_k0 + dist_k0_p;

    wire [9:0] dist_p1_k1 = (people1 > key1) ? (people1 - key1) : (key1 - people1);
    wire [9:0] dist_k1_p = (key1 > p) ? (key1 - p) : (p - key1);
    wire [10:0] time0_1 = dist_p1_k1 + dist_k1_p;

    wire [10:0] max0 = (time0_0 > time0_1) ? time0_0 : time0_1;

    // Window 1: keys 1, 2
    wire [9:0] dist_p0_k1 = (people0 > key1) ? (people0 - key1) : (key1 - people0);
    wire [10:0] time1_0 = dist_p0_k1 + dist_k1_p;

    wire [9:0] dist_p1_k2 = (people1 > key2) ? (people1 - key2) : (key2 - people1);
    wire [9:0] dist_k2_p = (key2 > p) ? (key2 - p) : (p - key2);
    wire [10:0] time1_1 = dist_p1_k2 + dist_k2_p;

    wire [10:0] max1 = (time1_0 > time1_1) ? time1_0 : time1_1;

    // Window 2: keys 2, 3
    wire [9:0] dist_p0_k2 = (people0 > key2) ? (people0 - key2) : (key2 - people0);
    wire [10:0] time2_0 = dist_p0_k2 + dist_k2_p;

    wire [9:0] dist_p1_k3 = (people1 > key3) ? (people1 - key3) : (key3 - people1);
    wire [9:0] dist_k3_p = (key3 > p) ? (key3 - p) : (p - key3);
    wire [10:0] time2_1 = dist_p1_k3 + dist_k3_p;

    wire [10:0] max2 = (time2_0 > time2_1) ? time2_0 : time2_1;

    // Find min of maxes
    wire [10:0] min_max_01 = (max0 < max1) ? max0 : max1;
    assign result = (min_max_01 < max2) ? min_max_01 : max2;

endmodule