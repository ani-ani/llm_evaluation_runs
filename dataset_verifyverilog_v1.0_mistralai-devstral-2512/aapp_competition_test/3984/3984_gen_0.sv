module string_game_winner(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] char_in,
    input wire char_valid,
    input wire char_end,
    output reg [15:0] result,
    output reg done,
    output reg valid
);

    // State declarations
    localparam [1:0] IDLE    = 2'd0;
    localparam [1:0] PROCESS = 2'd1;
    localparam [1:0] FINISH  = 2'd2;

    // Internal registers
    reg [1:0] state;
    reg [7:0] current_min;
    reg [3:0] position_counter;
    reg [15:0] result_reg;
    reg done_reg;
    reg valid_reg;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            current_min <= 8'h7F;
            position_counter <= 4'd0;
            result_reg <= 16'd0;
            done_reg <= 1'b0;
            valid_reg <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done_reg <= 1'b0;
                    valid_reg <= 1'b0;
                    if (start) begin
                        state <= PROCESS;
                        current_min <= 8'h7F;
                        position_counter <= 4'd0;
                        result_reg <= 16'd0;
                    end
                end

                PROCESS: begin
                    if (char_valid) begin
                        // Determine winner for current position
                        if (position_counter > 0 && char_in > current_min) begin
                            result_reg[position_counter] <= 1'b1;
                        end else begin
                            result_reg[position_counter] <= 1'b0;
                        end

                        // Update current_min
                        if (char_in < current_min) begin
                            current_min <= char_in;
                        end

                        // Move to next position
                        position_counter <= position_counter + 4'd1;

                        // Check if we've reached the end
                        if (char_end) begin
                            state <= FINISH;
                        end
                    end
                end

                FINISH: begin
                    done_reg <= 1'b1;
                    valid_reg <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

    // Output assignments
    always @(posedge clk) begin
        result <= result_reg;
        done <= done_reg;
        valid <= valid_reg;
    end

endmodule