module cube_sum_even (
input clk,
input rst_n, // active-low reset
input start,
input [3:0] n,
output reg [31:0] result,
output reg done
);

// Registers
reg [1:0] state; // 00=IDLE, 01=COMPUTE, 10=DONE
reg [31:0] accumulated_sum;
reg [2:0] count; // count from 1 to n
reg [3:0] n_value; 
reg [1:0] wait_counter; // 2 cycles delay

// State machine
always @(posedge clk) begin
    if (!rst_n) begin
        state <= 2'b00;
        accumulated_sum <= 32'b0;
        count <= 3'b0;
        n_value <= 4'b0;
        wait_counter <= 2'b00;
        done <= 1'b0;
    end else begin
        case (state)
            2'b00: // IDLE
                if (start) begin
                    n_value <= n;
                    accumulated_sum <= 32'b0;
                    count <= 1;
                    wait_counter <= 2'b10; // 2 cycles wait
                    state <= 2'b01;
                    done <= 1'b0;
                end
                else begin
                    state <= 2'b00;
                    done <= 1'b0;
                end
            2'b01: // COMPUTE
                if (wait_counter > 0) begin
                    wait_counter <= wait_counter - 1;
                    state <= 2'b01;
                    done <= 1'b0;
                end else begin
                    if (count > n_value) begin
                        state <= 2'b10;
                        done <= 1'b1;
                    end else begin
                        accumulated_sum <= accumulated_sum + ( (2 * count) * (2 * count) * (2 * count) );
                        count <= count + 1;
                        state <= 2'b01;
                        done <= 1'b0;
                    end
                end
            2'b10: // DONE
                state <= 2'b10;
                done <= 1'b1;
        endcase
    end
end

// Assign outputs
assign result = accumulated_sum;
endmodule
