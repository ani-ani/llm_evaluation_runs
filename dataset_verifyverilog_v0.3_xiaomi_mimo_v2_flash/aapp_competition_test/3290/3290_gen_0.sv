module exploding_kittens (
    input clk,
    input rst_n,
    input start,
    input [3:0] N,
    input [3:0] E,
    input [3:0] D,
    input [7:0] e_pos_0, e_pos_1, e_pos_2, e_pos_3, e_pos_4, e_pos_5, e_pos_6, e_pos_7,
    input [7:0] d_pos_0, d_pos_1, d_pos_2, d_pos_3, d_pos_4, d_pos_5, d_pos_6, d_pos_7,
    output reg [7:0] winner,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE = 3'b000;
    localparam [2:0] INIT = 3'b001;
    localparam [2:0] LOOP = 3'b010;
    localparam [2:0] PROCESS = 3'b011;
    localparam [2:0] NEXT_PLAYER = 3'b100;
    localparam [2:0] NEXT_POS = 3'b101;
    localparam [2:0] FINISH = 3'b110;

    // Registers for state
    reg [2:0] state, next_state;
    reg [7:0] cycle_counter;
    localparam [7:0] MAX_CYCLE = 8'd200;

    // Game registers
    reg [7:0] current_position;
    reg [7:0] max_position;
    reg [2:0] current_player;
    reg [3:0] alive_count;
    reg [2:0] hand_total [0:7];
    reg [2:0] hand_defuse [0:7];
    reg alive [0:7];
    reg [7:0] winner_temp;

    // Combinational signals
    reg is_exploding;
    reg is_defuse;
    reg [2:0] next_alive_idx;

    integer i;

    // Combinational logic for card detection
    always @(*) begin
        is_exploding = 0;
        is_defuse = 0;
        // Check Exploding positions
        if (E > 0 && e_pos_0 == current_position) is_exploding = 1;
        if (E > 1 && e_pos_1 == current_position) is_exploding = 1;
        if (E > 2 && e_pos_2 == current_position) is_exploding = 1;
        if (E > 3 && e_pos_3 == current_position) is_exploding = 1;
        if (E > 4 && e_pos_4 == current_position) is_exploding = 1;
        if (E > 5 && e_pos_5 == current_position) is_exploding = 1;
        if (E > 6 && e_pos_6 == current_position) is_exploding = 1;
        if (E > 7 && e_pos_7 == current_position) is_exploding = 1;
        // Check Defuse positions
        if (D > 0 && d_pos_0 == current_position) is_defuse = 1;
        if (D > 1 && d_pos_1 == current_position) is_defuse = 1;
        if (D > 2 && d_pos_2 == current_position) is_defuse = 1;
        if (D > 3 && d_pos_3 == current_position) is_defuse = 1;
        if (D > 4 && d_pos_4 == current_position) is_defuse = 1;
        if (D > 5 && d_pos_5 == current_position) is_defuse = 1;
        if (D > 6 && d_pos_6 == current_position) is_defuse = 1;
        if (D > 7 && d_pos_7 == current_position) is_defuse = 1;
    end

    // Combinational logic for next alive player
    always @(*) begin
        next_alive_idx = current_player;
        // Search for next alive player
        for (i = 1; i <= 8; i = i + 1) begin
            reg [2:0] candidate;
            if (current_player + i >= N)
                candidate = current_player + i - N;
            else
                candidate = current_player + i;
            if (alive[candidate]) begin
                next_alive_idx = candidate;
                break;
            end
        end
    end

    // State transition
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end

    always @(*) begin
        next_state = state;
        case (state)
            IDLE: if (start) next_state = INIT;
            INIT: next_state = LOOP;
            LOOP: begin
                if (alive_count <= 1 || current_position > max_position)
                    next_state = FINISH;
                else
                    next_state = PROCESS;
            end
            PROCESS: next_state = NEXT_PLAYER;
            NEXT_PLAYER: next_state = NEXT_POS;
            NEXT_POS: next_state = LOOP;
            FINISH: next_state = FINISH;
            default: next_state = IDLE;
        endcase
    end

    // Main sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all
            for (i = 0; i < 8; i = i + 1) begin
                hand_total[i] <= 0;
                hand_defuse[i] <= 0;
                alive[i] <= 0;
            end
            current_position <= 0;
            max_position <= 0;
            current_player <= 0;
            alive_count <= 0;
            winner <= 8'hFF;
            done <= 0;
            cycle_counter <= 0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 0;
                    cycle_counter <= 0;
                end

                INIT: begin
                    // Initialize player states
                    for (i = 0; i < 8; i = i + 1) begin
                        if (i < N) begin
                            alive[i] <= 1;
                            hand_total[i] <= 0;
                            hand_defuse[i] <= 0;
                        end else begin
                            alive[i] <= 0;
                            hand_total[i] <= 0;
                            hand_defuse[i] <= 0;
                        end
                    end
                    alive_count <= N;
                    current_player <= 0;
                    current_position <= 0;
                    max_position <= 0;
                    // Find max position from all cards
                    if (E > 0 && e_pos_0 > max_position) max_position <= e_pos_0;
                    if (E > 1 && e_pos_1 > max_position) max_position <= e_pos_1;
                    if (E > 2 && e_pos_2 > max_position) max_position <= e_pos_2;
                    if (E > 3 && e_pos_3 > max_position) max_position <= e_pos_3;
                    if (E > 4 && e_pos_4 > max_position) max_position <= e_pos_4;
                    if (E > 5 && e_pos_5 > max_position) max_position <= e_pos_5;
                    if (E > 6 && e_pos_6 > max_position) max_position <= e_pos_6;
                    if (E > 7 && e_pos_7 > max_position) max_position <= e_pos_7;
                    if (D > 0 && d_pos_0 > max_position) max_position <= d_pos_0;
                    if (D > 1 && d_pos_1 > max_position) max_position <= d_pos_1;
                    if (D > 2 && d_pos_2 > max_position) max_position <= d_pos_2;
                    if (D > 3 && d_pos_3 > max_position) max_position <= d_pos_3;
                    if (D > 4 && d_pos_4 > max_position) max_position <= d_pos_4;
                    if (D > 5 && d_pos_5 > max_position) max_position <= d_pos_5;
                    if (D > 6 && d_pos_6 > max_position) max_position <= d_pos_6;
                    if (D > 7 && d_pos_7 > max_position) max_position <= d_pos_7;
                    winner <= 8'hFF;
                end

                PROCESS: begin
                    // Process card at current_position for current_player
                    if (alive[current_player]) begin
                        if (is_exploding) begin
                            if (hand_defuse[current_player] > 0) begin
                                // Use Defuse
                                hand_defuse[current_player] <= hand_defuse[current_player] - 1;
                                hand_total[current_player] <= hand_total[current_player] - 1;
                            end else begin
                                // Player leaves
                                alive[current_player] <= 0;
                                alive_count <= alive_count - 1;
                            end
                        end else if (is_defuse) begin
                            // Draw Defuse
                            if (hand_total[current_player] < 5) begin
                                hand_defuse[current_player] <= hand_defuse[current_player] + 1;
                                hand_total[current_player] <= hand_total[current_player] + 1;
                            end else begin
                                // Discard logic
                                if ((hand_total[current_player] - hand_defuse[current_player]) > 0) begin
                                    // Have neutral cards, discard neutral
                                    hand_defuse[current_player] <= hand_defuse[current_player] + 1;
                                    // Total remains 5
                                end else begin
                                    // Only Defuse cards, discard Defuse (net zero change in defuse)
                                    // Draw Defuse: defuse+1, total+1 -> 6
                                    // Discard Defuse: defuse-1, total-1 -> 5
                                    // Net: defuse unchanged, total unchanged
                                    // But we drew and discarded, so no change.
                                end
                            end
                        end else begin
                            // Neutral card
                            if (hand_total[current_player] < 5) begin
                                hand_total[current_player] <= hand_total[current_player] + 1;
                            end else begin
                                // Discard logic
                                if ((hand_total[current_player] - hand_defuse[current_player]) > 0) begin
                                    // Have neutral cards, discard neutral (net zero change in total)
                                    // Total becomes 6, discard 1 neutral -> 5
                                end else begin
                                    // Only Defuse cards, discard Defuse
                                    hand_defuse[current_player] <= hand_defuse[current_player] - 1;
                                    // Total stays 5
                                end
                            end
                        end
                    end
                    // Check for timeout
                    cycle_counter <= cycle_counter + 1;
                end

                NEXT_PLAYER: begin
                    if (alive_count > 1) begin
                        current_player <= next_alive_idx;
                    end
                end

                NEXT_POS: begin
                    current_position <= current_position + 1;
                end

                FINISH: begin
                    done <= 1;
                    // Determine winner
                    if (alive_count == 1) begin
                        for (i = 0; i < 8; i = i + 1) begin
                            if (alive[i]) winner <= i;
                        end
                    end else begin
                        winner <= 8'hFF;
                    end
                end

                default: begin
                    // No action
                end
            endcase
        end
    end

endmodule