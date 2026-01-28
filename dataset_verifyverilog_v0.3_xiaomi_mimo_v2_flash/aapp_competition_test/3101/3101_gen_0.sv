module eris_sabotage #(
    parameter N_MAX = 4,
    parameter BITS = 4
)(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [1:0] n,
    input wire [BITS-1:0] arr_0,
    input wire [BITS-1:0] arr_1,
    input wire [BITS-1:0] arr_2,
    input wire [BITS-1:0] arr_3,
    output reg [BITS-1:0] result_0,
    output reg [BITS-1:0] result_1,
    output reg [BITS-1:0] result_2,
    output reg [BITS-1:0] result_3,
    output reg done,
    output reg impossible
);

    // State definitions
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] SEARCH = 2'd1;
    localparam [1:0] DONE_STATE = 2'd2;

    // Registers for input storage
    reg [1:0] n_reg;
    reg [BITS-1:0] orig_0;
    reg [BITS-1:0] orig_1;
    reg [BITS-1:0] orig_2;
    reg [BITS-1:0] orig_3;

    // State machine registers
    reg [1:0] state;
    reg [1:0] i_reg;
    reg [1:0] bit_reg;
    reg found_reg;
    reg impossible_reg;
    reg [BITS-1:0] result_reg_0;
    reg [BITS-1:0] result_reg_1;
    reg [BITS-1:0] result_reg_2;
    reg [BITS-1:0] result_reg_3;

    // Combinational signals
    wire [BITS-1:0] new_number;
    wire [BITS-1:0] cand_0;
    wire [BITS-1:0] cand_1;
    wire [BITS-1:0] cand_2;
    wire [BITS-1:0] cand_3;
    wire cmp0;
    wire cmp1;
    wire cmp2;
    wire sorted_flag;

    // Combinational logic for new_number
    assign new_number = (i_reg == 2'd0) ? (orig_0 ^ (1 << bit_reg)) :
                        (i_reg == 2'd1) ? (orig_1 ^ (1 << bit_reg)) :
                        (i_reg == 2'd2) ? (orig_2 ^ (1 << bit_reg)) :
                        (orig_3 ^ (1 << bit_reg));

    // Candidate list
    assign cand_0 = (i_reg == 2'd0) ? new_number : orig_0;
    assign cand_1 = (i_reg == 2'd1) ? new_number : orig_1;
    assign cand_2 = (i_reg == 2'd2) ? new_number : orig_2;
    assign cand_3 = (i_reg == 2'd3) ? new_number : orig_3;

    // Sorted check
    assign cmp0 = (n_reg > 2'd1) ? (cand_0 <= cand_1) : 1'b1;
    assign cmp1 = (n_reg > 2'd2) ? (cand_1 <= cand_2) : 1'b1;
    assign cmp2 = (n_reg > 2'd3) ? (cand_2 <= cand_3) : 1'b1;
    assign sorted_flag = cmp0 & cmp1 & cmp2;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            impossible <= 1'b0;
            i_reg <= 2'd0;
            bit_reg <= 2'd0;
            found_reg <= 1'b0;
            impossible_reg <= 1'b0;
            result_reg_0 <= {BITS{1'b0}};
            result_reg_1 <= {BITS{1'b0}};
            result_reg_2 <= {BITS{1'b0}};
            result_reg_3 <= {BITS{1'b0}};
            orig_0 <= {BITS{1'b0}};
            orig_1 <= {BITS{1'b0}};
            orig_2 <= {BITS{1'b0}};
            orig_3 <= {BITS{1'b0}};
            n_reg <= 2'd0;
            result_0 <= {BITS{1'b0}};
            result_1 <= {BITS{1'b0}};
            result_2 <= {BITS{1'b0}};
            result_3 <= {BITS{1'b0}};
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    impossible <= 1'b0;
                    if (start) begin
                        n_reg <= n;
                        orig_0 <= arr_0;
                        orig_1 <= arr_1;
                        orig_2 <= arr_2;
                        orig_3 <= arr_3;
                        i_reg <= 2'd0;
                        bit_reg <= 2'd0;
                        found_reg <= 1'b0;
                        impossible_reg <= 1'b0;
                        state <= SEARCH;
                    end
                end

                SEARCH: begin
                    if (!sorted_flag) begin
                        found_reg <= 1'b1;
                        result_reg_0 <= cand_0;
                        result_reg_1 <= cand_1;
                        result_reg_2 <= cand_2;
                        result_reg_3 <= cand_3;
                        state <= DONE_STATE;
                    end else begin
                        if (bit_reg < 2'd3) begin
                            bit_reg <= bit_reg + 2'd1;
                        end else begin
                            bit_reg <= 2'd0;
                            if (i_reg < n_reg - 2'd1) begin
                                i_reg <= i_reg + 2'd1;
                            end else begin
                                impossible_reg <= 1'b1;
                                state <= DONE_STATE;
                            end
                        end
                    end
                end

                DONE_STATE: begin
                    done <= 1'b1;
                    if (found_reg) begin
                        result_0 <= result_reg_0;
                        result_1 <= result_reg_1;
                        result_2 <= result_reg_2;
                        result_3 <= result_reg_3;
                        impossible <= 1'b0;
                    end else begin
                        result_0 <= orig_0;
                        result_1 <= orig_1;
                        result_2 <= orig_2;
                        result_3 <= orig_3;
                        impossible <= 1'b1;
                    end
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule