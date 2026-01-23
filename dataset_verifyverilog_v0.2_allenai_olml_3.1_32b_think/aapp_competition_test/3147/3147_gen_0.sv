module square_killer_finder (
    input clk,
    input rst_n,
    input start,
    input [15:0] matrix_row [15:0],
    output reg [4:0] max_size,
    output reg done
);

    reg [4:0] current_size;
    reg [3:0] current_i, current_j;
    reg [4:0] max_size_reg;
    reg done_reg;
    reg [2:0] state;

    localparam IDLE = 3'b0;
    localparam INIT = 3'b1;
    localparam SIZE_LOOP = 3'b2;
    localparam I_LOOP = 3'b3;
    localparam J_LOOP = 3'b4;
    localparam CHECK_SYMM = 3'b5;
    localparam UPDATE = 3'b6;
    localparam DONE_STATE = 3'b7;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_size <= 16;
            current_i <= 0;
            current_j <= 0;
            max_size_reg <= 0;
            done_reg <= 0;
            state <= IDLE;
        end else begin
            case (state)
                IDLE: if (start) state <= INIT;
                INIT: state <= SIZE_LOOP;
                SIZE_LOOP: if (current_size > 1) begin
                    current_i <= 0;
                    current_j <= 0;
                    state <= I_LOOP;
                end else begin
                    done_reg <= 1;
                    state <= DONE_STATE;
                end
                I_LOOP: if (current_i < (16 - current_size)) begin
                    current_i <= current_i + 1;
                    state <= J_LOOP;
                    current_j <= 0;
                end else begin
                    current_size <= current_size - 1;
                    if (current_size < 2) begin
                        done_reg <= 1;
                        state <= DONE_STATE;
                    end else begin
                        state <= I_LOOP;
                    end
                end
                J_LOOP: if (current_j < (16 - current_size)) begin
                    current_j <= current_j + 1;
                    state <= CHECK_SYMM;
                end else begin
                    state <= I_LOOP;
                end
                CHECK_SYMM: state <= UPDATE;
                UPDATE: if (current_size == 2) begin
                    state <= J_LOOP;
                end else begin
                    state <= J_LOOP;
                end
                DONE_STATE: ;
            endcase
        end
    end

    assign max_size = max_size_reg;
    assign done = done_reg;

endmodule