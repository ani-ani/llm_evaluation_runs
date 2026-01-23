module elf_dwarf_optimizer (
    input clk,
    input rst_n,
    input start,
    input [2:0] N,
    input [7:0] A_i [0:7],
    input [15:0] P_i [0:7],
    input [15:0] V_i [0:7],
    output reg [3:0] result,
    output reg done
);

    // Parameters
    parameter MAX_N = 8;
    parameter STRENGTH_WIDTH = 16;
    parameter LABEL_WIDTH = 3;

    // State definitions
    localparam IDLE = 4'd0;
    localparam INIT_PERM = 4'd1;
    localparam NEXT_PERM = 4'd2;
    localparam SIM_SEAT = 4'd3;
    localparam SEAT_ELF = 4'd4;
    localparam COUNT_WINS = 4'd5;
    localparam UPDATE_MAX = 4'd6;
    localparam DONE = 4'd7;

    // Registers and Wires
    reg [3:0] state, next_state;

    // Permutation generation registers
    reg [2:0] p_indices [0:7]; // Current permutation indices
    reg [3:0] current_elf_idx; // Index in permutation array
    reg [7:0] occupied_dwarves; // Bitmask for occupied dwarves
    reg [3:0] current_victories;
    reg [2:0] current_dwarf_idx; // Current dwarf being checked

    // Temporary storage
    reg [2:0] temp_idx;
    reg [2:0] swap_idx;

    // Completion tracking
    reg [2:0] gen_count; // Tracks how many permutations generated for current N
    reg [19:0] factorial_limit; // N! or 8! depending on N
    reg [19:0] perm_counter;