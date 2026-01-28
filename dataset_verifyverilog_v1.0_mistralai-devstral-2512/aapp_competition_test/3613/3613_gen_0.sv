module kindergarten_partition(
    input clk,
    input rst_n,
    input start,
    input [1:0] current_teacher [0:15],
    input [3:0] pref_list [0:15][0:15],
    input [15:0] valid_kids,
    output reg [3:0] result_t,
    output reg done,
    output reg found
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] SEARCH_T = 3'd1;
    localparam [2:0] CHECK_PARTITION = 3'd2;
    localparam [2:0] DONE_STATE = 3'd3;

    reg [2:0] state, next_state;

    // Registered inputs
    reg [1:0] current_teacher_reg [0:15];
    reg [3:0] pref_list_reg [0:15][0:15];
    reg [15:0] valid_kids_reg;

    // T counter (0-15)
    reg [3:0] t_counter;

    // Partition state (3^16 possibilities)
    reg [31:0] partition_state;
    reg [3:0] partition_index;

    // Internal signals
    reg [3:0] kid_counter;
    reg [3:0] classmate_counter;
    reg partition_valid;
    reg t_found;

    // Initialize all registers
    integer i, j;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            result_t <= 4'd0;
            done <= 1'b0;
            found <= 1'b0;
            t_counter <= 4'd0;
            partition_state <= 32'd0;
            partition_index <= 4'd0;
            kid_counter <= 4'd0;
            classmate_counter <= 4'd0;
            partition_valid <= 1'b1;
            t_found <= 1'b0;

            // Initialize registered inputs
            for (i = 0; i < 16; i = i + 1) begin
                current_teacher_reg[i] <= 2'd0;
                for (j = 0; j < 16; j = j + 1) begin
                    pref_list_reg[i][j] <= 4'd0;
                end
            end
            valid_kids_reg <= 16'd0;
        end else begin
            // Register inputs
            for (i = 0; i < 16; i = i + 1) begin
                current_teacher_reg[i] <= current_teacher[i];
                for (j = 0; j < 16; j = j + 1) begin
                    pref_list_reg[i][j] <= pref_list[i][j];
                end
            end
            valid_kids_reg <= valid_kids;

            // State machine
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    found <= 1'b0;
                    t_found <= 1'b0;
                    if (start) begin
                        next_state <= SEARCH_T;
                        t_counter <= 4'd0;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                SEARCH_T: begin
                    if (t_counter == 4'd16) begin
                        // No solution found
                        result_t <= 4'd15;
                        found <= 1'b0;
                        next_state <= DONE_STATE;
                    end else begin
                        partition_state <= 32'd0;
                        partition_index <= 4'd0;
                        partition_valid <= 1'b1;
                        next_state <= CHECK_PARTITION;
                    end
                end

                CHECK_PARTITION: begin
                    // Check if partition is valid
                    if (partition_valid) begin
                        // Check teacher constraints
                        reg teacher_ok;
                        teacher_ok = 1'b1;
                        for (i = 0; i < 16; i = i + 1) begin
                            if (valid_kids_reg[i]) begin
                                reg [1:0] assigned_teacher;
                                assigned_teacher = partition_state[(i*2)+1:i*2];
                                if (assigned_teacher == current_teacher_reg[i]) begin
                                    teacher_ok = 1'b0;
                                end
                            end
                        end

                        // Check preference constraints
                        reg pref_ok;
                        pref_ok = 1'b1;
                        for (i = 0; i < 16; i = i + 1) begin
                            if (valid_kids_reg[i]) begin
                                for (j = i + 1; j < 16; j = j + 1) begin
                                    if (valid_kids_reg[j]) begin
                                        reg [1:0] teacher_i, teacher_j;
                                        teacher_i = partition_state[(i*2)+1:i*2];
                                        teacher_j = partition_state[(j*2)+1:j*2];
                                        if (teacher_i == teacher_j) begin
                                            if (pref_list_reg[i][j] >= t_counter || pref_list_reg[j][i] >= t_counter) begin
                                                pref_ok = 1'b0;
                                            end
                                        end
                                    end
                                end
                            end
                        end

                        if (teacher_ok && pref_ok) begin
                            t_found <= 1'b1;
                            result_t <= t_counter;
                            found <= 1'b1;
                            next_state <= DONE_STATE;
                        end else begin
                            // Move to next partition
                            partition_index <= partition_index + 4'd1;
                            if (partition_index == 4'd1) begin
                                partition_state <= partition_state + 32'd1;
                            end else if (partition_index == 4'd2) begin
                                partition_state <= partition_state + 32'd3;
                            end else if (partition_index == 4'd3) begin
                                partition_state <= partition_state + 32'd9;
                            end else if (partition_index == 4'd4) begin
                                partition_state <= partition_state + 32'd27;
                            end else if (partition_index == 4'd5) begin
                                partition_state <= partition_state + 32'd81;
                            end else if (partition_index == 4'd6) begin
                                partition_state <= partition_state + 32'd243;
                            end else if (partition_index == 4'd7) begin
                                partition_state <= partition_state + 32'd729;
                            end else if (partition_index == 4'd8) begin
                                partition_state <= partition_state + 32'd2187;
                            end else if (partition_index == 4'd9) begin
                                partition_state <= partition_state + 32'd6561;
                            end else if (partition_index == 4'd10) begin
                                partition_state <= partition_state + 32'd19683;
                            end else if (partition_index == 4'd11) begin
                                partition_state <= partition_state + 32'd59049;
                            end else if (partition_index == 4'd12) begin
                                partition_state <= partition_state + 32'd177147;
                            end else if (partition_index == 4'd13) begin
                                partition_state <= partition_state + 32'd531441;
                            end else if (partition_index == 4'd14) begin
                                partition_state <= partition_state + 32'd1594323;
                            end else if (partition_index == 4'd15) begin
                                partition_state <= partition_state + 32'd4782969;
                                partition_index <= 4'd0;
                                t_counter <= t_counter + 4'd1;
                                next_state <= SEARCH_T;
                            end
                        end
                    end else begin
                        // Move to next partition
                        partition_index <= partition_index + 4'd1;
                        if (partition_index == 4'd1) begin
                            partition_state <= partition_state + 32'd1;
                        end else if (partition_index == 4'd2) begin
                            partition_state <= partition_state + 32'd3;
                        end else if (partition_index == 4'd3) begin
                            partition_state <= partition_state + 32'd9;
                        end else if (partition_index == 4'd4) begin
                            partition_state <= partition_state + 32'd27;
                        end else if (partition_index == 4'd5) begin
                            partition_state <= partition_state + 32'd81;
                        end else if (partition_index == 4'd6) begin
                            partition_state <= partition_state + 32'd243;
                        end else if (partition_index == 4'd7) begin
                            partition_state <= partition_state + 32'd729;
                        end else if (partition_index == 4'd8) begin
                            partition_state <= partition_state + 32'd2187;
                        end else if (partition_index == 4'd9) begin
                            partition_state <= partition_state + 32'd6561;
                        end else if (partition_index == 4'd10) begin
                            partition_state <= partition_state + 32'd19683;
                        end else if (partition_index == 4'd11) begin
                            partition_state <= partition_state + 32'd59049;
                        end else if (partition_index == 4'd12) begin
                            partition_state <= partition_state + 32'd177147;
                        end else if (partition_index == 4'd13) begin
                            partition_state <= partition_state + 32'd531441;
                        end else if (partition_index == 4'd14) begin
                            partition_state <= partition_state + 32'd1594323;
                        end else if (partition_index == 4'd15) begin
                            partition_state <= partition_state + 32'd4782969;
                            partition_index <= 4'd0;
                            t_counter <= t_counter + 4'd1;
                            next_state <= SEARCH_T;
                        end
                    end
                end

                DONE_STATE: begin
                    done <= 1'b1;
                    next_state <= IDLE;
                end

                default: next_state <= IDLE;
            endcase
            state <= next_state;
        end
    end

endmodule