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

    integer i;
    reg [7:0] arrival_time;
    reg is_roofed_at_zero;
    reg [31:0] rain_wait;
    reg [31:0] rain_walk;
    reg [31:0] cloud_contrib_wait;
    reg [31:0] cloud_contrib_walk;
    reg [7:0] curr_time;
    reg [7:0] walk_end_time;
    reg valid;

    always @(*) begin
        // 1. Check validity
        arrival_time = wait_duration + d;
        valid = (arrival_time <= t);

        // 2. Check roof at position 0
        is_roofed_at_zero = 0;
        for (i = 0; i < 8; i = i + 1) begin
            if (i < num_roofs) begin
                if (roof_start[i] <= 8'h00 && 8'h00 < roof_end[i]) begin
                    is_roofed_at_zero = 1;
                end
            end
        end

        // 3. Calculate Rain during Wait Phase
        rain_wait = 0;
        if (valid && wait_duration > 0) begin
            if (!is_roofed_at_zero) begin
                for (curr_time = 0; curr_time < 255; curr_time = curr_time + 1) begin
                    if (curr_time < wait_duration) begin
                        cloud_contrib_wait = 0;
                        for (i = 0; i < 8; i = i + 1) begin
                            if (i < num_clouds) begin
                                if (cloud_start[i] <= curr_time && curr_time < cloud_end[i]) begin
                                    cloud_contrib_wait = cloud_contrib_wait + (cloud_amount[i] * cloud_prob[i]);
                                end
                            end
                        end
                        rain_wait = rain_wait + cloud_contrib_wait;
                    end
                end
            end
        end

        // 4. Calculate Rain during Walk Phase
        rain_walk = 0;
        if (valid && d > 0) begin
            walk_end_time = arrival_time - 1;
            for (curr_time = 0; curr_time < 255; curr_time = curr_time + 1) begin
                if (curr_time >= wait_duration && curr_time <= walk_end_time) begin
                    cloud_contrib_walk = 0;
                    for (i = 0; i < 8; i = i + 1) begin
                        if (i < num_clouds) begin
                            if (cloud_start[i] <= curr_time && curr_time < cloud_end[i]) begin
                                cloud_contrib_walk = cloud_contrib_walk + (cloud_amount[i] * cloud_prob[i]);
                            end
                        end
                    end
                    rain_walk = rain_walk + cloud_contrib_walk;
                end
            end
        end

        // 5. Assign Output
        if (!valid) begin
            total_rain = 0;
        end else begin
            total_rain = rain_wait + rain_walk;
        end
    end

endmodule
