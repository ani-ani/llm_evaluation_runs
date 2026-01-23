module sort_numeric_strings (
    input clk,
    input rst_n,
    input start,
    input [7:0] nums [0:15],
    output reg [7:0] sorted_nums [0:15],
    output reg done
);

    parameter N = 16;

    typedef enum logic [1:0] {
        IDLE,
        LOAD,
        PROCESSING,
        DONE
    } state_t;

    state_t state;
    reg [7:0] buffer [0:N-1];
    integer i, j;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 0;
            i <= 0;
            j <= 0;
            for (int k = 0; k < N; k = k + 1) begin
                buffer[k] <= 0;
                sorted_nums[k] <= 0;
            end
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        state <= LOAD;
                    end
                end
                LOAD: begin
                    for (int k = 0; k < N; k = k + 1) begin
                        buffer[k] <= nums[k];
                    end
                    i <= 0;
                    j <= 0;
                    state <= PROCESSING;
                end
                PROCESSING: begin
                    if ($signed(buffer[j]) > $signed(buffer[j+1])) begin
                        reg [7:0] temp;
                        temp = buffer[j];
                        buffer[j] = buffer[j+1];
                        buffer[j+1] = temp;
                    end
                    if (j < N - 2 - i) begin
                        j <= j + 1;
                    end else begin
                        j <= 0;
                        if (i < N - 2) begin
                            i <= i + 1;
                        end else begin
                            state <= DONE;
                        end
                    end
                end
                DONE: begin
                    for (int k = 0; k < N; k = k + 1) begin
                        sorted_nums[k] <= buffer[k];
                    end
                    done <= 1;
                    if (start || !rst_n) begin
                        state <= IDLE;
                        done <= 0;
                    end
                end
            endcase
        end
    end

endmodule