module rain_accumulator (
input [7:0] d, t, wait_duration,
input [2:0] num_clouds, num_roofs,
input [7:0] cloud_start [0:7], cloud_end [0:7],
input [15:0] cloud_prob [0:7],
input [7:0] cloud_amount [0:7],
input [7:0] roof_start [0:7], roof_end [0:7],
output reg [31:0] total_rain);

wire [9:0] arrival_time_val;
assign arrival_time_val = wait_duration + d;

assign is_under_roof = 
(num_roofs >0 ? ( (roof_start[0] <=0) & (roof_end[0] >0) ) : 0) |
(num_roofs >1 ? ( (roof_start[1] <=0) & (roof_end[1] >0) ) : 0) |
(num_roofs >2 ? ( (roof_start[2] <=0) & (roof_end[2] >0) ) : 0) |
(num_roofs >3 ? ( (roof_start[3] <=0) & (roof_end[3] >0) ) : 0) |
(num_roofs >4 ? ( (roof_start[4] <=0) & (roof_end[4] >0) ) : 0) |
(num_roofs >5 ? ( (roof_start[5] <=0) & (roof_end[5] >0) ) : 0) |
(num_roofs >6 ? ( (roof_start[6] <=0) & (roof_end[6] >0) ) : 0) |
(num_roofs >7 ? ( (roof_start[7] <=0) & (roof_end[7] >0) ) : 0);

always @(*) begin
integer sum_total =0;

if (arrival_time_val > t) begin
    total_rain = 0;
