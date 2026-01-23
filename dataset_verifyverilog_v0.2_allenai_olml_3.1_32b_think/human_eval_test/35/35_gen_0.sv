module max_element (
    output reg [15:0] max_result,
    output reg done,
    input clk,
    input rst_n, // active-low reset
    input start, // added
    input [4:0] array_size,
    input [15:0] array_data [0:15]
);

// Registers
reg [1:0] state;
reg [15:0] max_val;
reg [3:0] index;
reg done_out;

// Reset
always @(posedge clk) begin
    if (!rst_n) begin
        state <= 2'b00; // IDLE
        max_val <= 16'b0;
        index <= 4'd0;
        done_out <= 1'b0;
    end else begin
        case(state)
            2'b00: // IDLE
                if (start) begin
                    state <= 2'b01; // INIT
                end
                done_out <= 1'b0;
            end
            2'b01: // INIT
                max_val <= array_data[0];
                index <= 1;
                state <= 2'b10; // COMPARE
                done_out <= 1'b0;
            end
            2'b10: // COMPARE
                if (index < array_size) begin
                    if (array_data[index] > max_val) begin
                        max_val <= array_data[index];
                    end
                    index <= index + 1;
                    state <= 2'b10; // stay
                end else begin
                    state <= 2'b11; // DONE
                    done_out <= 1'b1;
                end
            end
            2'b11: // DONE
                state <= 2'b11;
                done_out <= 1'b1;
            endcase
        end
    end
end

// Assign outputs
assign max_result = max_val;
assign done = done_out;

endmodule