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
    
    reg [1:0] state;
    reg [4:0] read_idx;
    reg [4:0] write_idx;
    reg [4:0] digit_count;
    reg [CHAR_WIDTH-1:0] digit_buffer [0:MAX_LEN-1];
    
    integer i;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            read_idx <= 0;
            write_idx <= 0;
            digit_count <= 0;
            done <= 1'b0;
            len_out <= 5'd0;
            for (i = 0; i < MAX_LEN; i = i + 1) begin
                str_out[i] <= 8'd0;
                digit_buffer[i] <= 8'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start && len_in > 0) begin
                        read_idx <= 0;
                        write_idx <= 0;
                        digit_count <= 0;
                        state <= PROCESS;
                    end else begin
                        state <= IDLE;
                    end
                end
                
                PROCESS: begin
                    if (read_idx < len_in) begin
                        if (str_in[read_idx] >= 8'h30 && str_in[read_idx] <= 8'h39) begin
                            digit_buffer[digit_count] <= str_in[read_idx];
                            digit_count <= digit_count + 1;
                        end else begin
                            str_out[write_idx] <= str_in[read_idx];
                            write_idx <= write_idx + 1;
                        end
                        read_idx <= read_idx + 1;
                    end else begin
                        for (i = 0; i < digit_count; i = i + 1) begin
                            str_out[write_idx + i] <= digit_buffer[digit_count - 1 - i];
                        end
                        len_out <= write_idx + digit_count;
                        state <= FINISH;
                    end
                end
                
                FINISH: begin
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end

endmodule