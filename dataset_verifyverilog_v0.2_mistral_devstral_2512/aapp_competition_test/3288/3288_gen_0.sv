module k_incremental_double_free (
    input clk,
    input rst_n,
    input start,
    input [5:0] k_in,
    input [63:0] n_in,
    output reg [7:0] char_out,
    output reg char_valid,
    output reg done,
    output reg error
);

    // State definitions
    localparam IDLE = 3'b000;
    localparam CHECK = 3'b001;
    localparam FIND_PAIR = 3'b010;
    localparam STREAM = 3'b011;
    localparam FINISHED = 3'b100;

    reg [2:0] state;
    
    // Registers for calculation
    reg [63:0] n_reg;
    reg [63:0] pair_index;
    reg [7:0] char1_idx;
    reg [7:0] char2_idx;
    reg [7:0] stream_pos;
    reg str_type;
    reg [63:0] temp_rem;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            char_valid <= 0;
            done <= 0;
            error <= 0;
            char_out <= 8'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 0;
                    error <= 0;
                    char_valid <= 0;
                    if (start) begin
                        if (k_in != 2) begin
                            error <= 1;
                            state <= FINISHED;
                        end else if (n_in < 1 || n_in > 650) begin
                            error <= 1;
                            state <= FINISHED;
                        end else begin
                            n_reg <= n_in;
                            state <= CHECK;
                        end
                    end
                end

                CHECK: begin
                    char1_idx <= 0;
                    temp_rem <= n_reg - 1;
                    state <= FIND_PAIR;
                end

                FIND_PAIR: begin
                    if ((25 - char1_idx) <= temp_rem) begin
                        temp_rem <= temp_rem - (25 - char1_idx);
                        char1_idx <= char1_idx + 1;
                    end else begin
                        char2_idx <= char1_idx + 1 + temp_rem;
                        str_type <= (n_reg - 1) % 2;
                        stream_pos <= 0;
                        state <= STREAM;
                    end
                end

                STREAM: begin
                    char_valid <= 1;
                    if (stream_pos == 0) begin
                        if (str_type == 0) char_out <= 8'h61 + char1_idx;
                        else char_out <= 8'h61 + char2_idx;
                        stream_pos <= 1;
                    end else if (stream_pos == 1) begin
                        char_out <= 8'h61 + char2_idx;
                        stream_pos <= 2;
                    end else if (stream_pos == 2) begin
                        if (str_type == 0) char_out <= 8'h61 + char1_idx;
                        else char_out <= 8'h61 + char2_idx;
                        state <= FINISHED;
                    end
                end

                FINISHED: begin
                    char_valid <= 0;
                    done <= 1;
                end
            endcase
        end
    end
endmodule