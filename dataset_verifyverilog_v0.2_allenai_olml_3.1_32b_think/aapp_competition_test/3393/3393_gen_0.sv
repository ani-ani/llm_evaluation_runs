module course_scheduler (input clk, input rst_n, input start, input [2:0] k, input [3:0] valid_mask, input [9:0] course_difficulty_0_i, input [9:0] course_difficulty_0_ii, input [9:0] course_difficulty_1_i, input [9:0] course_difficulty_1_ii, input [9:0] course_difficulty_2_i, input [9:0] course_difficulty_2_ii, input [9:0] course_difficulty_3_i, input [9:0] course_difficulty_3_ii, output reg [15:0] min_sum, output reg done, output reg error );

// Internal registers
reg [1:0] state;
reg [2:0] k_reg;
reg [3:0] valid_mask_reg;
reg [9:0] course_difficulty_0_i_reg;
reg [9:0] course_difficulty_0_ii_reg;
reg [9:0] course_difficulty_1_i_reg;
reg [9:0] course_difficulty_1_ii_reg;
reg [9:0] course_difficulty_2_i_reg;
reg [9:0] course_difficulty_2_ii_reg;
reg [9:0] course_difficulty_3_i_reg;
reg [9:0] course_difficulty_3_ii_reg;
reg [15:0] min_sum_reg;
reg [3:0] combo_index;
reg done_reg, error_reg;

// Outputs assignment
assign min_sum = min_sum_reg;
assign done = done_reg;
assign error = error_reg;

// Combinational signals for COMPUTE state
wire [3:0] total_courses;
wire [18:0] total_diff;
wire update_min;

always @(*) begin
    assign total_courses = (combo_index[0] ? 2 :0) + (combo_index[1] ? 2 :0) + (combo_index[2] ? 2 :0) + (combo_index[3] ? 2 :0);
    assign total_diff = (combo_index[0] ? (course_difficulty_0_i_reg + course_difficulty_0_ii_reg) : 0) +
        (combo_index[1] ? (course_difficulty_1_i_reg + course_difficulty_1_ii_reg) : 0) +
        (combo_index[2] ? (course_difficulty_2_i_reg + course_difficulty_2_ii_reg) : 0) +
        (combo_index[3] ? (course_difficulty_3_i_reg + course_difficulty_3_ii_reg) : 0);
    assign update_min = (total_courses == k_reg) && (total_diff < min_sum_reg);
end

always @(posedge clk) begin
    if (!rst_n) begin
        state <= 2'b00;
        k_reg <= 3'b000;
        valid_mask_reg <= 4'b0000;
        course_difficulty_0_i_reg <= 10'b0000000000;
        course_difficulty_0_ii_reg <= 10'b0000000000;
        course_difficulty_1_i_reg <= 10'b0000000000;
        course_difficulty_1_ii_reg <= 10'b0000000000;
        course_difficulty_2_i_reg <= 10'b0000000000;
        course_difficulty_2_ii_reg <= 10'b0000000000;
        course_difficulty_3_i_reg <= 10'b0000000000;
        course_difficulty_3_ii_reg <= 10'b0000000000;
        min_sum_reg <= 16'd8191;
        combo_index <= 4'd0;
        done_reg <= 1'b0;
        error_reg <= 1'b0;
    end else begin
        if (state == 2'b00) begin
            if (start) begin
                k_reg <= k;
                valid_mask_reg <= valid_mask;
                course_difficulty_0_i_reg <= course_difficulty_0_i;
                course_difficulty_0_ii_reg <= course_difficulty_0_ii;
                course_difficulty_1_i_reg <= course_difficulty_1_i;
                course_difficulty_1_ii_reg <= course_difficulty_1_ii;
                course_difficulty_2_i_reg <= course_difficulty_2_i;
                course_difficulty_2_ii_reg <= course_difficulty_2_ii;
                course_difficulty_3_i_reg <= course_difficulty_3_i;
                course_difficulty_3_ii_reg <= course_difficulty_3_ii;
                state <= 2'b01;
            end
        end else if (state == 2'b01) begin
            if (combo_index < 4'd15) begin
                if (update_min) begin
                    min_sum_reg <= total_diff;
                end
                combo_index <= combo_index + 1;
            end else begin
                if (min_sum_reg == 16'd8191) begin
                    error_reg <= 1'b1;
                end
                done_reg <= 1'b1;
                state <= 2'b10;
            end
        end else if (state == 2'b10) begin
            state <= 2'b10;
        end
    end
endmodule