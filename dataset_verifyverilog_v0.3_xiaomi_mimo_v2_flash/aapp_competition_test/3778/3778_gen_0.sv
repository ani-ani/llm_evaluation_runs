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
localparam [2:0] IDLE = 3'd0;
localparam [2:0] PROCESS = 3'd1;
localparam [2:0] OUTPUT = 3'd2;
localparam [2:0] NEXT_COLUMN = 3'd3;
localparam [2:0] DONE = 3'd4;
localparam [2:0] ERROR = 3'd5;

// Registers
reg [2:0] state;
reg [1:0] a_reg0, a_reg1, a_reg2, a_reg3;
reg signed [2:0] col_index;
reg [1:0] sp_one;
reg [1:0] sp_two;
reg [1:0] stack_one_row0, stack_one_row1, stack_one_row2, stack_one_row3;
reg [1:0] stack_one_col0, stack_one_col1, stack_one_col2, stack_one_col3;
reg [1:0] stack_two_row0, stack_two_row1, stack_two_row2, stack_two_row3;
reg [1:0] stack_two_col0, stack_two_col1, stack_two_col2, stack_two_col3;
reg [1:0] target1_row, target1_col, target2_row, target2_col;
reg [1:0] remaining_targets;
reg [1:0] output_index;
reg signed [2:0] next_col;

wire [1:0] a_current;
wire [1:0] stack_one_row_val;
wire [1:0] stack_one_col_val;
wire [1:0] stack_two_row_val;
wire [1:0] stack_two_col_val;

assign a_current = (col_index == 3) ? a_reg3 :
                   (col_index == 2) ? a_reg2 :
                   (col_index == 1) ? a_reg1 :
                   a_reg0;

assign stack_one_row_val = (sp_one == 1) ? stack_one_row0 :
                           (sp_one == 2) ? stack_one_row1 :
                           (sp_one == 3) ? stack_one_row2 :
                           stack_one_row3;

assign stack_one_col_val = (sp_one == 1) ? stack_one_col0 :
                           (sp_one == 2) ? stack_one_col1 :
                           (sp_one == 3) ? stack_one_col2 :
                           stack_one_col3;

assign stack_two_row_val = (sp_two == 1) ? stack_two_row0 :
                           (sp_two == 2) ? stack_two_row1 :
                           (sp_two == 3) ? stack_two_row2 :
                           stack_two_row3;

