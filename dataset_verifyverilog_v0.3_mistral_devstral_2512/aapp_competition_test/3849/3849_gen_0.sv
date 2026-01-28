module duel_game (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] initial_state,
    input wire [3:0] k,
    output reg [1:0] result,
    output reg done
);

    // State definitions
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] PLAY = 2'd1;
    localparam [1:0] FINISH = 2'd2;

    // Internal registers
    reg [1:0] state;
    reg [7:0] current_state;
    reg [7:0] cycle_count;
    reg [1:0] winner;
    reg [7:0] history [0:15];
    reg [3:0] history_idx;
    reg [7:0] i;

    // Helper wires
    wire all_same = (current_state == 8'd0) || (current_state == 8'd255);
    wire can_win = check_win(current_state, k);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            current_state <= 8'd0;
            cycle_count <= 8'd0;
            winner <= 2'd0;
            done <= 1'b0;
            result <= 2'd0;
            history_idx <= 4'd0;
            for (i = 0; i < 16; i = i + 1) begin
                history[i] <= 8'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        current_state <= initial_state;
                        cycle_count <= 8'd0;
                        history_idx <= 4'd0;
                        for (i = 0; i < 16; i = i + 1) begin
                            history[i] <= 8'd0;
                        end
                        if (all_same) begin
                            winner <= 2'd0;  // Tokitsukaze
                            state <= FINISH;
                        end else begin
                            state <= PLAY;
                        end
                    end
                end

                PLAY: begin
                    if (cycle_count >= 8'd255) begin
                        winner <= 2'd2;  // Draw
                        state <= FINISH;
                    end else if (can_win) begin
                        winner <= (cycle_count[0] == 1'b0) ? 2'd0 : 2'd1;
                        state <= FINISH;
                    end else begin
                        // Check for cycles
                        reg found = 1'b0;
                        for (i = 0; i < history_idx; i = i + 1) begin
                            if (history[i] == current_state) begin
                                found = 1'b1;
                            end
                        end
                        if (found) begin
                            winner <= 2'd2;  // Draw
                            state <= FINISH;
                        end else begin
                            // Make move
                            current_state <= make_move(current_state, k, cycle_count[0]);
                            history[history_idx] <= current_state;
                            history_idx <= history_idx + 4'd1;
                            cycle_count <= cycle_count + 8'd1;
                        end
                    end
                end

                FINISH: begin
                    done <= 1'b1;
                    case (winner)
                        2'd0: result <= 2'd0;  // Tokitsukaze
                        2'd1: result <= 2'd1;  // Quailty
                        2'd2: result <= 2'd2;  // Draw
                        default: result <= 2'd0;
                    endcase
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

    function automatic [7:0] make_move;
        input [7:0] state;
        input [3:0] k_val;
        input player;
        integer j;
        begin
            make_move = state;
            for (j = 0; j < k_val && j < 8; j = j + 1) begin
                make_move[j] = player ? 1'b1 : 1'b0;
            end
        end
    endfunction

    function automatic check_win;
        input [7:0] state;
        input [3:0] k_val;
        integer i, j;
        reg [7:0] test_state;
        begin
            check_win = 1'b0;
            for (i = 0; i <= 8 - k_val; i = i + 1) begin
                // Try flipping to 0
                test_state = state;
                for (j = 0; j < k_val; j = j + 1) begin
                    test_state[i+j] = 1'b0;
                end
                if (test_state == 8'd0 || test_state == 8'd255) begin
                    check_win = 1'b1;
                    return 1'b1;
                end
                // Try flipping to 1
                test_state = state;
                for (j = 0; j < k_val; j = j + 1) begin
                    test_state[i+j] = 1'b1;
                end
                if (test_state == 8'd0 || test_state == 8'd255) begin
                    check_win = 1'b1;
                    return 1'b1;
                end
            end
        end
    endfunction

endmodule