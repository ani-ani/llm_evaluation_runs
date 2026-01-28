module ZerglingRush(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] config_addr,
    input wire [7:0] config_data,
    input wire [7:0] map_data,
    output reg ready,
    output reg done,
    output reg [7:0] result_addr,
    output reg [7:0] result_data
);

    // Parameters
    localparam [2:0] MAX_N = 3'd8;
    localparam [3:0] MAX_ZERGLINGS = 4'd16;
    localparam [7:0] MAX_CYCLES = 8'd256;

    // State definitions
    localparam [3:0] IDLE = 4'd0;
    localparam [3:0] LOAD_CONFIG = 4'd1;
    localparam [3:0] LOAD_MAP = 4'd2;
    localparam [3:0] SIM_START = 4'd3;
    localparam [3:0] SIM_TURN_DECISION = 4'd4;
    localparam [3:0] SIM_TURN_ATTACK = 4'd5;
    localparam [3:0] SIM_TURN_MOVE = 4'd6;
    localparam [3:0] SIM_TURN_REGEN = 4'd7;
    localparam [3:0] SIM_DONE = 4'd8;
    localparam [3:0] OUTPUT_READ = 4'd9;

    // Configuration registers
    reg [2:0] N;
    reg [7:0] P1_Attack_Upg;
    reg [7:0] P1_Armor_Upg;
    reg [7:0] P2_Attack_Upg;
    reg [7:0] P2_Armor_Upg;
    reg [7:0] Turns;

    // Grid storage (2 banks)
    reg [7:0] grid_a [0:63];
    reg [7:0] grid_b [0:63];
    reg [7:0] grid_c [0:63];
    reg [7:0] grid_d [0:63];

    // Internal registers
    reg [3:0] state;
    reg [7:0] map_counter;
    reg [7:0] turn_counter;
    reg [7:0] cycle_counter;
    reg [7:0] x_counter;
    reg [7:0] y_counter;
    reg [7:0] z_counter;
    reg [7:0] output_counter;

    // FSM
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            ready <= 1'b0;
            done <= 1'b0;
            result_addr <= 8'd0;
            result_data <= 8'd0;
            map_counter <= 8'd0;
            turn_counter <= 8'd0;
            cycle_counter <= 8'd0;
            x_counter <= 8'd0;
            y_counter <= 8'd0;
            z_counter <= 8'd0;
            output_counter <= 8'd0;
            N <= 3'd0;
            P1_Attack_Upg <= 8'd0;
            P1_Armor_Upg <= 8'd0;
            P2_Attack_Upg <= 8'd0;
            P2_Armor_Upg <= 8'd0;
            Turns <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    ready <= 1'b0;
                    done <= 1'b0;
                    if (start) begin
                        state <= LOAD_CONFIG;
                    end
                end

                LOAD_CONFIG: begin
                    ready <= 1'b0;
                    case (config_addr)
                        4'd0: N <= config_data[2:0];
                        4'd1: P1_Attack_Upg <= config_data;
                        4'd2: P1_Armor_Upg <= config_data;
                        4'd3: P2_Attack_Upg <= config_data;
                        4'd4: P2_Armor_Upg <= config_data;
                        4'd5: Turns <= config_data;
                        default: ;
                    endcase
                    if (N != 3'd0 && Turns != 8'd0) begin
                        state <= LOAD_MAP;
                        ready <= 1'b1;
                    end
                end

                LOAD_MAP: begin
                    ready <= 1'b1;
                    if (map_counter < (N * N)) begin
                        grid_a[map_counter] <= map_data;
                        map_counter <= map_counter + 8'd1;
                    end else begin
                        ready <= 1'b0;
                        state <= SIM_START;
                    end
                end

                SIM_START: begin
                    turn_counter <= 8'd0;
                    state <= SIM_TURN_DECISION;
                end

                SIM_TURN_DECISION: begin
                    // Decision phase logic
                    state <= SIM_TURN_ATTACK;
                end

                SIM_TURN_ATTACK: begin
                    // Attack resolution logic
                    state <= SIM_TURN_MOVE;
                end

                SIM_TURN_MOVE: begin
                    // Movement resolution logic
                    state <= SIM_TURN_REGEN;
                end

                SIM_TURN_REGEN: begin
                    // Regeneration logic
                    turn_counter <= turn_counter + 8'd1;
                    if (turn_counter >= Turns) begin
                        state <= SIM_DONE;
                    end else begin
                        state <= SIM_TURN_DECISION;
                    end
                end

                SIM_DONE: begin
                    done <= 1'b1;
                    state <= OUTPUT_READ;
                end

                OUTPUT_READ: begin
                    if (output_counter < (N * N)) begin
                        result_addr <= output_counter;
                        result_data <= grid_a[output_counter];
                        output_counter <= output_counter + 8'd1;
                    end else begin
                        output_counter <= 8'd0;
                    end
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule