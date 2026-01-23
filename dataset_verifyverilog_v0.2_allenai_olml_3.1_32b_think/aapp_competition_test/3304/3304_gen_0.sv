module elf_dwarf_optimizer (input clk, input rst_n, input start, input [2:0] N, input [7:0] A_i [0:7], input [15:0] P_i [0:7], input [15:0] V_i [0:7], output reg [3:0] result, output reg done);
`parameter MAX_N = 8;
`parameter STRENGTH_WIDTH = 16;
`parameter LABEL_WIDTH = 3;

reg [2:0] state;
reg [15:0] perm_count;
reg [LABEL_WIDTH-1:0] current_perm [0:MAX_N-1];
reg [LABEL_WIDTH-1:0] elf_index;
reg [7:0] available_dwarves;
reg [STRENGTH_WIDTH-1:0] max_victories;
reg [STRENGTH_WIDTH-1:0] current_victories;
reg [2:0] N_val;
reg [7:0] A_reg [0:7];
reg [15:0] P_reg [0:7];
reg [15:0] V_reg [0:7];
reg [2:0] assigned_dwarves [0:MAX_N-1];

localparam IDLE = 3'b000;
localparam INIT_PERM = 3'b001;
localparam NEXT_PERM = 3'b010;
localparam SIM_SEAT = 3'b011;
localparam SEAT_ELF = 3'b100;
localparam COUNT_WINS = 3'b101;
localparam UPDATE_MAX = 3'b110;
localparam DONE = 3'b111;

always @(posedge clk) begin
    if (!rst_n) begin
        state <= IDLE;
        perm_count <= 0;
        elf_index <= 0;
        available_dwarves <= 8'b11111111;
        max_victories <= 0;
        current_victories <= 0;
        N_val <= 0;
        A_reg <= 0;
        P_reg <= 0;
        V_reg <= 0;
        current_perm <= {LABEL_WIDTH-1{0}};
        assigned_dwarves <= {LABEL_WIDTH-1{0}};
    end else begin
        case (state)
            IDLE: if (start) state = INIT_PERM;
            INIT_PERM: state = SIM_SEAT;
            SIM_SEAT: state = SEAT_ELF;
            SEAT_ELF: state = COUNT_WINS;
            COUNT_WINS: state = DONE;
            DONE: ;
        endcase
    end
end

endmodule