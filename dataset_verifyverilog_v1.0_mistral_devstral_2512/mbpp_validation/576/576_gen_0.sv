module is_Sub_Array(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] A_0, A_1, A_2, A_3,
    input wire [7:0] B_0, B_1, B_2, B_3,
    input wire [2:0] len_A,
    input wire [2:0] len_B,
    output reg result,
    output reg done
);

    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] SEARCH = 3'd1;
    localparam [2:0] CHECK_MATCH = 3'd2;
    localparam [2:0] BACKTRACK = 3'd3;
    localparam [2:0] FINISHED = 3'd4;

    reg [2:0] state;
    reg [2:0] i;
    reg [2:0] j;
    reg [2:0] start_idx;
    reg [7:0] arr_A [0:3];
    reg [7:0] arr_B [0:3];
    reg [2:0] valid_len_A;
    reg [2:0] valid_len_B;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 1'b0;
            done <= 1'b0;
            i <= 3'd0;
            j <= 3'd0;
            start_idx <= 3'd0;
            arr_A[0] <= 8'd0;
            arr_A[1] <= 8'd0;
            arr_A[2] <= 8'd0;
            arr_A[3] <= 8'd0;
            arr_B[0] <= 8'd0;
            arr_B[1] <= 8'd0;
            arr_B[2] <= 8'd0;
            arr_B[3] <= 8'd0;
            valid_len_A <= 3'd0;
            valid_len_B <= 3'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        arr_A[0] <= A_0;
                        arr_A[1] <= A_1;
                        arr_A[2] <= A_2;
                        arr_A[3] <= A_3;
                        arr_B[0] <= B_0;
                        arr_B[1] <= B_1;
                        arr_B[2] <= B_2;
                        arr_B[3] <= B_3;
                        valid_len_A <= len_A;
                        valid_len_B <= len_B;
                        if (len_B == 3'd0 || len_B > len_A) begin
                            result <= 1'b0;
                            state <= FINISHED;
                        end else begin
                            i <= 3'd0;
                            j <= 3'd0;
                            start_idx <= 3'd0;
                            state <= SEARCH;
                        end
                    end
                end

                SEARCH: begin
                    if (j >= valid_len_B) begin
                        result <= 1'b1;
                        state <= FINISHED;
                    end else if (i >= valid_len_A) begin
                        result <= 1'b0;
                        state <= FINISHED;
                    end else begin
                        state <= CHECK_MATCH;
                    end
                end

                CHECK_MATCH: begin
                    if (arr_A[i] == arr_B[j]) begin
                        i <= i + 3'd1;
                        j <= j + 3'd1;
                        state <= SEARCH;
                    end else begin
                        if (start_idx + 3'd1 >= valid_len_A) begin
                            result <= 1'b0;
                            state <= FINISHED;
                        end else begin
                            start_idx <= start_idx + 3'd1;
                            i <= start_idx + 3'd1;
                            j <= 3'd0;
                            state <= SEARCH;
                        end
                    end
                end

                FINISHED: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule