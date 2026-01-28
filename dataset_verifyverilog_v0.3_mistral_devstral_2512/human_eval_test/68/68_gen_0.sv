module pluck_even(
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
    reg [2:0] counter;
    reg [7:0] min_value;
    reg [2:0] min_index;
    reg even_found;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            counter <= 3'd0;
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
                        counter <= 3'd0;
                        min_value <= 8'd0;
                        min_index <= 3'd0;
                        even_found <= 1'b0;
                    end
                end

                ITERATE: begin
                    // Check current element
                    if (arr[counter][0] == 1'b0) begin  // Even check
                        if (!even_found || arr[counter] < min_value) begin
                            min_value <= arr[counter];
                            min_index <= counter;
                            even_found <= 1'b1;
                        end
                    end

                    // Move to next element or finish
                    if (counter == 3'd7) begin
                        state <= DONE;
                    end else begin
                        counter <= counter + 3'd1;
                    end
                end

                DONE: begin
                    result_value <= min_value;
                    result_index <= min_index;
                    found <= even_found;
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule