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

    // State declarations
    localparam [2:0] IDLE          = 3'd0;
    localparam [2:0] NEXT_WINDOW   = 3'd1;
    localparam [2:0] COMPUTE_MINMAX = 3'd2;
    localparam [2:0] UPDATE_DIFF   = 3'd3;
    localparam [2:0] FINISH        = 3'd4;

    reg [2:0] state;
    reg [DATA_WIDTH-1:0] arr_reg [0:N-1];
    reg [3:0] i, j;
    reg [K_WIDTH-1:0] k_reg;
    reg [DATA_WIDTH-1:0] cur_min;
    reg [DATA_WIDTH-1:0] cur_max;
    reg [DATA_WIDTH-1:0] min_diff;
    reg window_done;
    integer idx;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result <= 8'd0;
            for (idx = 0; idx < N; idx = idx + 1) arr_reg[idx] <= 8'd0;
            k_reg <= {K_WIDTH{1'b0}};
            min_diff <= {DATA_WIDTH{1'b1}};
            cur_min <= 8'd0;
            cur_max <= 8'd0;
            i <= 4'd0;
            j <= 4'd0;
            window_done <= 1'b0;
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
                        min_diff <= {DATA_WIDTH{1'b1}};  // Max value
                        i <= 4'd0;
                        j <= 4'd0;
                        state <= NEXT_WINDOW;
                    end
                end

                NEXT_WINDOW: begin
                    window_done <= 1'b0;
                    if (i <= (8'd8 - k_reg)) begin
                        cur_min <= {DATA_WIDTH{1'b1}};
                        cur_max <= 8'd0;
                        j <= i;
                        state <= COMPUTE_MINMAX;
                    end else begin
                        state <= FINISH;
                    end
                end

                COMPUTE_MINMAX: begin
                    if (j < (i + k_reg)) begin
                        if (arr_reg[j] < cur_min) cur_min <= arr_reg[j];
                        if (arr_reg[j] > cur_max) cur_max <= arr_reg[j];
                        j <= j + 1;
                    end else begin
                        window_done <= 1'b1;
                    end

                    if (window_done) begin
                        state <= UPDATE_DIFF;
                    end
                end

                UPDATE_DIFF: begin
                    if ((cur_max - cur_min) < min_diff) begin
                        min_diff <= cur_max - cur_min;
                    end
                    i <= i + 1;
                    state <= NEXT_WINDOW;
                end

                FINISH: begin
                    result <= min_diff;
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule