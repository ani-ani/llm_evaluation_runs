module plant_flowers(
    input clk,
    input rst_n,
    input start,
    input [7:0] L,
    input [7:0] R,
    output reg [4:0] num_flowers,
    output reg done
);

    // Internal storage for up to 8 plants
    reg [7:0] L_arr [0:7];
    reg [7:0] R_arr [0:7];
    reg [2:0] plant_count; // number of stored plants (0-8, but 3 bits for 0-7 index)

    // Combinational count of intersections on start
    integer i;
    reg [4:0] flowers_comb;

    always @(*) begin
        flowers_comb = 5'd0;
        if (start) begin
            for (i = 0; i < 8; i = i + 1) begin
                if (i < plant_count) begin
                    // Count if new L is between (Lj,Rj) or new R is between (Lj,Rj)
                    if ((L > L_arr[i] && L < R_arr[i]) ||
                        (R > L_arr[i] && R < R_arr[i])) begin
                        flowers_comb = flowers_comb + 5'd1;
                    end
                end
            end
        end
    end

    // Sequential logic for registers and done pulse
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            plant_count  <= 3'd0;
            num_flowers <= 5'd0;
            done        <= 1'b0;
        end else begin
            // Default done low each cycle
            done <= 1'b0;

            if (start) begin
                // Output combinational result immediately (registered on clock edge)
                num_flowers <= flowers_comb;

                // Store new plant if there is space (max 8 plants)
                if (plant_count < 3'd8) begin
                    L_arr[plant_count] <= L;
                    R_arr[plant_count] <= R;
                    plant_count        <= plant_count + 3'd1;
                end

                // Pulse done high for this cycle
                done <= 1'b1;
            end
        end
    end

endmodule