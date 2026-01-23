module gondola_scheduler(
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

    // Internal signals to compute departure_interval
    wire [5:0] two_T;
    wire [5:0] G_extended;
    wire [5:0] numerator;
    wire [5:0] departure_interval;

    // Calculate 2 * T
    assign two_T = {T, 1'b0};

    // Extend G to 6 bits
    assign G_extended = {3'b000, G};

    // Calculate ceil((2*T) / G) as (2*T + G - 1) / G using integer division
    // Check for G = 0 to prevent division by zero (though G is 1-4 per spec)
    assign numerator = (G == 3'd0) ? 6'd0 : (two_T + G_extended - 6'd1);
    assign departure_interval = (G == 3'd0) ? 6'd0 : (numerator / G_extended);

    // Intermediate signals for wait calculations
    wire [7:0] arrival [0:7];
    wire [7:0] next_dep [0:7];
    wire [7:0] wait_time [0:7];
    wire [15:0] partial_sum;

    assign arrival[0] = arrival_times_0;
    assign arrival[1] = arrival_times_1;
    assign arrival[2] = arrival_times_2;
    assign arrival[3] = arrival_times_3;
    assign arrival[4] = arrival_times_4;
    assign arrival[5] = arrival_times_5;
    assign arrival[6] = arrival_times_6;
    assign arrival[7] = arrival_times_7;

    // Generate logic for each skier
    genvar i;
    generate
        for (i = 0; i < 8; i = i + 1) begin : wait_gen
            // next_departure = ceil(arrival / interval) * interval
            // Implementation: ((arrival + interval - 1) / interval) * interval
            // If arrival is multiple of interval, (arrival + interval - 1) gives a value
            // that divides exactly to arrival/interval + 1? No, wait.
            // Example: arrival=4, interval=2. (4+2-1)/2 = 5/2 = 2. 2*2=4. Correct.
            // Example: arrival=3, interval=2. (3+2-1)/2 = 4/2 = 2. 2*2=4. Correct.
            // Example: arrival=0, interval=2. (0+2-1)/2 = 1/2 = 0. 0*2=0. Correct.
            // Integer division truncates. So (val - 1) / div gives floor((val-1)/div).
            // To get ceil(val/div), we use (val + div - 1) / div.
            
            wire [7:0] next_dep_raw;
            wire [7:0] next_dep_calc;
            wire [7:0] interval_check;
            
            // Convert departure_interval to 8 bits for comparison with arrival
            wire [7:0] dep_int_8;
            assign dep_int_8 = {2'b00, departure_interval};
            
            // Calculate ((arrival + dep_int_8 - 1) / dep_int_8) * dep_int_8
            wire [7:0] sum_for_ceil;
            // If dep_int_8 is 0, avoid crash (logic added at output)
            assign sum_for_ceil = (dep_int_8 == 8'd0) ? 8'd0 : (arrival[i] + dep_int_8 - 8'd1);
            
            wire [7:0] div_result;
            assign div_result = (dep_int_8 == 8'd0) ? 8'd0 : (sum_for_ceil / dep_int_8);
            
            assign next_dep_calc = div_result * dep_int_8;
            
            // Handle edge case: if result is less than arrival (due to max index rollover or zero interval)
            // Just use arrival + interval in that case to ensure next_dep >= arrival
            // But spec says ceil, so next_dep_calc >= arrival should hold if math is right.
            // If dep_int_8 is 0, wait time is 0.
            
            // Wait time
            // If valid_skiers[i] is 1, calculate, else 0
            wire [7:0] w;
            assign w = next_dep_calc - arrival[i];
            
            assign wait_time[i] = (valid_skiers[i] && dep_int_8 != 8'd0) ? w : 8'd0;
        end
    endgenerate

    // Summation tree
    wire [15:0] sum0, sum1, sum2, sum3;
    wire [15:0] sum4, sum5;
    wire [15:0] sum6;

    // Level 1
    assign sum0 = {8'b0, wait_time[0]} + {8'b0, wait_time[1]};
    assign sum1 = {8'b0, wait_time[2]} + {8'b0, wait_time[3]};
    assign sum2 = {8'b0, wait_time[4]} + {8'b0, wait_time[5]};
    assign sum3 = {8'b0, wait_time[6]} + {8'b0, wait_time[7]};

    // Level 2
    assign sum4 = sum0 + sum1;
    assign sum5 = sum2 + sum3;

    // Level 3
    assign sum6 = sum4 + sum5;

    assign total_waiting_time = sum6;

endmodule