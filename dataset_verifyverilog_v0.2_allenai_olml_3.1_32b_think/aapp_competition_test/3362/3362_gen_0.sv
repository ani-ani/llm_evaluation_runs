module lava_game (input clk, input rst_n, input start, input [15:0] A, input [15:0] F, input [7:0] map_data, input [2:0] map_index, output reg [1:0] result, output reg done);
localparam IDLE = 2'd0;
localparam LOAD = 2'd1;
localparam ELSA_PROCESS = 2'd2;
localparam FATHER_PROCESS = 2'd3;
localparam COMPARE = 2'd4;
localparam DONE_STATE = 2'd5;

localparam TOTAL_TILES = 8;

reg [2:0] state;
reg [1:0] result_val;
reg done_flag;
reg [7:0] elsa_steps;
reg [7:0] father_steps;
reg [1:0] map_ram [TOTAL_TILES-1:0];
reg [2:0] load_index;

always @(posedge clk) begin
    if (!rst_n) begin
        state <= IDLE;
        result_val <= 0;
        done_flag <=0;
        elsa_steps <=0;
        father_steps <=0;
        load_index <=0;
        map_ram <= {TOTAL_TILES{2'b00}};
    end else begin
        case(state)
            IDLE: if (start) state <= LOAD; else state <= IDLE;
            LOAD: begin
                if (load_index < TOTAL_TILES) begin
                    if (map_index == load_index) begin
                        map_ram[load_index] <= map_data[1:0];
                    end
                    load_index <= load_index +1;
                    if (load_index == TOTAL_TILES) begin
                        state <= ELSA_PROCESS;
                    end
                    state <= LOAD;
                end
            end
            ELSA_PROCESS: begin
                elsa_steps <= 1;
                state <= FATHER_PROCESS;
            end
            FATHER_PROCESS: begin
                father_steps <=1;
                state <= COMPARE;
            end
            COMPARE: begin
                if (elsa_steps > 64 || father_steps >64) begin
                    if (elsa_steps >64 && father_steps >64) begin
                        result_val <=0;
                    end else if (elsa_steps >64) begin
                        result_val <=1;
                    end else begin
                        result_val <=2;
                    end
                end else begin
                    if (elsa_steps == father_steps) begin
                        result_val <=3;
                    end else if (elsa_steps < father_steps) begin
                        result_val <=2;
                    end else begin
                        result_val <=1;
                    end
                end
                done_flag <=1;
                state <= DONE_STATE;
            end
            DONE_STATE: state <= DONE_STATE;
        endcase
    end
end

assign result = result_val;
assign done = done_flag;

endmodule