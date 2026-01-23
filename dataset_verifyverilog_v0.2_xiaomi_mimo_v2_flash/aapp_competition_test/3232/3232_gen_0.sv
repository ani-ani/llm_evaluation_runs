module string_rearrange(
    input clk,
    input rst_n,
    input start,
    input [7:0][7:0] char_array,
    output reg [7:0][7:0] result,
    output reg valid,
    output reg no_solution,
    output reg done
);

    localparam IDLE = 3'b000, SORT = 3'b001, CHECK = 3'b010, MODIFY = 3'b011, VERIFY = 3'b100, DONE = 3'b101;
    reg [2:0] state, next_state;
    reg [7:0][7:0] current_string;
    reg [7:0][7:0] next_result_reg;
    reg [2:0] sort_idx;
    reg [2:0] shift_count;
    reg [1:0] modify_flag;

    wire [31:0] substr [4:0];
    wire [31:0] substr_check [4:0];
    wire has_duplicates;
    wire has_duplicates_check;

    assign substr[0] = {current_string[0], current_string[1], current_string[2], current_string[3]};
    assign substr[1] = {current_string[1], current_string[2], current_string[3], current_string[4]};
    assign substr[2] = {current_string[2], current_string[3], current_string[4], current_string[5]};
    assign substr[3] = {current_string[3], current_string[4], current_string[5], current_string[6]};
    assign substr[4] = {current_string[4], current_string[5], current_string[6], current_string[7]};

    assign substr_check[0] = {next_result_reg[0], next_result_reg[1], next_result_reg[2], next_result_reg[3]};
    assign substr_check[1] = {next_result_reg[1], next_result_reg[2], next_result_reg[3], next_result_reg[4]};
    assign substr_check[2] = {next_result_reg[2], next_result_reg[3], next_result_reg[4], next_result_reg[5]};
    assign substr_check[3] = {next_result_reg[3], next_result_reg[4], next_result_reg[5], next_result_reg[6]};
    assign substr_check[4] = {next_result_reg[4], next_result_reg[5], next_result_reg[6], next_result_reg[7]};

    assign has_duplicates = (substr[0]==substr[1] || substr[0]==substr[2] || substr[0]==substr[3] || substr[0]==substr[4] ||
                             substr[1]==substr[2] || substr[1]==substr[3] || substr[1]==substr[4] ||
                             substr[2]==substr[3] || substr[2]==substr[4] ||
                             substr[3]==substr[4]);

    assign has_duplicates_check = (substr_check[0]==substr_check[1] || substr_check[0]==substr_check[2] || substr_check[0]==substr_check[3] || substr_check[0]==substr_check[4] ||
                                   substr_check[1]==substr_check[2] || substr_check[1]==substr_check[3] || substr_check[1]==substr_check[4] ||
                                   substr_check[2]==substr_check[3] || substr_check[2]==substr_check[4] ||
                                   substr_check[3]==substr_check[4]);

    always @(*) begin
        next_state = state;
        case (state)
            IDLE: if (start) next_state = SORT;
            SORT: if (shift_count >= 3'd7) next_state = CHECK; else next_state = SORT;
            CHECK: next_state = has_duplicates ? MODIFY : DONE;
            MODIFY: next_state = VERIFY;
            VERIFY: begin
                if (has_duplicates_check) begin
                    if (modify_flag == 2'd1) next_state = MODIFY;
                    else next_state = DONE;
                end else begin
                    next_state = DONE;
                end
            end
            DONE: if (!start) next_state = IDLE; else next_state = DONE;
            default: next_state = IDLE;
        endcase
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            current_string <= 64'b0;
            result <= 64'b0;
            valid <= 1'b0;
            no_solution <= 1'b0;
            done <= 1'b0;
            sort_idx <= 3'd0;
            shift_count <= 3'd0;
            modify_flag <= 2'd0;
            next_result_reg <= 64'b0;
        end else begin
            state <= next_state;
            case (next_state)
                IDLE: begin
                    valid <= 1'b0;
                    no_solution <= 1'b0;
                    done <= 1'b0;
                    if (start) begin
                        current_string <= char_array;
                        sort_idx <= 3'd0;
                        shift_count <= 3'd0;
                        modify_flag <= 2'd0;
                    end
                end
                SORT: begin
                    if (shift_count < 3'd7) begin
                        if (current_string[sort_idx] > current_string[sort_idx + 1]) begin
                            current_string[sort_idx] <= current_string[sort_idx + 1];
                            current_string[sort_idx + 1] <= current_string[sort_idx];
                        end
                        if (sort_idx < 3'd6) begin
                            sort_idx <= sort_idx + 1;
                        end else begin
                            sort_idx <= 3'd0;
                            shift_count <= shift_count + 1;
                        end
                    end
                end
                CHECK: begin
                    modify_flag <= 2'd0;
                end
                MODIFY: begin
                    if (modify_flag == 2'd0) begin
                        // Reverse
                        next_result_reg[0] <= current_string[7];
                        next_result_reg[1] <= current_string[6];
                        next_result_reg[2] <= current_string[5];
                        next_result_reg[3] <= current_string[4];
                        next_result_reg[4] <= current_string[3];
                        next_result_reg[5] <= current_string[2];
                        next_result_reg[6] <= current_string[1];
                        next_result_reg[7] <= current_string[0];
                        modify_flag <= 2'd1;
                    end else if (modify_flag == 2'd1) begin
                        // Shift
                        next_result_reg[0] <= current_string[7];
                        next_result_reg[1] <= current_string[0];
                        next_result_reg[2] <= current_string[1];
                        next_result_reg[3] <= current_string[2];
                        next_result_reg[4] <= current_string[3];
                        next_result_reg[5] <= current_string[4];
                        next_result_reg[6] <= current_string[5];
                        next_result_reg[7] <= current_string[6];
                        modify_flag <= 2'd2;
                    end
                end
                VERIFY: begin
                    if (!has_duplicates_check) begin
                        result <= next_result_reg;
                        valid <= 1'b1;
                        no_solution <= 1'b0;
                        done <= 1'b1;
                    end else begin
                        if (modify_flag == 2'd2) begin
                            valid <= 1'b0;
                            no_solution <= 1'b1;
                            done <= 1'b1;
                        end
                    end
                end
                DONE: begin
                    if (state != DONE && modify_flag == 2'd0) begin
                        result <= current_string;
                        valid <= 1'b1;
                        no_solution <= 1'b0;
                        done <= 1'b1;
                    end
                    if (!start) begin
                         valid <= 1'b0;
                         no_solution <= 1'b0;
                         done <= 1'b0;
                    end
                end
            endcase
        end
    end
endmodule