module sort_numeric_strings ( parameter N = 16, input clk, input rst_n, input start, input [7:0] nums [0:N-1], output reg [7:0] sorted_nums [0:N-1], output reg done );
// Internal signals
reg signed [7:0] buffer [0:N-1];
reg [3:0] i, j;
reg [1:0] state;
reg signed [7:0] temp;
always @(posedge clk) begin
    if (!rst_n) begin
        state <= 0; // IDLE
        buffer <= {N{8's0}};
        i <= 0;
        j <= 0;
        sorted_nums <= {N{8's0}};
        done <= 0;
    end else begin
        case (state)
            0: begin // IDLE
                if (start) begin
                    state <= 1; // LOAD
                end
            end
            1: begin // LOAD
                buffer <= nums;
                state <= 2; // PROCESSING
            end
            2: begin // PROCESSING
                if (buffer[j] > buffer[j+1]) begin
                    temp = buffer[j];
                    buffer[j] = buffer[j+1];
                    buffer[j+1] = temp;
                end
                if (j < (N-1 - i)) begin
                    j <= j + 1;
                end else begin
                    i <= i + 1;
                    j <= 0;
                end
                if (i >= N-1) begin
                    state <= 3; // DONE
                    sorted_nums <= buffer;
                    done <= 1;
                end
            end
            3: begin // DONE
                if (start) begin
                    state <= 0;
                    i <= 0;
                    j <= 0;
                    done <= 0;
                end
            end
        endcase
    end
endmodule