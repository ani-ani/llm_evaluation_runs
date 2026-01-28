module move_num #(
    parameter MAX_LEN = 16,
    parameter CHAR_WIDTH = 8
) (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [CHAR_WIDTH-1:0] str_in [0:MAX_LEN-1],
    input wire [4:0] len_in,
    output reg [CHAR_WIDTH-1:0] str_out [0:MAX_LEN-1],
    output reg [4:0] len_out,
    output reg done
);

    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] PROCESS = 2'd1;
    localparam [1:0] FINISH = 2'd2;

    reg [1:0] state, next_state;
    reg [4:0] read_idx;
    reg [4:0] write_letters_idx;
    reg [4:0] digit_count;
    reg [CHAR_WIDTH-1:0] digit_buffer [0:MAX_LEN-1];
    reg [CHAR_WIDTH-1:0] temp_out [0:MAX_LEN-1];
    reg [4:0] temp_len;
    wire is_digit;
    integer i;

    assign is_digit = (str_in[read_idx] >= 8'h30) && (str_in[read_idx] <= 8'h39);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            read_idx <= 5'd0;
            write_letters_idx <= 5'd0;
            digit_count <= 5'd0;
            done <= 1'b0;
            len_out <= 5'd0;
            temp_len <= 5'd0;
            for (i = 0; i < MAX_LEN; i = i + 1) begin
                temp_out[i] <= 8'd0;
                digit_buffer[i] <= 8'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start && len_in > 5'd0) begin
                        read_idx <= 5'd0;
                        write_letters_idx <= 5'd0;
                        digit_count <= 5'd0;
                        next_state <= PROCESS;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                PROCESS: begin
                    if (read_idx < len_in) begin
                        if (is_digit) begin
                            digit_buffer[digit_count] <= str_in[read_idx];
                            digit_count <= digit_count + 5'd1;
                        end else begin
                            temp_out[write_letters_idx] <= str_in[read_idx];
                            write_letters_idx <= write_letters_idx + 5'd1;
                        end
                        read_idx <= read_idx + 5'd1;
                        next_state <= PROCESS;
                    end else begin
                        for (i = 0; i < MAX_LEN; i = i + 1) begin
                            if (i < digit_count) begin
                                temp_out[write_letters_idx + i] <= digit_buffer[digit_count - 5'd1 - i];
                            end
                        end
                        temp_len <= write_letters_idx + digit_count;
                        next_state <= FINISH;
                    end
                end

                FINISH: begin
                    for (i = 0; i < MAX_LEN; i = i + 1) begin
                        str_out[i] <= temp_out[i];
                    end
                    len_out <= temp_len;
                    done <= 1'b1;
                    next_state <= IDLE;
                end

                default: next_state <= IDLE;
            endcase
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end

endmodule