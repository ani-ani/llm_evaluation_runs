module make_a_pile (
    input clk,
    input rst_n,
    input start,
    input [3:0] n,
    output reg [7:0] result_data,
    output reg [3:0] result_index,
    output reg result_valid,
    output reg done
);

    // State encoding
    localparam IDLE = 2'b00;
    localparam PROCESSING = 2'b01;
    localparam DONE = 2'b10;

    reg [1:0] state;
    reg [3:0] level_cnt; // Counts current level (1 to n)
    reg [7:0] stone_cnt; // Current stone count
    reg [3:0] n_reg;     // Registered n value

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result_data <= 8'b0;
            result_index <= 4'b0;
            result_valid <= 1'b0;
            done <= 1'b0;
            level_cnt <= 4'b0;
            stone_cnt <= 8'b0;
            n_reg <= 4'b0;
        end else begin
            case (state)
                IDLE: begin
                    result_valid <= 1'b0;
                    done <= 1'b0;
                    if (start) begin
                        n_reg <= n;
                        if (n == 4'b0000) begin
                            state <= DONE;
                            done <= 1'b1;
                        end else begin
                            state <= PROCESSING;
                            level_cnt <= 4'd1;      // Start at level 1
                            stone_cnt <= {4'b0, n}; // Initialize stones based on n
                            result_data <= {4'b0, n};
                            result_index <= 4'd1;
                            result_valid <= 1'b1;
                        end
                    end
                end

                PROCESSING: begin
                    if (level_cnt < n_reg) begin
                        // Prepare next level
                        level_cnt <= level_cnt + 1'b1;
                        stone_cnt <= stone_cnt + 8'd2;
                        result_data <= stone_cnt + 8'd2;
                        result_index <= level_cnt + 1'b1;
                        result_valid <= 1'b1;
                    end else begin
                        // Current level is n, finish processing
                        state <= DONE;
                        result_valid <= 1'b0;
                        done <= 1'b1;
                    end
                end

                DONE: begin
                    done <= 1'b1;
                    if (!start) begin
                        // Reset logic handles returning to IDLE when start goes low
                        state <= IDLE;
                        done <= 1'b0;
                    end
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule
