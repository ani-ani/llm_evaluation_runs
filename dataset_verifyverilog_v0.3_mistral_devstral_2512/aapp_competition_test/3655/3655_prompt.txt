module compute_scores (
    input [3:0] robot_flat,
    input [8:0] floor_flat,
    output reg [2:0] score0,
    output reg [2:0] score1,
    output reg [2:0] score2,
    output reg [2:0] score3
);

    always @(*) begin
        // (0,0)
        score0 = 
            (robot_flat[0] == floor_flat[0]) +
            (robot_flat[1] == floor_flat[1]) +
            (robot_flat[2] == floor_flat[3]) +
            (robot_flat[3] == floor_flat[4]);

        // (0,1)
        score1 = 
            (robot_flat[0] == floor_flat[3]) +
            (robot_flat[1] == floor_flat[4]) +
            (robot_flat[2] == floor_flat[6]) +
            (robot_flat[3] == floor_flat[7]);

        // (1,0)
        score2 = 
            (robot_flat[0] == floor_flat[1]) +
            (robot_flat[1] == floor_flat[2]) +
            (robot_flat[2] == floor_flat[4]) +
            (robot_flat[3] == floor_flat[5]);

        // (1,1)
        score3 = 
            (robot_flat[0] == floor_flat[4]) +
            (robot_flat[1] == floor_flat[5]) +
            (robot_flat[2] == floor_flat[7]) +
            (robot_flat[3] == floor_flat[8]);
    end

endmodule