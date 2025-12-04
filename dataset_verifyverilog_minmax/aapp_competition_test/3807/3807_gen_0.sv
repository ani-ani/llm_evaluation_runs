module greedy_block_tower (
  input clk,
  input rst_n,
  input start,
  input [15:0] m,
  output reg [7:0] block_count,
  output reg [15:0] volume_X,
  output reg done
);

parameter IDLE = 2'b00;
parameter FIND_CUBE = 2'b01;
parameter UPDATE = 2'b10;

reg [1:0] state;
reg [15:0] current_remaining_volume;
reg [7:0] a_out;
reg [15:0] cube_value;

localparam [0:40][15:0] cubes = '{
    0: 0,
    1: 1,
    2: 8,
    3: 27,
    4: 64,
    5: 125,
    6: 216,
    7: 343,
    8: 512,
    9: 729,
    10: 1000,
    11: 1331,
    12: 1728,
    13: 2197,
    14: 2744,
    15: 3375,
    16: 4096,
    17: 4913,
    18: 5832,
    19: 6859,
    20: 8000,
    21: 9261,
    22: 10648,
    23: 12167,
    24: 13824,
    25: 15625,
    26: 17576,
    27: 19683,
    28: 21952,
    29: 24389,
    30: 27000,
    31: 29791,
    32: 32768,
    33: 35937,
    34: 39304,
    35: 42875,
    36: 46656,
    37: 50653,
    38: 54872,
    39: 59319,
    40: 64000
};

function [7:0] get_a;
    input [15:0] rem;
    begin
        get_a = 0;
        for (int i=40; i>=1; i--) begin
            if (cubes[i] <= rem) begin
                get_a = i;
                return;
            end
        end
    end
endfunction

always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        current_remaining_volume <= 0;
        block_count <= 0;
        volume_X <= 0;
        done <= 0;
    end
    else begin
        case (state)
            IDLE: begin
                if (start) begin
                    state <= FIND_CUBE;
                    current_remaining_volume <= m;
                    block_count <= 0;
                    volume_X <= 0;
                    done <= 0;
                end
            end
            FIND_CUBE: begin
                a_out = get_a(current_remaining_volume);
                cube_value = cubes[a_out];
                block_count <= block_count + 1;
                volume_X <= cube_value;
                if (cube_value == 0) begin
                    state <= IDLE;
                    done <= 1;
                end
                else begin
                    current_remaining_volume <= current_remaining_volume - cube_value;
                    if (current_remaining_volume - cube_value == 0) begin
                        state <= IDLE;
                        done <= 1;
                    end
                    else begin
                        state <= UPDATE;
                    end
                end
            end
            UPDATE: begin
                if (current_remaining_volume > 0) begin
                    state <= FIND_CUBE;
                end
                else begin
                    state <= IDLE;
                    done <= 1;
                end
            end
        endcase
    end
end

endmodule