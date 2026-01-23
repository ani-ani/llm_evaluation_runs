module plant_flowers (
    input [7:0] day,
    input [7:0] new_L,
    input [7:0] new_R,
    input [7:0] prev_L [0:7],
    input [7:0] prev_R [0:7],
    input [7:0] prev_H [0:7],
    output reg [7:0] flowers
);

    integer i;
    reg [7:0] count;
    reg intersect;
    reg left_hit;
    reg right_hit;

    always @(*) begin
        count = 0;
        for (i = 0; i < 8; i = i + 1) begin
            // Check if previous plant exists (height > 0) and is older (height < current day)
            // Also ensure it's not the current day itself
            if (prev_H[i] != 8'd0 && prev_H[i] < day) begin
                // Check left stem intersection: strict containment
                left_hit = (prev_L[i] < new_L) && (new_L < prev_R[i]);
                // Check right stem intersection: strict containment
                right_hit = (prev_L[i] < new_R) && (new_R < prev_R[i]);
                
                // If either stem intersects, count 1 flower for this plant
                if (left_hit || right_hit) begin
                    count = count + 1;
                end
            end
        end
        flowers = count;
    end

endmodule