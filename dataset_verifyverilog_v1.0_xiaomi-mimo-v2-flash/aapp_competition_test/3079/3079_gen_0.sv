module SlavkoGame(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] char_in,
    input wire [3:0] len,
    output reg [63:0] result,
    output reg done,
    output reg win
);

    // State declarations
    localparam [2:0] IDLE       = 3'd0;
    localparam [2:0] READ_INPUT = 3'd1;
    localparam [2:0] PROCESS    = 3'd2;
    localparam [2:0] MIRKO_TURN = 3'd3;
    localparam [2:0] SLAVKO_TURN = 3'd4;
    localparam [2:0] COMPARE    = 3'd5;
    localparam [2:0] FINISH     = 3'd6;

    reg [2:0] state;
    reg [3:0] read_count;
    reg [3:0] turn_count;
    reg [3:0] buffer_index;
    reg [3:0] scan_index;
    reg [3:0] min_index;
    reg [7:0] buffer [0:15];
    reg [7:0] slavko_word [0:7];
    reg [7:0] mirko_word [0:7];
    reg [3:0] slavko_idx;
    reg [3:0] mirko_idx;
    reg [2:0] compare_state;
    reg [3:0] compare_idx;
    reg temp_win;
    reg [7:0] slavko_char;
    reg [7:0] mirko_char;
    reg [3:0] remaining_count;

    integer i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            read_count <= 4'd0;
            turn_count <= 4'd0;
            buffer_index <= 4'd0;
            scan_index <= 4'd0;
            min_index <= 4'd0;
            slavko_idx <= 4'd0;
            mirko_idx <= 4'd0;
            compare_state <= 3'd0;
            compare_idx <= 4'd0;
            temp_win <= 1'b0;
            slavko_char <= 8'd0;
            mirko_char <= 8'd0;
            remaining_count <= 4'd0;
            result <= 64'd0;
            done <= 1'b0;
            win <= 1'b0;
            for (i = 0; i < 16; i = i + 1) begin
                buffer[i] <= 8'd0;
            end
            for (i = 0; i < 8; i = i + 1) begin
                slavko_word[i] <= 8'd0;
                mirko_word[i] <= 8'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        read_count <= 4'd0;
                        state <= READ_INPUT;
                    end
                end

                READ_INPUT: begin
                    if (read_count < len) begin
                        buffer[read_count] <= char_in;
                        read_count <= read_count + 4'd1;
                    end
                    if (read_count == len - 4'd1) begin
                        turn_count <= 4'd0;
                        slavko_idx <= 4'd0;
                        mirko_idx <= 4'd0;
                        buffer_index <= len;
                        state <= PROCESS;
                    end
                end

                PROCESS: begin
                    if (turn_count < (len >> 1)) begin
                        state <= MIRKO_TURN;
                    end else begin
                        compare_state <= 3'd0;
                        compare_idx <= 4'd0;
                        state <= COMPARE;
                    end
                end

                MIRKO_TURN: begin
                    mirko_word[mirko_idx] <= buffer[buffer_index - 4'd1];
                    mirko_idx <= mirko_idx + 4'd1;
                    buffer_index <= buffer_index - 4'd1;
                    remaining_count <= buffer_index - 4'd1;
                    scan_index <= 4'd0;
                    min_index <= 4'd0;
                    state <= SLAVKO_TURN;
                end

                SLAVKO_TURN: begin
                    if (scan_index < remaining_count) begin
                        if (scan_index == 4'd0) begin
                            min_index <= 4'd0;
                        end else begin
                            if (buffer[scan_index] < buffer[min_index]) begin
                                min_index <= scan_index;
                            end
                        end
                        scan_index <= scan_index + 4'd1;
                    end else begin
                        slavko_word[slavko_idx] <= buffer[min_index];
                        slavko_idx <= slavko_idx + 4'd1;
                        for (i = 0; i < 16; i = i + 1) begin
                            if (i >= min_index && i < buffer_index - 4'd1) begin
                                buffer[i] <= buffer[i + 4'd1];
                            end
                        end
                        buffer_index <= buffer_index - 4'd1;
                        turn_count <= turn_count + 4'd1;
                        state <= PROCESS;
                    end
                end

                COMPARE: begin
                    case (compare_state)
                        3'd0: begin
                            if (compare_idx < (len >> 1)) begin
                                slavko_char <= slavko_word[compare_idx];
                                mirko_char <= mirko_word[compare_idx];
                                compare_state <= 3'd1;
                            end else begin
                                temp_win <= 1'b1;
                                compare_state <= 3'd2;
                            end
                        end
                        3'd1: begin
                            if (slavko_char < mirko_char) begin
                                temp_win <= 1'b1;
                                compare_state <= 3'd2;
                            end else if (slavko_char > mirko_char) begin
                                temp_win <= 1'b0;
                                compare_state <= 3'd2;
                            end else begin
                                compare_idx <= compare_idx + 4'd1;
                                compare_state <= 3'd0;
                            end
                        end
                        3'd2: begin
                            result <= 64'd0;
                            for (i = 0; i < 8; i = i + 1) begin
                                result[63-(i*8) -: 8] <= slavko_word[i];
                            end
                            win <= temp_win;
                            state <= FINISH;
                        end
                        default: compare_state <= 3'd0;
                    endcase
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