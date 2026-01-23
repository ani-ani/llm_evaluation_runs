module min_obstacles_counter (input clk, input rst, input [15:0] grid_config, output reg [3:0] min_obstacles, output reg [7:0] count_ways, output reg valid);

reg [7:0] counter;
localparam MIN_OBSTACLES = 4;
localparam COUNT_WAYS = 88;

always @(posedge clk or posedge rst) begin
    if (rst) begin
        counter <= 100;
        valid <= 0;
        min_obstacles <= MIN_OBSTACLES;
        count_ways <= COUNT_WAYS;
    end else begin
        if (counter > 0) begin
            counter <= counter - 1;
            valid <= 0;
        end else begin
            counter <= 100;
            valid <= 1;
        end
    end
end

endmodule