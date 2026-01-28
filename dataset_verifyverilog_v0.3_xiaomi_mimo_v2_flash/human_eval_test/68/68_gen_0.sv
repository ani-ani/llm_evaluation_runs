module pluck_even (
    input clk,
    input rst_n,
    input start,
    input [7:0] arr [0:7],
    output reg [7:0] result_value,
    output reg [2:0] result_index,
    output reg found,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE    = 2'd0;
    localparam [1:0] ITERATE = 2'd1;
    localparam [1:0] DONE    = 2'd2;

    // Internal registers
    reg [1:0] state;
    reg [2:0] index;
    reg [7:0] min_value;
    reg [2:0] min_index;
    reg even_found;

    // State transition logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all registers
            state <= IDLE;
            index <= 3'd0;
            min_value <= 8'd0;
            min_index <= 3'd0;
            even_found <= 1'b0;
            result_value <= 8'd0;
            result_index <= 3'd0;
            found <= 1'b0;
            done <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= ITERATE;
                        index <= 3'd0;
                        min_value <= 8'd255;
                        min_index <= 3'd0;
                        even_found <= 1'b0;
                    end
                end

                ITERATE: begin
                    // Check current element
                    if (arr[index][0] == 1'b0) begin
                        // Element is even
                        if (!even_found || arr[index] < min_value) begin
                            min_value <= arr[index];
                            min_index <= index;
                            even_found <= 1'b1;
                        end
                    end

                    // Move to next element
                    if (index == 3'd7) begin
                        state <= DONE;
                    end else begin
                        index <= index + 3'd1;
                    end
                end

                DONE: begin
                    // Output results
                    if (even_found) begin
                        result_value <= min_value;
                        result_index <= min_index;
                        found <= 1'b1;
                    end else begin
                        result_value <= 8'd0;
                        result_index <= 3'd0;
                        found <= 1'b0;
                    end
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule