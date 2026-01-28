module dijkstra_3 (
    input [7:0] y1, d1, r1,
    input [7:0] y2, d2, r2,
    input [7:0] y3, d3, r3,
    output [15:0] dist2,
    output [15:0] dist3
);

    // Compute absolute differences
    wire [7:0] abs_y1_y2;
    wire [7:0] abs_y1_y3;
    wire [7:0] abs_y2_y3;

    assign abs_y1_y2 = (y1 > y2) ? (y1 - y2) : (y2 - y1);
    assign abs_y1_y3 = (y1 > y3) ? (y1 - y3) : (y3 - y1);
    assign abs_y2_y3 = (y2 > y3) ? (y2 - y3) : (y3 - y2);

    // Condition checks
    wire cond1_to_2;
    wire cond1_to_3;
    wire cond1_to_2_via_3;
    wire cond1_to_3_via_2;

    assign cond1_to_2 = (abs_y1_y2 >= d1);
    assign cond1_to_3 = (abs_y1_y3 >= d1);
    assign cond1_to_2_via_3 = cond1_to_3 && (abs_y2_y3 >= d3);
    assign cond1_to_3_via_2 = cond1_to_2 && (abs_y2_y3 >= d2);

    // Candidate calculations (INF = 16'hFFFF)
    wire [15:0] candidate1_to_2;
    wire [15:0] candidate1_to_3;
    wire [15:0] candidate1_to_2_via_3;
    wire [15:0] candidate1_to_3_via_2;

    assign candidate1_to_2 = cond1_to_2 ? {8'd0, r1} + {8'd0, abs_y1_y2} : 16'hFFFF;
    assign candidate1_to_3 = cond1_to_3 ? {8'd0, r1} + {8'd0, abs_y1_y3} : 16'hFFFF;
    assign candidate1_to_2_via_3 = cond1_to_2_via_3 ? ({8'd0, r1} + {8'd0, abs_y1_y3} + {8'd0, r3} + {8'd0, abs_y2_y3}) : 16'hFFFF;
    assign candidate1_to_3_via_2 = cond1_to_3_via_2 ? ({8'd0, r1} + {8'd0, abs_y1_y2} + {8'd0, r2} + {8'd0, abs_y2_y3}) : 16'hFFFF;

    // Final dist for city2 and city3
    assign dist2 = (candidate1_to_2 < candidate1_to_2_via_3) ? candidate1_to_2 : candidate1_to_2_via_3;
    assign dist3 = (candidate1_to_3 < candidate1_to_3_via_2) ? candidate1_to_3 : candidate1_to_3_via_2;

endmodule