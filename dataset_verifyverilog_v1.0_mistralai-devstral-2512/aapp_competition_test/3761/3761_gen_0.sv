module robot_nav(
    input clk,
    input rst_n,
    input start,
    input [7:0] instruction,
    input signed [15:0] target_x,
    input signed [15:0] target_y,
    output reg result,
    output reg done
);

    // Parameters
    localparam [15:0] MAX_SUM = 16'd16000;
    localparam [15:0] OFFSET = 16'd8000;
    localparam [15:0] MAX_MOVES = 16'd4000;

    // States
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] PARSE = 3'd1;
    localparam [2:0] DP_X = 3'd2;
    localparam [2:0] DP_Y = 3'd3;
    localparam [2:0] CHECK = 3'd4;

    // State machine
    reg [2:0] state;
    reg [15:0] move_count_x;
    reg [15:0] move_count_y;
    reg [15:0] current_move_x;
    reg [15:0] current_move_y;
    reg [15:0] move_list_x [0:3999];
    reg [15:0] move_list_y [0:3999];
    reg [15:0] move_length;
    reg [15:0] turn_count;
    reg [15:0] i;
    reg [15:0] j;
    reg [15:0] k;
    reg [15:0] temp_sum;
    reg [15:0] first_move_x;
    reg first_move_fixed;

    // DP bitset for X and Y
    reg [16000:0] dp_x;
    reg [16000:0] dp_y;

    // DP state
    reg [15:0] dp_index_x;
    reg [15:0] dp_index_y;

    // Initialization
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            move_count_x <= 16'd0;
            move_count_y <= 16'd0;
            current_move_x <= 16'd0;
            current_move_y <= 16'd0;
            move_length <= 16'd0;
            turn_count <= 16'd0;
            i <= 16'd0;
            j <= 16'd0;
            k <= 16'd0;
            temp_sum <= 16'd0;
            first_move_x <= 16'd0;
            first_move_fixed <= 1'b0;
            dp_index_x <= 16'd0;
            dp_index_y <= 16'd0;
            result <= 1'b0;
            done <= 1'b0;

            // Initialize DP bitsets
            for (i = 0; i <= MAX_SUM; i = i + 1) begin
                dp_x[i] <= 1'b0;
                dp_y[i] <= 1'b0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= PARSE;
                        move_count_x <= 16'd0;
                        move_count_y <= 16'd0;
                        move_length <= 16'd0;
                        turn_count <= 16'd0;
                        first_move_fixed <= 1'b0;
                        first_move_x <= 16'd0;
                    end
                end

                PARSE: begin
                    // Parse instruction string
                    if (instruction == 8'd'F') begin
                        move_length <= move_length + 16'd1;
                    end else if (instruction == 8'd'T') begin
                        // Store move length based on turn count parity
                        if (turn_count % 2 == 0) begin
                            // X-axis move
                            if (move_count_x < MAX_MOVES) begin
                                move_list_x[move_count_x] <= move_length;
                                move_count_x <= move_count_x + 16'd1;
                            end
                            if (!first_move_fixed) begin
                                first_move_x <= move_length;
                                first_move_fixed <= 1'b1;
                            end
                        end else begin
                            // Y-axis move
                            if (move_count_y < MAX_MOVES) begin
                                move_list_y[move_count_y] <= move_length;
                                move_count_y <= move_count_y + 16'd1;
                            end
                        end
                        move_length <= 16'd0;
                        turn_count <= turn_count + 16'd1;
                    end else begin
                        // End of string
                        state <= DP_X;
                        dp_index_x <= 16'd0;
                        dp_index_y <= 16'd0;

                        // Initialize DP for X-axis
                        if (first_move_fixed) begin
                            dp_x[first_move_x + OFFSET] <= 1'b1;
                        end else begin
                            dp_x[OFFSET] <= 1'b1;
                        end
                    end
                end

                DP_X: begin
                    // Process X-axis moves
                    if (dp_index_x < move_count_x) begin
                        // Shift and OR for current move
                        for (i = 0; i <= MAX_SUM; i = i + 1) begin
                            if (dp_x[i]) begin
                                temp_sum <= i - OFFSET + move_list_x[dp_index_x];
                                if (temp_sum >= -8000 && temp_sum <= 8000) begin
                                    dp_x[temp_sum + OFFSET] <= 1'b1;
                                end
                                temp_sum <= i - OFFSET - move_list_x[dp_index_x];
                                if (temp_sum >= -8000 && temp_sum <= 8000) begin
                                    dp_x[temp_sum + OFFSET] <= 1'b1;
                                end
                            end
                        end
                        dp_index_x <= dp_index_x + 16'd1;
                    end else begin
                        state <= DP_Y;
                        dp_index_y <= 16'd0;
                        dp_y[OFFSET] <= 1'b1;
                    end
                end

                DP_Y: begin
                    // Process Y-axis moves
                    if (dp_index_y < move_count_y) begin
                        // Shift and OR for current move
                        for (i = 0; i <= MAX_SUM; i = i + 1) begin
                            if (dp_y[i]) begin
                                temp_sum <= i - OFFSET + move_list_y[dp_index_y];
                                if (temp_sum >= -8000 && temp_sum <= 8000) begin
                                    dp_y[temp_sum + OFFSET] <= 1'b1;
                                end
                                temp_sum <= i - OFFSET - move_list_y[dp_index_y];
                                if (temp_sum >= -8000 && temp_sum <= 8000) begin
                                    dp_y[temp_sum + OFFSET] <= 1'b1;
                                end
                            end
                        end
                        dp_index_y <= dp_index_y + 16'd1;
                    end else begin
                        state <= CHECK;
                    end
                end

                CHECK: begin
                    // Check if target is reachable
                    if (first_move_fixed) begin
                        result <= dp_x[target_x + OFFSET] && dp_y[target_y + OFFSET];
                    end else begin
                        result <= dp_x[target_x + OFFSET] && dp_y[target_y + OFFSET];
                    end
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule