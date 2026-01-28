module min_max_sum (
    input clk,
    input rst_n,
    input start,
    input [7:0] A0, A1, A2, A3, A4, A5, A6, A7,
    input [7:0] B0, B1, B2, B3, B4, B5, B6, B7,
    output reg [7:0] result,
    output reg done
);

// State definitions
localparam [2:0] IDLE    = 3'd0;
localparam [2:0] SORT_A  = 3'd1;
localparam [2:0] SORT_B  = 3'd2;
localparam [2:0] COMPUTE = 3'd3;
localparam [2:0] DONE    = 3'd4;

// Internal registers
reg [7:0] A [0:7];
reg [7:0] B [0:7];
reg [2:0] state;
reg [2:0] i, j;
reg [3:0] k;
reg [7:0] max_sum;
reg load_done;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        i <= 3'd0;
        j <= 3'd0;
        k <= 4'd0;
        max_sum <= 8'd0;
        result <= 8'd0;
        done <= 1'b0;
        load_done <= 1'b0;
        A[0] <= 8'd0; A[1] <= 8'd0; A[2] <= 8'd0; A[3] <= 8'd0;
        A[4] <= 8'd0; A[5] <= 8'd0; A[6] <= 8'd0; A[7] <= 8'd0;
        B[0] <= 8'd0; B[1] <= 8'd0; B[2] <= 8'd0; B[3] <= 8'd0;
        B[4] <= 8'd0; B[5] <= 8'd0; B[6] <= 8'd0; B[7] <= 8'd0;
    end else begin
        case (state)
            IDLE: begin
                done <= 1'b0;
                if (start) begin
                    load_done <= 1'b1;
                    A[0] <= A0; A[1] <= A1; A[2] <= A2; A[3] <= A3;
                    A[4] <= A4; A[5] <= A5; A[6] <= A6; A[7] <= A7;
                    B[0] <= B0; B[1] <= B1; B[2] <= B2; B[3] <= B3;
                    B[4] <= B4; B[5] <= B5; B[6] <= B6; B[7] <= B7;
                    i <= 3'd0;
                    j <= 3'd0;
                    state <= SORT_A;
                end
            end

            SORT_A: begin
                load_done <= 1'b0;
                if (i < 3'd7) begin
                    if (j < 3'd7 - i) begin
                        if (A[j] > A[j+1]) begin
                            A[j] <= A[j+1];
                            A[j+1] <= A[j];
                        end
                        j <= j + 3'd1;
                    end else begin
                        j <= 3'd0;
                        i <= i + 3'd1;
                    end
                end else begin
                    i <= 3'd0;
                    j <= 3'd0;
                    state <= SORT_B;
                end
            end

            SORT_B: begin
                if (i < 3'd7) begin
                    if (j < 3'd7 - i) begin
                        if (B[j] < B[j+1]) begin
                            B[j] <= B[j+1];
                            B[j+1] <= B[j];
                        end
                        j <= j + 3'd1;
                    end else begin
                        j <= 3'd0;
                        i <= i + 3'd1;
                    end
                end else begin
                    i <= 3'd0;
                    j <= 3'd0;
                    k <= 4'd0;
                    max_sum <= 8'd0;
                    state <= COMPUTE;
                end
            end

            COMPUTE: begin
                if (k < 4'd8) begin
                    if (A[k] + B[k] > max_sum) begin
                        max_sum <= A[k] + B[k];
                    end
                    k <= k + 4'd1;
                end else begin
                    result <= max_sum;
                    state <= DONE;
                end
            end

            DONE: begin
                done <= 1'b1;
                state <= IDLE;
            end

            default: state <= IDLE;
        endcase
    end
end

endmodule