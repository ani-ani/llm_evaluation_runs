module boomerang_4x4 (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [1:0] a0, a1, a2, a3,
    output reg done,
    output reg valid,
    output reg target_valid,
    output reg [2:0] target_row,
    output reg [2:0] target_col
);

// Parameters and states
localparam [2:0] IDLE = 3'b000;
localparam [2:0] PROCESS = 3'b001;
localparam [2:0] OUTPUT = 3'b010;
localparam [2:0] NEXT_COLUMN = 3'b011;
localparam [2:0] DONE = 3'b100;
localparam [2:0] ERROR = 3'b101;

// Registers
reg [2:0] state;
reg [1:0] a_reg0, a_reg1, a_reg2, a_reg3;
reg signed [2:0] col_index;
reg [1:0] sp_one;
reg [1:0] sp_two;
reg [1:0] stack_one_row [3:0];
reg [1:0] stack_one_col [3:0];
reg [1:0] stack_two_row [3:0];
reg [1:0] stack_two_col [3:0];
reg [1:0] target1_row, target1_col, target2_row, target2_col;
reg [1:0] remaining_targets;
reg [1:0] output_index;

wire [1:0] a_current;

assign a_current = (col_index == 3) ? a_reg3 :
                   (col_index == 2) ? a_reg2 :
                   (col_index == 1) ? a_reg1 :
                   a_reg0;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        done <= 1'b0;
        valid <= 1'b0;
        target_valid <= 1'b0;
        sp_one <= 2'd0;
        sp_two <= 2'd0;
        col_index <= 3'd3;
        remaining_targets <= 2'd0;
        output_index <= 2'd0;
    end else begin
        case (state)
            IDLE: begin
                if (start) begin
                    a_reg0 <= a0;
                    a_reg1 <= a1;
                    a_reg2 <= a2;
                    a_reg3 <= a3;
                    sp_one <= 2'd0;
                    sp_two <= 2'd0;
                    col_index <= 3'd3;
                    remaining_targets <= 2'd0;
                    output_index <= 2'd0;
                    done <= 1'b0;
                    valid <= 1'b0;
                    target_valid <= 1'b0;
                    state <= PROCESS;
                end
            end

            PROCESS: begin
                if (col_index < 0) begin
                    state <= DONE;
                end else begin
                    case (a_current)
                        2'b00: begin
                            state <= NEXT_COLUMN;
                        end
                        2'b01: begin
                            stack_one_row[sp_one] <= col_index;
                            stack_one_col[sp_one] <= col_index;
                            sp_one <= sp_one + 2'd1;
                            target1_row <= col_index;
                            target1_col <= col_index;
                            remaining_targets <= 2'd1;
                            output_index <= 2'd0;
                            state <= OUTPUT;
                        end
                        2'b10: begin
                            if (sp_one == 2'd0) begin
                                state <= ERROR;
                            end else begin
                                target1_row <= stack_one_row[sp_one-1];
                                target1_col <= col_index;
                                stack_two_row[sp_two] <= stack_one_row[sp_one-1];
                                stack_two_col[sp_two] <= col_index;
                                sp_two <= sp_two + 2'd1;
                                sp_one <= sp_one - 2'd1;
                                remaining_targets <= 2'd1;
                                output_index <= 2'd0;
                                state <= OUTPUT;
                            end
                        end
                        2'b11: begin
                            if (sp_two > 2'd0) begin
                                target1_row <= col_index;
                                target1_col <= stack_two_col[sp_two-1];
                                target2_row <= col_index;
                                target2_col <= col_index;
                                stack_two_row[sp_two-1] <= col_index;
                                stack_two_col[sp_two-1] <= col_index;
                                remaining_targets <= 2'd2;
                                output_index <= 2'd0;
                                state <= OUTPUT;
                            end else if (sp_one > 2'd0) begin
                                target1_row <= col_index;
                                target1_col <= stack_one_col[sp_one-1];
                                target2_row <= col_index;
                                target2_col <= col_index;
                                stack_two_row[sp_two] <= col_index;
                                stack_two_col[sp_two] <= col_index;
                                sp_two <= sp_two + 2'd1;
                                sp_one <= sp_one - 2'd1;
                                remaining_targets <= 2'd2;
                                output_index <= 2'd0;
                                state <= OUTPUT;
                            end else begin
                                state <= ERROR;
                            end
                        end
                        default: state <= NEXT_COLUMN;
                    endcase
                end
            end

            OUTPUT: begin
                if (remaining_targets > 2'd0) begin
                    target_valid <= 1'b1;
                    if (output_index == 2'd0) begin
                        target_row <= target1_row + 3'd1;
                        target_col <= target1_col + 3'd1;
                    end else begin
                        target_row <= target2_row + 3'd1;
                        target_col <= target2_col + 3'd1;
                    end
                    remaining_targets <= remaining_targets - 2'd1;
                    output_index <= output_index + 2'd1;
                end else begin
                    target_valid <= 1'b0;
                    state <= NEXT_COLUMN;
                end
            end

            NEXT_COLUMN: begin
                col_index <= col_index - 3'd1;
                state <= PROCESS;
            end

            DONE: begin
                done <= 1'b1;
                valid <= 1'b1;
            end

            ERROR: begin
                done <= 1'b1;
                valid <= 1'b0;
                target_valid <= 1'b0;
            end

            default: state <= IDLE;
        endcase
    end
end

endmodule