module complex_to_polar (input clk, input rst_n, input start, input signed [31:0] real_in, input signed [31:0] imag_in, output reg [31:0] magnitude, output reg [31:0] angle, output reg done);
localparam IDLE = 3'd0, SQR_REAL = 3'd1, SQR_IMAG = 3'd2, SUM_SQRS = 3'd3, SQRT_ITER = 3'd4, ATAN = 3'd5, DONE = 3'd6;
reg [2:0] state;
reg [31:0] magnitude_reg;
reg [31:0] angle_reg;
reg [3:0] wait_counter;
reg [4:0] sqrt_iter_count;
reg [63:0] sum_squares;
reg [31:0] current_guess;
always @(*) begin
    magnitude = magnitude_reg;
    angle = angle_reg;
    done = (wait_counter == 0);
end
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        magnitude_reg <= 0;
        angle_reg <= 0;
        wait_counter <= 0;
        sqrt_iter_count <= 0;
        sum_squares <= 0;
        current_guess <= 0;
    end else begin
        case (state)
            IDLE: begin
                if (start) state <= SQR_REAL;
                else state <= IDLE;
            end
            SQR_REAL: state <= SQR_IMAG;
            SQR_IMAG: state <= SUM_SQRS;
            SUM_SQRS: begin
                sum_squares <= real_in * real_in + imag_in * imag_in;
                state <= SQRT_ITER;
            end
            SQRT_ITER: begin
                if (sqrt_iter_count < 20) begin
                    sqrt_iter_count <= sqrt_iter_count + 1;
                    current_guess <= (current_guess + sum_squares / current_guess) / 2;
                    state <= SQRT_ITER;
                end else begin
                    magnitude_reg <= current_guess >> 0;
                    state <= ATAN;
                end
            end
            ATAN: begin
                angle_reg <= 0;
                state <= DONE;
            end
            DONE: begin
                if (wait_counter > 0) begin
                    wait_counter <= wait_counter - 1;
                end
                state <= DONE;
            end
        endcase
    end
end
endmodule