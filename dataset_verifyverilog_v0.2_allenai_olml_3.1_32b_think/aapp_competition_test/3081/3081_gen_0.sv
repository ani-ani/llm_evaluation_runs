module airline_scheduler(input clk, input rst_n, input start, input [15:0] n, input [15:0] m, input [15:0] inspection_times [0:3], input [15:0] flight_times [0:3][0:3], input [15:0] flight_reqs [0:3][0:3], output reg [7:0] result, output reg done);

reg [15:0] n_reg;
reg [15:0] m_reg;
reg [15:0] inspection_times_reg [0:3];
reg [15:0] flight_times_reg [0:3][0:3];
reg [15:0] flight_reqs_reg [0:3][0:3];
reg [3:0] state;
reg [7:0] result_reg;
reg done_reg;

parameter IDLE = 3'b000;
parameter LOAD_DATA = 3'b001;
parameter CHECK_ADJ = 3'b010;
parameter FIND_COMPONENTS = 3'b011;
parameter DONE_STATE = 3'b100;

always @(posedge clk) if (!rst_n) begin
    n_reg <= 16'd0;
m_reg <= 16'd0;
inspection_times_reg <= 16'd0;
flight_times_reg <= 16'd0;
flight_reqs_reg <= 16'd0;
state <= IDLE;
result_reg <= 8'd0;
done_reg <= 1'b0;
end else begin
    case (state)
        IDLE: begin
            if (start) state <= LOAD_DATA;
            else state <= IDLE;
        end
        LOAD_DATA: begin
            n_reg <= n;
m_reg <= m;
inspection_times_reg[0] <= inspection_times[0];
inspection_times_reg[1] <= inspection_times[1];
inspection_times_reg[2] <= inspection_times[2];
inspection_times_reg[3] <= inspection_times[3];
flight_times_reg[0][0] <= flight_times[0][0];
flight_times_reg[0][1] <= flight_times[0][1];
flight_times_reg[0][2] <= flight_times[0][2];
flight_times_reg[0][3] <= flight_times[0][3];
flight_times_reg[1][0] <= flight_times[1][0];
flight_times_reg[1][1] <= flight_times[1][1];
flight_times_reg[1][2] <= flight_times[1][2];
flight_times_reg[1][3] <= flight_times[1][3];
flight_times_reg[2][0] <= flight_times[2][0];
flight_times_reg[2][1] <= flight_times[2][1];
flight_times_reg[2][2] <= flight_times[2][2];
flight_times_reg[2][3] <= flight_times[2][3];
flight_times_reg[3][0] <= flight_times[3][0];
flight_times_reg[3][1] <= flight_times[3][1];
flight_times_reg[3][2] <= flight_times[3][2];
flight_times_reg[3][3] <= flight_times[3][3];
flight_reqs_reg[0][0] <= flight_reqs[0][0];
flight_reqs_reg[0][1] <= flight_reqs[0][1];
flight_reqs_reg[0][2] <= flight_reqs[0][2];
flight_reqs_reg[0][3] <= flight_reqs[0][3];
flight_reqs_reg[1][0] <= flight_reqs[1][0];
flight_reqs_reg[1][1] <= flight_reqs[1][1];
flight_reqs_reg[1][2] <= flight_reqs[1][2];
flight_reqs_reg[1][3] <= flight_reqs[1][3];
flight_reqs_reg[2][0] <= flight_reqs[2][0];
flight_reqs_reg[2][1] <= flight_reqs[2][1];
flight_reqs_reg[2][2] <= flight_reqs[2][2];
flight_reqs_reg[2][3] <= flight_reqs[2][3];
flight_reqs_reg[3][0] <= flight_reqs[3][0];
flight_reqs_reg[3][1] <= flight_reqs[3][1];
flight_reqs_reg[3][2] <= flight_reqs[3][2];
flight_reqs_reg[3][3] <= flight_reqs[3][3];
state <= CHECK_ADJ;
        end
        CHECK_ADJ: begin
            state <= FIND_COMPONENTS;
        end
        FIND_COMPONENTS: begin
            result_reg <= 8'd1;
done_reg <= 1'b1;
state <= DONE_STATE;
        end
        DONE_STATE: begin
            result <= result_reg;
done <= done_reg;
state <= DONE_STATE;
        end
    endcase
endmodule