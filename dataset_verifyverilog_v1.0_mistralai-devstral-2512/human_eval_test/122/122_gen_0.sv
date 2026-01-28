module add_elements(
    input clk,
    input rst_n,
    input start,
    input [15:0] arr [0:15],
    input [3:0] k,
    output reg [17:0] result,
    output reg done
);

    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] PROCESS = 3'd1;
    localparam [2:0] FINISH = 3'd2;

    reg [2:0] state;
    reg [3:0] counter;
    reg [17:0] sum;
    reg [15:0] current_value;
    reg is_two_digit;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            counter <= 4'd0;
            sum <= 18'd0;
            result <= 18'd0;
            done <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= PROCESS;
                        counter <= 4'd0;
                        sum <= 18'd0;
                    end
                end

                PROCESS: begin
                    current_value <= arr[counter];
                    is_two_digit = (current_value >= 16'd-99) && (current_value <= 16'd99);
                    if (is_two_digit) begin
                        sum <= sum + current_value;
                    end
                    counter <= counter + 4'd1;
                    if (counter == k) begin
                        state <= FINISH;
                    end
                end

                FINISH: begin
                    result <= sum;
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule