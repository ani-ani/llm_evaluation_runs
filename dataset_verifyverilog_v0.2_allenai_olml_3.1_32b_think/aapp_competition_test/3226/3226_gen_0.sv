module police_escape (
    input clk,
    input rst_n,
    input start,
    input [1:0] num_nodes,
    input [1:0] num_exits,
    input [1:0] robber_start,
    input [1:0] police_start,
    input [5:0] edge_length [4:0][4:0],
    input [1:0] exits [1:0],
    output reg [31:0] min_speed,
    output reg done,
    output reg possible
);

reg [1:0] num_nodes_reg;
reg [1:0] num_exits_reg;
reg [1:0] robber_start_reg;
reg [1:0] police_start_reg;
reg [5:0] edge_length_reg [4:0][4:0];
reg [1:0] exits_reg [1:0];

localparam int IDLE = 3'd0;
localparam int LOAD = 3'd1;
localparam int COMPUTE_ROBBER = 3'd2;
localparam int COMPUTE_POLICE = 3'd3;
localparam int CHECK_EXITS = 3'd4;
localparam int CALCULATE_SPEED = 3'd5;
localparam int WAIT = 3'd6;
localparam int DONE = 3'd7;

reg [2:0] state;
reg [7:0] counter;

reg [1:0] robber_dist [3:0];
reg [1:0] police_dist [3:0];

reg [1:0] exit_nodes [1:0];
wire [1:0] valid_exit;
wire [31:0] candidate_speed;
reg [31:0] min_speed_reg;
reg possible_reg;
reg done_reg;

always @(*) begin
    min_speed = min_speed_reg;
    done = done_reg;
    possible = possible_reg;
end

always @(posedge clk) begin
    if (!rst_n) begin
        state <= IDLE;
        counter <= 8'd0;
        num_nodes_reg <= 2'd0;
        num_exits_reg <= 2'd0;
        robber_start_reg <= 2'd0;
        police_start_reg <= 2'd0;
        edge_length_reg <= 6'd0;
        exits_reg <= 2'd0;
        robber_dist <= 4'd0;
        police_dist <= 4'd0;
        min_speed_reg <= 32'd0;
        possible_reg <= 1'b0;
        done_reg <= 1'b0;
        state <= IDLE;
    end else begin
        case (state)
            IDLE: if (start) state <= LOAD; else state <= IDLE;
            LOAD: begin
                num_nodes_reg <= num_nodes;
                num_exits_reg <= num_exits;
                robber_start_reg <= robber_start;
                police_start_reg <= police_start;
                edge_length_reg <= edge_length;
                exits_reg <= exits;
                exit_nodes[0] = exits_reg[0];
                if (num_exits_reg == 2) exit_nodes[1] = exits_reg[1];
                state <= COMPUTE_ROBBER;
            end
            COMPUTE_ROBBER: begin
                robber_dist <= 4'd0;
                state <= COMPUTE_POLICE;
            end
            COMPUTE_POLICE: begin
                police_dist <= 4'd0;
                state <= CHECK_EXITS;
            end
            CHECK_EXITS: begin
                possible_reg <= 1'b0;
                min_speed_reg <= 32'd0;
                state <= CALCULATE_SPEED;
            end
            CALCULATE_SPEED: begin
                min_speed_reg <= (possible_reg) ? 32'd100 : 32'd0xFFFFFFFF;
                state <= WAIT;
            end
            WAIT: begin
                if (counter < 256) begin
                    counter <= counter + 1;
                    state <= WAIT;
                end else begin
                    done_reg <= 1'b1;
                    min_speed_reg <= (possible_reg) ? 32'd100 : 32'd0xFFFFFFFF;
                    state <= DONE;
                end
            end
            DONE: state <= DONE;
        endcase
    end
end

endmodule