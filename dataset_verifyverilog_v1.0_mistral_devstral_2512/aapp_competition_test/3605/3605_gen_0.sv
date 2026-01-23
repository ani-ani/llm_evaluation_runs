module tree_diff #(
    parameter N = 8,
    parameter DATA_WIDTH = 8,
    parameter K_WIDTH = 4
)(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [DATA_WIDTH-1:0] arr_0,
    input wire [DATA_WIDTH-1:0] arr_1,
    input wire [DATA_WIDTH-1:0] arr_2,
    input wire [DATA_WIDTH-1:0] arr_3,
    input wire [DATA_WIDTH-1:0] arr_4,
    input wire [DATA_WIDTH-1:0] arr_5,
    input wire [DATA_WIDTH-1:0] arr_6,
    input wire [DATA_WIDTH-1:0] arr_7,
    input wire [K_WIDTH-1:0] k,
    output reg [DATA_WIDTH-1:0] result,
    output reg done
);

    reg [DATA_WIDTH-1:0] arr_reg [0:N-1];
    reg [K_WIDTH-1:0] k_reg;
    reg [DATA_WIDTH-1:0] min_diff;
    reg [DATA_WIDTH-1:0] cur_min, cur_max;
    reg [3:0] i;
    reg [3:0] j;
    reg [2:0] state;

    localparam [2:0] IDLE = 3'b000;
    localparam [2:0] NEXT_WINDOW = 3'b001;
    localparam [2:0] COMPUTE_WINDOW = 3'b010;
    localparam [2:0] UPDATE_DIFF = 3'b011;
    localparam [2:0] DONE = 3'b100;

    integer idx;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result <= 8'b0;
            min_diff <= 8'b0;
            cur_min <= 8'b0;
            cur_max <= 8'b0;
            i <= 4'b0;
            j <= 4'b0;
            k_reg <= 4'b0;
            for (idx = 0; idx < N; idx = idx + 1) begin
                arr_reg[idx] <= 8'b0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        arr_reg[0] <= arr_0;
                        arr_reg[1] <= arr_1;
                        arr_reg[2] <= arr_2;
                        arr_reg[3] <= arr_3;
                        arr_reg[4] <= arr_4;
                        arr_reg[5] <= arr_5;
                        arr_reg[6] <= arr_6;
                        arr_reg[7] <= arr_7;
                        k_reg <= k;
                        min_diff <= 8'hFF;
                        i <= 4'b0;
                        state <= NEXT_WINDOW;
                    end
                end

                NEXT_WINDOW: begin
                    if (i <= N - k_reg) begin
                        cur_min <= 8'hFF;
                        cur_max <= 8'h00;
                        j <= i;
                        state <= COMPUTE_WINDOW;
                    end else begin
                        state <= DONE;
                    end
                end

                COMPUTE_WINDOW: begin
                    if (arr_reg[j] < cur_min) begin
                        cur_min <= arr_reg[j];
                    end
                    if (arr_reg[j] > cur_max) begin
                        cur_max <= arr_reg[j];
                    end
                    j <= j + 1;
                    if (j < i + k_reg) begin
                        state <= COMPUTE_WINDOW;
                    end else begin
                        state <= UPDATE_DIFF;
                    end
                end

                UPDATE_DIFF: begin
                    if (cur_max - cur_min < min_diff) begin
                        min_diff <= cur_max - cur_min;
                    end
                    i <= i + 1;
                    state <= NEXT_WINDOW;
                end

                DONE: begin
                    result <= min_diff;
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule