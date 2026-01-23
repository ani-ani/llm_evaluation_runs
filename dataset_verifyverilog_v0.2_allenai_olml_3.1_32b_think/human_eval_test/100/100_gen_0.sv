module make_a_pile (
    input reg clk,
    input reg rst_n,
    input reg start,
    input reg [3:0] n,
    output reg [7:0] result_data,
    output reg [3:0] result_index,
    output reg result_valid,
    output reg done
);

    // Internal registers
    reg [3:0] n_reg;
    reg [3:0] current_level;
    reg [1:0] state;
    reg done_reg;

    // State definitions
    localparam IDLE = 2'b00;
    localparam PROCESSING = 2'b01;
    localparam DONE = 2'b10;

    always @(posedge clk) begin
        if (!rst_n) begin
            n_reg <= 0;
            current_level <= 0;
            state <= IDLE;
            done_reg <= 0;
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        n_reg <= n;
                        if (n_reg == 0) begin
                            state <= DONE;
                            done_reg <= 1;
                        end else begin
                            current_level <= 0;
                            state <= PROCESSING;
                            done_reg <= 0;
                        end
                    end else begin
                        state <= IDLE;
                        done_reg <= 0;
                    end
                end
                PROCESSING: begin
                    current_level <= current_level + 1;
                    if (current_level == n_reg) begin
                        state <= DONE;
                        done_reg <= 1;
                    end else begin
                        state <= PROCESSING;
                        done_reg <= 0;
                    end
                end
                DONE: begin
                    state <= DONE;
                    done_reg <= 1;
                end
            endcase
        end
    end

    // Combinational assignments
    assign result_data = n_reg + 2 * current_level;
    assign result_index = current_level + 1;
    assign result_valid = (state == PROCESSING);
    assign done = done_reg;

endmodule