end else begin
    if (wait_duration >0 && !is_under_roof) begin
        if (num_clouds >0) begin
            int cloud_start_j0 = cloud_start[0];
            int cloud_end_j0 = cloud_end[0];
            if (cloud_start_j0 <= cloud_end_j0) begin
                int overlap_start0 = cloud_start_j0 > 0 ? cloud_start_j0 : 0;
                int overlap_end0 = cloud_end_j0 < wait_duration ? cloud_end_j0 : wait_duration;
                if (overlap_start0 < overlap_end0) begin
                    sum_total += (overlap_end0 - overlap_start0) * cloud_amount[0] * cloud_prob[0];
                end
            end
        end
        if (num_clouds >1) begin
            int cloud_start_j1 = cloud_start[1];
            int cloud_end_j1 = cloud_end[1];
            if (cloud_start_j1 <= cloud_end_j1) begin
                int overlap_start1 = cloud_start_j1 >0 ? cloud_start_j1 :0;
                int overlap_end1 = cloud_end_j1 < wait_duration ? cloud_end_j1 : wait_duration;
                if (overlap_start1 < overlap_end1) begin
                    sum_total += (overlap_end1 - overlap_start1) * cloud_amount[1] * cloud_prob[1];
                end
            end
        end
        if (num_clouds >2) begin
            int cloud_start_j2 = cloud_start[2];
            int cloud_end_j2 = cloud_end[2];
            if (cloud_start_j2 <= cloud_end_j2) begin
                int overlap_start2 = cloud_start_j2 >0 ? cloud_start_j2 :0;
                int overlap_end2 = cloud_end_j2 < wait_duration ? cloud_end_j2 : wait_duration;
                if (overlap_start2 < overlap_end2) begin
                    sum_total += (overlap_end2 - overlap_start2) * cloud_amount[2] * cloud_prob[2];
                end
            end
        end
        if (num_clouds >3) begin
            int cloud_start_j3 = cloud_start[3];
            int cloud_end_j3 = cloud_end[3];
            if (cloud_start_j3 <= cloud_end_j3) begin
                int overlap_start3 = cloud_start_j3 >0 ? cloud_start_j3 :0;
                int overlap_end3 = cloud_end_j3 < wait_duration ? cloud_end_j3 : wait_duration;
                if (overlap_start3 < overlap_end3) begin
                    sum_total += (overlap_end3 - overlap_start3) * cloud_amount[3] * cloud_prob[3];
                end
            end
        end
        if (num_clouds >4) begin
            int cloud_start_j4 = cloud_start[4];
            int cloud_end_j4 = cloud_end[4];
            if (cloud_start_j4 <= cloud_end_j4) begin
                int overlap_start4 = cloud_start_j4 >0 ? cloud_start_j4 :0;
                int overlap_end4 = cloud_end_j4 < wait_duration ? cloud_end_j4 : wait_duration;
                if (overlap_start4 < overlap_end4) begin
                    sum_total += (overlap_end4 - overlap_start4) * cloud_amount[4] * cloud_prob[4];
                end
            end
        end
        if (num_clouds >5) begin
            int cloud_start_j5 = cloud_start[5];
            int cloud_end_j5 = cloud_end[5];
            if (cloud_start_j5 <= cloud_end_j5) begin
                int overlap_start5 = cloud_start_j5 >0 ? cloud_start_j5 :0;
                int overlap_end5 = cloud_end_j5 < wait_duration ? cloud_end_j5 : wait_duration;
                if (overlap_start5 < overlap_end5) begin
                    sum_total += (overlap_end5 - overlap_start5) * cloud_amount[5] * cloud_prob[5];
                end
            end
        end
        if (num_clouds >6) begin
            int cloud_start_j6 = cloud_start[6];
            int cloud_end_j6 = cloud_end[6];
            if (cloud_start_j6 <= cloud_end_j6) begin
                int overlap_start6 = cloud_start_j6 >0 ? cloud_start_j6 :0;
                int overlap_end6 = cloud_end_j6 < wait_duration ? cloud_end_j6 : wait_duration;
                if (overlap_start6 < overlap_end6) begin
                    sum_total += (overlap_end6 - overlap_start6) * cloud_amount[6] * cloud_prob[6];
                end
            end
        end
        if (num_clouds >7) begin
            int cloud_start_j7 = cloud_start[7];
            int cloud_end_j7 = cloud_end[7];
            if (cloud_start_j7 <= cloud_end_j7) begin
                int overlap_start7 = cloud_start_j7 >0 ? cloud_start_j7 :0;
                int overlap_end7 = cloud_end_j7 < wait_duration ? cloud_end_j7 : wait_duration;
                if (overlap_start7 < overlap_end7) begin
                    sum_total += (overlap_end7 - overlap_start7) * cloud_amount[7] * cloud_prob[7];
                end
            end
        end
    end

    if (num_clouds >0) begin
        int cloud_start_j0 = cloud_start[0];
        int cloud_end_j0 = cloud_end[0];
        if (cloud_start_j0 <= cloud_end_j0) begin
            int overlap_start0 = cloud_start_j0 > wait_duration ? cloud_start_j0 : wait_duration;
            int overlap_end0 = cloud_end_j0 < arrival_time_val ? cloud_end_j0 : arrival_time_val;
            if (overlap_start0 < overlap_end0) begin
                sum_total += (overlap_end0 - overlap_start0) * cloud_amount[0] * cloud_prob[0];
            end
        end
    end
    if (num_clouds >1) begin
        int cloud_start_j1 = cloud_start[1];
        int cloud_end_j1 = cloud_end[1];
        if (cloud_start_j1 <= cloud_end_j1) begin
            int overlap_start1 = cloud_start_j1 > wait_duration ? cloud_start_j1 : wait_duration;
            int overlap_end1 = cloud_end_j1 < arrival_time_val ? cloud_end_j1 : arrival_time_val;
            if (overlap_start1 < overlap_end1) begin
                sum_total += (overlap_end1 - overlap_start1) * cloud_amount[1] * cloud_prob[1];
            end
        end
    end
    if (num_clouds >2) begin
        int cloud_start_j2 = cloud_start[2];
        int cloud_end_j2 = cloud_end[2];
        if (cloud_start_j2 <= cloud_end_j2) begin
            int overlap_start2 = cloud_start_j2 > wait_duration ? cloud_start_j2 : wait_duration;
            int overlap_end2 = cloud_end_j2 < arrival_time_val ? cloud_end_j2 : arrival_time_val;
            if (overlap_start2 < overlap_end2) begin
                sum_total += (overlap_end2 - overlap_start2) * cloud_amount[2] * cloud_prob[2];
            end
        end
    end
    if (num_clouds >3) begin
        int cloud_start_j3 = cloud_start[3];
        int cloud_end_j3 = cloud_end[3];
        if (cloud_start_j3 <= cloud_end_j3) begin
            int overlap_start3 = cloud_start_j3 > wait_duration ? cloud_start_j3 : wait_duration;
            int overlap_end3 = cloud_end_j3 < arrival_time_val ? cloud_end_j3 : arrival_time_val;
            if (overlap_start3 < overlap_end3) begin
                sum_total += (overlap_end3 - overlap_start3) * cloud_amount[3] * cloud_prob[3];
            end
        end
    end
    if (num_clouds >4) begin
        int cloud_start_j4 = cloud_start[4];
        int cloud_end_j4 = cloud_end[4];
        if (cloud_start_j4 <= cloud_end_j4) begin
            int overlap_start4 = cloud_start_j4 > wait_duration ? cloud_start_j4 : wait_duration;
            int overlap_end4 = cloud_end_j4 < arrival_time_val ? cloud_end_j4 : arrival_time_val;
            if (overlap_start4 < overlap_end4) begin
                sum_total += (overlap_end4 - overlap_start4) * cloud_amount[4] * cloud_prob[4];
            end
        end
    end
    if (num_clouds >5) begin
        int cloud_start_j5 = cloud_start[5];
        int cloud_end_j5 = cloud_end[5];
        if (cloud_start_j5 <= cloud_end_j5) begin
            int overlap_start5 = cloud_start_j5 > wait_duration ? cloud_start_j5 : wait_duration;
            int overlap_end5 = cloud_end_j5 < arrival_time_val ? cloud_end_j5 : arrival_time_val;
            if (overlap_start5 < overlap_end5) begin
                sum_total += (overlap_end5 - overlap_start5) * cloud_amount[5] * cloud_prob[5];
            end
        end
    end
    if (num_clouds >6) begin
        int cloud_start_j6 = cloud_start[6];
        int cloud_end_j6 = cloud_end[6];
        if (cloud_start_j6 <= cloud_end_j6) begin
            int overlap_start6 = cloud_start_j6 > wait_duration ? cloud_start_j6 : wait_duration;
            int overlap_end6 = cloud_end_j6 < arrival_time_val ? cloud_end_j6 : arrival_time_val;
            if (overlap_start6 < overlap_end6) begin
                sum_total += (overlap_end6 - overlap_start6) * cloud_amount[6] * cloud_prob[6];
            end
        end
    end
    if (num_clouds >7) begin
        int cloud_start_j7 = cloud_start[7];
        int cloud_end_j7 = cloud_end[7];
        if (cloud_start_j7 <= cloud_end_j7) begin
            int overlap_start7 = cloud_start_j7 > wait_duration ? cloud_start_j7 : wait_duration;
            int overlap_end7 = cloud_end_j7 < arrival_time_val ? cloud_end_j7 : arrival_time_val;
            if (overlap_start7 < overlap_end7) begin
                sum_total += (overlap_end7 - overlap_start7) * cloud_amount[7] * cloud_prob[7];
            end
        end
    end
end

total_rain = sum_total << 8;
endmodule