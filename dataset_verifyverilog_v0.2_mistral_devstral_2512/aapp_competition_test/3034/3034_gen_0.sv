module rain_accumulator (
    input [7:0] d,
    input [7:0] t,
    input [7:0] wait_duration,
    input [2:0] num_clouds,
    input [2:0] num_roofs,
    input [7:0] cloud_start [0:7],
    input [7:0] cloud_end [0:7],
    input [15:0] cloud_prob [0:7],
    input [7:0] cloud_amount [0:7],
    input [7:0] roof_start [0:7],
    input [7:0] roof_end [0:7],
    output reg [31:0] total_rain
);

    reg [31:0] wait_rain = 0;
    reg [31:0] walk_rain = 0;
    reg [7:0] arrival_time = wait_duration + d;
    reg roofed_at_zero = 1'b0;
    integer i, j;

    // Check if arrival_time exceeds t
    if (arrival_time > t) begin
        total_rain = 0;
    end else begin
        // Check if position 0 is under any roof
        for (i = 0; i < num_roofs; i = i + 1) begin
            if (roof_start[i] <= 0 && 0 < roof_end[i]) begin
                roofed_at_zero = 1'b1;
            end
        end

        // Wait Phase: Calculate rain during wait_duration if not roofed
        if (wait_duration > 0 && !roofed_at_zero) begin
            for (i = 0; i < num_clouds; i = i + 1) begin
                for (j = 0; j < wait_duration; j = j + 1) begin
                    if (cloud_start[i] <= j && j < cloud_end[i]) begin
                        wait_rain = wait_rain + (cloud_amount[i] * cloud_prob[i]);
                    end
                end
            end
        end

        // Walk Phase: Calculate rain during walk
        for (i = 0; i < num_clouds; i = i + 1) begin
            for (j = wait_duration; j < arrival_time; j = j + 1) begin
                if (cloud_start[i] <= j && j < cloud_end[i]) begin
                    walk_rain = walk_rain + (cloud_amount[i] * cloud_prob[i]);
                end
            end
        end

        total_rain = wait_rain + walk_rain;
    end

endmodule