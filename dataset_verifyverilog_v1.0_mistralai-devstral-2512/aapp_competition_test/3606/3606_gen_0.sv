module frog_jump(
    input clk,
    input rst_n,
    input start,
    input [15:0] plant_x [0:15],
    input [15:0] plant_y [0:15],
    input [63:0] dir_seq,
    input [3:0] num_plants,
    input [3:0] num_jumps,
    output reg [15:0] final_x,
    output reg [15:0] final_y,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] LOAD = 3'd1;
    localparam [2:0] JUMP = 3'd2;
    localparam [2:0] FINISH = 3'd3;

    reg [2:0] state, next_state;
    reg [3:0] jump_count;
    reg [3:0] current_index;
    reg [3:0] dir_index;
    reg [3:0] scan_index;
    reg [15:0] current_x, current_y;
    reg found;

    // Internal plant storage
    reg [15:0] plants_x [0:15];
    reg [15:0] plants_y [0:15];

    // Direction parsing
    wire [3:0] current_dir = dir_seq[dir_index*4 +: 4];

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            jump_count <= 4'd0;
            current_index <= 4'd0;
            dir_index <= 4'd0;
            scan_index <= 4'd0;
            current_x <= 16'd0;
            current_y <= 16'd0;
            found <= 1'b0;
            done <= 1'b0;
            final_x <= 16'd0;
            final_y <= 16'd0;
        end else begin
            state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = LOAD;
                end
            end
            LOAD: begin
                next_state = JUMP;
            end
            JUMP: begin
                if (jump_count == num_jumps - 1'b1) begin
                    next_state = FINISH;
                end else begin
                    next_state = JUMP;
                end
            end
            FINISH: begin
                next_state = IDLE;
            end
            default: next_state =