assign stack_two_col_val = (sp_two == 1) ? stack_two_col0 :
                           (sp_two == 2) ? stack_two_col1 :
                           (sp_two == 3) ? stack_two_col2 :
                           stack_two_col3;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        done <= 0;
        valid <= 0;
        target_valid <= 0;
        sp_one <= 0;
        sp_two <= 0;
        col_index <= 3;
        remaining_targets <= 0;
        output_index <= 0;
        next_col <= 0;
        a_reg0 <= 0;
        a_reg1 <= 0;
        a_reg2 <= 0;
        a_reg3 <= 0;
        target1_row <= 0;
        target1_col <= 0;
        target2_row <= 0;
        target2_col <= 0;
        target_row <= 0;
        target_col <= 0;
        stack_one_row0 <= 0;
        stack_one_row1 <= 0;
        stack_one_row2 <= 0;
        stack_one_row3 <= 0;
        stack_one_col0 <= 0;
        stack_one_col1 <= 0;
        stack_one_col2 <= 0;
        stack_one_col3 <= 0;
        stack_two_row0 <= 0;
        stack_two_row1 <= 0;
        stack_two_row2 <= 0;
        stack_two_row3 <= 0;
        stack_two_col0 <= 0;
        stack_two_col1 <= 0;
        stack_two_col2 <= 0;
        stack_two_col3 <= 0;
    end else begin
        case (state)
            IDLE: begin
                if (start) begin
                    a_reg0 <= a0;
                    a_reg1 <= a1;
                    a_reg2 <= a2;
                    a_reg3 <= a3;
                    sp_one <= 0;
                    sp_two <= 0;
                    col_index <= 3;
                    remaining_targets <= 0;
                    output_index <= 0;
                    done <= 0;
                    valid <= 0;
                    target_valid <= 0;
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
                            case (sp_one)
                                2'd0: begin
                                    stack_one_row0 <= col_index;
                                    stack_one_col0 <= col_index;
                                end
                                2'd1: begin
                                    stack_one_row1 <= col_index;
                                    stack_one_col1 <= col_index;
                                end
                                2'd2: begin
                                    stack_one_row2 <= col_index;
                                    stack_one_col2 <= col_index;
                                end
                                2'd3: begin
                                    stack_one_row3 <= col_index;
                                    stack_one_col3 <= col_index;
                                end
                            endcase
                            sp_one <= sp_one + 1;
                            target1_row <= col_index;
                            target1_col <= col_index;
                            remaining_targets <= 1;
                            output_index <= 0;
                            state <= OUTPUT;
                        end
                        2'b10: begin
                            if (sp_one == 0) begin
                                state <= ERROR;
                            end else begin
                                target1_row <= stack_one_row_val;
                                target1_col <= col_index;
                                case (sp_two)
                                    2'd0: begin
                                        stack_two_row0 <= stack_one_row_val;
                                        stack_two_col0 <= col_index;
                                    end
                                    2'd1: begin
                                        stack_two_row1 <= stack_one_row_val;
                                        stack_two_col1 <= col_index;
                                    end
                                    2'd2: begin
                                        stack_two_row2 <= stack_one_row_val;
                                        stack_two_col2 <= col_index;
                                    end
                                    2'd3: begin
                                        stack_two_row3 <= stack_one_row_val;
                                        stack_two_col3 <= col_index;
                                    end
                                endcase
                                sp_two <= sp_two + 1;
                                sp_one <= sp_one - 1;
                                remaining_targets <= 1;
                                output_index <= 0;
                                state <= OUTPUT;
                            end
                        end
                        2'b11: begin
                            if (sp_two > 0) begin
                                target1_row <= col_index;
                                target1_col <= stack_two_col_val;
                                target2_row <= col_index;
                                target2_col <= col_index;
                                case (sp_two)
                                    2'd1: begin
                                        stack_two_row0 <= col_index;
                                        stack_two_col0 <= col_index;
                                    end
                                    2'd2: begin
                                        stack_two_row1 <= col_index;
                                        stack_two_col1 <= col_index;
                                    end
                                    2'd3: begin
                                        stack_two_row2 <= col_index;
                                        stack_two_col2 <= col_index;
                                    end
                                    default: begin
                                        stack_two_row3 <= col_index;
                                        stack_two_col3 <= col_index;
                                    end
                                endcase
                                remaining_targets <= 2;
                                output_index <= 0;
                                state <= OUTPUT;
                            end else if (sp_one > 0) begin
                                target1_row <= col_index;
                                target1_col <= stack_one_col_val;
                                target2_row <= col_index;
                                target2_col <= col_index;
                                case (sp_two)
                                    2'd0: begin
                                        stack_two_row0 <= col_index;
                                        stack_two_col0 <= col_index;
                                    end
                                    2'd1: begin
                                        stack_two_row1 <= col_index;
                                        stack_two_col1 <= col_index;
                                    end
                                    2'd2: begin
                                        stack_two_row2 <= col_index;
                                        stack_two_col2 <= col_index;
                                    end
                                    2'd3: begin
                                        stack_two_row3 <= col_index;
                                        stack_two_col3 <= col_index;
                                    end
                                endcase
                                sp_two <= sp_two + 1;
                                sp_one <= sp_one - 1;
                                remaining_targets <= 2;
                                output_index <= 0;
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
                if (remaining_targets > 0) begin
                    target_valid <= 1;
                    if (output_index == 0) begin
                        target_row <= target1_row + 1;
                        target_col <= target1_col + 1;
                    end else begin
                        target_row <= target2_row + 1;
                        target_col <= target2_col + 1;
                    end
                    remaining_targets <= remaining_targets - 1;
                    output_index <= output_index + 1;
                end else begin
                    target_valid <= 0;
                    state <= NEXT_COLUMN;
                end
            end

            NEXT_COLUMN: begin
                if (col_index > 0) begin
                    next_col <= col_index - 1;
                    col_index <= col_index - 1;
                    state <= PROCESS;
                end else begin
                    state <= DONE;
                end
            end

            DONE: begin
                done <= 1;
                valid <= 1;
                state <= IDLE;
            end

            ERROR: begin
                done <= 1;
                valid <= 0;
                target_valid <= 0;
                state <= IDLE;
            end

            default: state <= IDLE;
        endcase
    end
end

endmodule