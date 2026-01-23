module frog_regent (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] N,
    input wire [7:0] start_seq [0:15],
    input wire [7:0] target_seq [0:15],
    output reg [7:0] proclamation,
    output reg proclamation_valid,
    output reg done,
    output reg error
);

    // State machine states
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] INIT = 3'd1;
    localparam [2:0] FIND_DIFF = 3'd2;
    localparam [2:0] FIND_FROG = 3'd3;
    localparam [2:0] EXECUTE_LEAPS = 3'd4;
    localparam [2:0] RENORMALIZE = 3'd5;
    localparam [2:0] OUTPUT_PROCLAMATION = 3'd6;
    localparam [2:0] CHECK_DONE = 3'd7;

    reg [2:0] state;
    reg [7:0] current_seq [0:15];
    reg [7:0] target_frog;
    reg [7:0] position;
    reg [7:0] leap_count;
    reg [7:0] diff_index;
    reg [7:0] jump_step;
    reg [7:0] temp_reg;
    reg [7:0] temp_seq_0;
    reg [7:0] temp_seq_1;
    reg [7:0] temp_seq_2;
    reg [7:0] temp_seq_3;
    reg [7:0] temp_seq_4;
    reg [7:0] temp_seq_5;
    reg [7:0] temp_seq_6;
    reg [7:0] temp_seq_7;
    reg [7:0] temp_seq_8;
    reg [7:0] temp_seq_9;
    reg [7:0] temp_seq_10;
    reg [7:0] temp_seq_11;
    reg [7:0] temp_seq_12;
    reg [7:0] temp_seq_13;
    reg [7:0] temp_seq_14;
    reg [7:0] temp_seq_15;
    reg [7:0] loop_counter;
    reg [7:0] temp_pos;
    reg [7:0] renorm_index;
    reg found;
    reg is_equal;

    // State transition logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
        end else begin
            case (state)
                IDLE: if (start) state <= INIT;
                INIT: state <= FIND_DIFF;
                FIND_DIFF: begin
                    if (diff_index >= N) begin
                        state <= CHECK_DONE;
                    end else if (current_seq[diff_index] != target_seq[diff_index]) begin
                        state <= FIND_FROG;
                    end else begin
                        state <= FIND_DIFF;
                    end
                end
                FIND_FROG: state <= EXECUTE_LEAPS;
                EXECUTE_LEAPS: begin
                    if (leap_count == 8'd0) state <= RENORMALIZE;
                    else state <= EXECUTE_LEAPS;
                end
                RENORMALIZE: state <= OUTPUT_PROCLAMATION;
                OUTPUT_PROCLAMATION: state <= CHECK_DONE;
                CHECK_DONE: begin
                    if (diff_index >= N) state <= IDLE;
                    else state <= FIND_DIFF;
                end
                default: state <= IDLE;
            endcase
        end
    end

    // Data path logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            proclamation <= 8'd0;
            proclamation_valid <= 1'b0;
            done <= 1'b0;
            error <= 1'b0;
            for (integer i = 0; i < 16; i = i + 1) begin
                current_seq[i] <= 8'd0;
            end
            target_frog <= 8'd0;
            position <= 8'd0;
            leap_count <= 8'd0;
            diff_index <= 8'd1;
            jump_step <= 8'd0;
            loop_counter <= 8'd0;
            temp_pos <= 8'd0;
            renorm_index <= 8'd0;
            found <= 1'b0;
            is_equal <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    proclamation_valid <= 1'b0;
                    error <= 1'b0;
                end
                INIT: begin
                    for (integer i = 0; i < 16; i = i + 1) begin
                        if (i < N)
                            current_seq[i] <= start_seq[i];
                        else
                            current_seq[i] <= 8'd0;
                    end
                    diff_index <= 8'd1;
                    proclamation_valid <= 1'b0;
                    done <= 1'b0;
                end
                FIND_DIFF: begin
                    if (diff_index < N && current_seq[diff_index] != target_seq[diff_index]) begin
                        target_frog <= target_seq[diff_index];
                    end else if (diff_index < N) begin
                        diff_index <= diff_index + 8'd1;
                    end
                end
                FIND_FROG: begin
                    found <= 1'b0;
                    position <= 8'd0;
                    jump_step <= 8'd1;
                    loop_counter <= 8'd0;
                end
                EXECUTE_LEAPS: begin
                    if (jump_step <= leap_count && !found) begin
                        if (loop_counter < N) begin
                            if (current_seq[loop_counter] == target_frog) begin
                                position <= loop_counter;
                                found <= 1'b1;
                            end
                            loop_counter <= loop_counter + 8'd1;
                        end else begin
                            error <= 1'b1;
                        end
                    end else if (jump_step <= leap_count && found) begin
                        if (position + 8'd1 < N) begin
                            temp_seq_0 <= current_seq[position];
                            temp_seq_1 <= current_seq[position + 8'd1];
                            current_seq[position] <= temp_seq_1;
                            current_seq[position + 8'd1] <= temp_seq_0;
                            position <= position + 8'd1;
                            jump_step <= jump_step + 8'd1;
                            found <= 1'b0;
                            loop_counter <= 8'd0;
                        end else begin
                            error <= 1'b1;
                        end
                    end
                end
                RENORMALIZE: begin
                    if (N > 8'd0 && current_seq[8'd0] != 8'd1) begin
                        temp_seq_0 <= current_seq[0];
                        temp_seq_1 <= current_seq[1];
                        temp_seq_2 <= current_seq[2];
                        temp_seq_3 <= current_seq[3];
                        temp_seq_4 <= current_seq[4];
                        temp_seq_5 <= current_seq[5];
                        temp_seq_6 <= current_seq[6];
                        temp_seq_7 <= current_seq[7];
                        temp_seq_8 <= current_seq[8];
                        temp_seq_9 <= current_seq[9];
                        temp_seq_10 <= current_seq[10];
                        temp_seq_11 <= current_seq[11];
                        temp_seq_12 <= current_seq[12];
                        temp_seq_13 <= current_seq[13];
                        temp_seq_14 <= current_seq[14];
                        temp_seq_15 <= current_seq[15];
                        temp_pos <= 8'd0;
                        renorm_index <= 8'd0;
                    end
                    if (renorm_index < N) begin
                        if (renorm_index < N - temp_pos) begin
                            if (renorm_index == 8'd0) current_seq[renorm_index] <= temp_seq_1;
                            else if (renorm_index == 8'd1) current_seq[renorm_index] <= temp_seq_2;
                            else if (renorm_index == 8'd2) current_seq[renorm_index] <= temp_seq_3;
                            else if (renorm_index == 8'd3) current_seq[renorm_index] <= temp_seq_4;
                            else if (renorm_index == 8'd4) current_seq[renorm_index] <= temp_seq_5;
                            else if (renorm_index == 8'd5) current_seq[renorm_index] <= temp_seq_6;
                            else if (renorm_index == 8'd6) current_seq[renorm_index] <= temp_seq_7;
                            else if (renorm_index == 8'd7) current_seq[renorm_index] <= temp_seq_8;
                            else if (renorm_index == 8'd8) current_seq[renorm_index] <= temp_seq_9;
                            else if (renorm_index == 8'd9) current_seq[renorm_index] <= temp_seq_10;
                            else if (renorm_index == 8'd10) current_seq[renorm_index] <= temp_seq_11;
                            else if (renorm_index == 8'd11) current_seq[renorm_index] <= temp_seq_12;
                            else if (renorm_index == 8'd12) current_seq[renorm_index] <= temp_seq_13;
                            else if (renorm_index == 8'd13) current_seq[renorm_index] <= temp_seq_14;
                            else if (renorm_index == 8'd14) current_seq[renorm_index] <= temp_seq_15;
                            renorm_index <= renorm_index + 8'd1;
                        end else begin
                            if (renorm_index == N - temp_pos) current_seq[renorm_index] <= temp_seq_0;
                            renorm_index <= renorm_index + 8'd1;
                        end
                    end
                end
                OUTPUT_PROCLAMATION: begin
                    proclamation <= target_frog;
                    proclamation_valid <= 1'b1;
                end
                CHECK_DONE: begin
                    proclamation_valid <= 1'b0;
                    if (diff_index >= N) begin
                        done <= 1'b1;
                    end else begin
                        diff_index <= diff_index + 8'd1;
                    end
                end
            endcase
        end
    end

endmodule