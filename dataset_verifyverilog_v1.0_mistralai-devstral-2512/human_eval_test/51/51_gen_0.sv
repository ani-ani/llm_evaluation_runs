module RemoveVowels(
    input clk,
    input rst_n,
    input start,
    input [7:0] char_in,
    input valid_in,
    input done_in,
    output reg [7:0] char_out,
    output reg valid_out,
    output reg done,
    output reg busy
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] PROCESSING = 2'd1;
    localparam [1:0] OUTPUTTING = 2'd2;
    localparam [1:0] DONE_STATE = 2'd3;

    // FIFO buffer for input characters (16 entries)
    reg [7:0] fifo [0:15];
    reg [3:0] wr_ptr;
    reg [3:0] rd_ptr;
    reg [3:0] count;

    // State machine
    reg [1:0] state;
    reg [7:0] current_char;
    reg vowel_flag;

    // Vowel detection
    always @(*) begin
        vowel_flag = (char_in == 8'd97) ||  // 'a'
                     (char_in == 8'd101) || // 'e'
                     (char_in == 8'd105) || // 'i'
                     (char_in == 8'd111) || // 'o'
                     (char_in == 8'd117) || // 'u'
                     (char_in == 8'd65) ||  // 'A'
                     (char_in == 8'd69) ||  // 'E'
                     (char_in == 8'd73) ||  // 'I'
                     (char_in == 8'd79) ||  // 'O'
                     (char_in == 8'd85);    // 'U'
    end

    // FIFO write logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wr_ptr <= 4'd0;
            rd_ptr <= 4'd0;
            count <= 4'd0;
        end else begin
            if (state == PROCESSING && valid_in && count < 4'd16) begin
                fifo[wr_ptr] <= char_in;
                wr_ptr <= wr_ptr + 4'd1;
                count <= count + 4'd1;
            end
        end
    end

    // Main FSM
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            char_out <= 8'd0;
            valid_out <= 1'b0;
            done <= 1'b0;
            busy <= 1'b0;
            current_char <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    busy <= 1'b0;
                    valid_out <= 1'b0;
                    done <= 1'b0;
                    if (start) begin
                        state <= PROCESSING;
                        busy <= 1'b1;
                    end
                end

                PROCESSING: begin
                    busy <= 1'b1;
                    if (done_in) begin
                        state <= OUTPUTTING;
                    end
                end

                OUTPUTTING: begin
                    busy <= 1'b1;
                    if (count > 4'd0) begin
                        current_char <= fifo[rd_ptr];
                        if (!vowel_flag) begin
                            char_out <= current_char;
                            valid_out <= 1'b1;
                        end else begin
                            valid_out <= 1'b0;
                        end
                        rd_ptr <= rd_ptr + 4'd1;
                        count <= count - 4'd1;
                    end else begin
                        state <= DONE_STATE;
                    end
                end

                DONE_STATE: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule