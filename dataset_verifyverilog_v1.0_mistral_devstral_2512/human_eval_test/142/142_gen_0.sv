module sum_squares(
    input clk,
    input rst_n,
    input start,
    input [7:0] arr [0:15],
    output reg [31:0] result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] PROCESSING = 2'd1;
    localparam [1:0] DONE_STATE = 2'd2;

    reg [1:0] state;
    reg [3:0] index;
    reg signed [31:0] sum;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            index <= 4'd0;
            sum <= 32'd0;
            result <= 32'd0;
            done <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= PROCESSING;
                        index <= 4'd0;
                        sum <= 32'd0;
                    end
                end

                PROCESSING: begin
                    // Process current element
                    if (index == 4'd15) begin
                        state <= DONE_STATE;
                    end else begin
                        index <= index + 4'd1;
                    end
                end

                DONE_STATE: begin
                    result <= sum;
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

    // Combinational logic for processing
    always @(*) begin
        if (state == PROCESSING) begin
            reg signed [7:0] current_val = arr[index];
            reg signed [15:0] square_val;
            reg signed [23:0] cube_val;
            reg signed [31:0] transformed_val;

            // Compute square or cube based on index
            if (index % 3 == 0) begin
                square_val = $signed(current_val) * $signed(current_val);
                transformed_val = $signed(square_val);
            end else if (index % 4 == 0) begin
                cube_val = $signed(current_val) * $signed(current_val) * $signed(current_val);
                transformed_val = $signed(cube_val);
            end else begin
                transformed_val = $signed(current_val);
            end

            // Update sum
            sum = sum + transformed_val;
        end
    end

endmodule