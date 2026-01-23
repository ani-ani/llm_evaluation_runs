module frog_pathfinder (
    input clk,
    input rst_n,
    input start,
    input [2:0] plant_addr,
    input [2:0] plant_x,
    input [2:0] plant_y,
    input [7:0] plant_flies,
    input plant_write,
    output reg [7:0] result_energy,
    output reg [3:0] result_length,
    output reg [31:0] result_path,
    output reg done,
    output reg valid
);

    reg [2:0] state, next_state;
    reg [3:0] count_writes;
    reg [7:0] energy [8];
    reg [2:0] predecessor [8];
    reg [2:0] plant_x_ram [8];
    reg [2:0] plant_y_ram [8];
    reg [7:0] plant_flies_ram [8];
    reg [31:0] path;
    reg [2:0] path_index;
    reg [3:0] path_length;
    reg [3:0] result_length;
    reg [7:0] result_energy;
    reg [31:0] result_path;
    reg done_flag, valid_flag;

    parameter K = 5;
    localparam IDLE = 3'd0, WRITE = 3'd1, COMPUTE = 3'd2, DONE = 3'd3;

    always @(posedge clk) begin
        if (!rst_n) begin
            state <= IDLE;
            count_writes <= 4'd0;
            energy[0] <= 8'd0; energy[1] <= 8'd0; energy[2] <= 8'd0; energy[3] <= 8'd0; energy[4] <= 8'd0; energy[5] <= 8'd0; energy[6] <= 8'd0; energy[7] <= 8'd0;
            predecessor[0] <= 3'd-1; predecessor[1] <= 3'd-1; predecessor[2] <= 3'd-1; predecessor[3] <= 3'd-1; predecessor[4] <= 3'd-1; predecessor[5] <= 3'd-1; predecessor[6] <= 3'd-1; predecessor[7] <= 3'd-1;
            plant_x_ram[0] <= 3'd0; plant_x_ram[1] <= 3'd0; plant_x_ram[2] <= 3'd0; plant_x_ram[3] <= 3'd0; plant_x_ram[4] <= 3'd0; plant_x_ram[5] <= 3'd0; plant_x_ram[6] <= 3'd0; plant_x_ram[7] <= 3'd0;
            plant_y_ram[0] <= 3'd0; plant_y_ram[1] <= 3'd0; plant_y_ram[2] <= 3'd0; plant_y_ram[3] <= 3'd0; plant_y_ram[4] <= 3'd0; plant_y_ram[5] <= 3'd0; plant_y_ram[6] <= 3'd0; plant_y_ram[7] <= 3'd0;
            plant_flies_ram[0] <= 8'd0; plant_flies_ram[1] <= 8'd0; plant_flies_ram[2] <= 8'd0; plant_flies_ram[3] <= 8'd0; plant_flies_ram[4] <= 8'd0; plant_flies_ram[5] <= 8'd0; plant_flies_ram[6] <= 8'd0; plant_flies_ram[7] <= 8'd0;
            path <= 32'd0;
            path_index <= 3'd0;
            result_energy <= 8'd0;
            result_length <= 4'd0;
            result_path <= 32'd0;
            done_flag <= 1'b0;
            valid_flag <= 1'b0;
        end else begin
            state <= next_state;
            next_state <= state;
            case (state)
                IDLE: begin
                    if (start) begin
                        next_state <= WRITE;
                        count_writes <= 4'd0;
                    end
                end
                WRITE: begin
                    if (plant_write && count_writes < 8) begin
                        plant_x_ram[plant_addr] <= plant_x;
                        plant_y_ram[plant_addr] <= plant_y;
                        plant_flies_ram[plant_addr] <= plant_flies;
                        count_writes <= count_writes + 1;
                        if (count_writes == 8) begin
                            next_state <= COMPUTE;
                            energy[0] <= plant_flies_ram[0];
                            energy[1] <= 8'd0; energy[2] <= 8'd0; energy[3] <= 8'd0; energy[4] <= 8'd0; energy[5] <= 8'd0; energy[6] <= 8'd0; energy[7] <= 8'd0;
                            predecessor[1] <= 3'd-1; predecessor[2] <= 3'd-1; predecessor[3] <= 3'd-1; predecessor[4] <= 3'd-1; predecessor[5] <= 3'd-1; predecessor[6] <= 3'd-1; predecessor[7] <= 3'd-1;
                        end
                    end
                    if (count_writes == 8) begin
                        next_state <= COMPUTE;
                    end
                end
                COMPUTE: begin
                    next_state <= DONE;
                end
                DONE: begin
                    if (energy[7] == 8'd0) begin
                        result_energy <= 8'd0;
                        result_length <= 4'd0;
                        result_path <= 32'd0;
                    end else begin
                        result_energy <= energy[7];
                        result_length <= 4'd1;
                        result_path <= 32'd0;
                    end
                    done_flag <= 1'b1;
                    valid_flag <= 1'b1;
                end
            endcase
        end
    end

    assign done = done_flag;
    assign valid = valid_flag;
    assign result_energy = result_energy;
    assign result_length = result_length;
    assign result_path = result_path;

endmodule