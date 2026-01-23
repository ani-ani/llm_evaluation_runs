module remove_odd(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] char_in,
    input wire [3:0] str_len,
    output reg [7:0] char_out,
    output reg out_valid,
    output reg done
);

    // State definitions
    localparam [1:0] IDLE     = 2'd0;
    localparam [1:0] PROCESS  = 2'd1;
    localparam [1:0] DONE     = 2'd2;

    reg [1:0] state;
    reg [3:0] pos_counter;
    reg [3:0] processed_count;
    reg [3:0] str_len_reg;
    localparam [3:0] MAX_LEN = 4'd16;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            pos_counter <= 4'd0;
            processed_count <= 4'd0;
            str_len_reg <= 4'd0;
            char_out <= 8'd0;
            out_valid <= 1'b0;
            done <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    out_valid <= 1'b0;
                    done <= 1'b0;
                    if (start) begin
                        state <= PROCESS;
                        pos_counter <= 4'd1;
                        processed_count <= 4'd0;
                        if (str_len > MAX_LEN)
                            str_len_reg <= MAX_LEN;
                        else
                            str_len_reg <= str_len;
                    end
                end

                PROCESS: begin
                    if (processed_count < str_len_reg) begin
                        // Check if position is even (keep) or odd (skip)
                        if (pos_counter[0] == 1'b0) begin  // Even position
                            char_out <= char_in;
                            out_valid <= 1'b1;
                        end else begin  // Odd position
                            out_valid <= 1'b0;
                        end
                        pos_counter <= pos_counter + 4'd1;
                        processed_count <= processed_count + 4'd1;
                    end else begin
                        out_valid <= 1'b0;
                        done <= 1'b1;
                        state <= DONE;
                    end
                end

                DONE: begin
                    done <= 1'b0;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule