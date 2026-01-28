module LastCharExtractor(
    input clk,
    input rst_n,
    input start,
    output reg done,
    input [3:0] num_strings,
    input [3:0] string_len [0:7],
    input [127:0] strings [0:7],
    output reg [7:0] result [0:7],
    output reg valid
);

    reg [3:0] state;
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] PROCESS = 2'd1;
    localparam [1:0] DONE_STATE = 2'd2;

    integer i;
    reg [7:0] last_char [0:7];
    reg [3:0] clamped_len [0:7];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            valid <= 1'b0;
            for (i = 0; i < 8; i = i + 1) begin
                result[i] <= 8'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    valid <= 1'b0;
                    if (start) begin
                        state <= PROCESS;
                    end
                end

                PROCESS: begin
                    // Clamp lengths and extract characters
                    for (i = 0; i < 8; i = i + 1) begin
                        // Clamp length to 1-16 range
                        if (string_len[i] == 4'd0) begin
                            clamped_len[i] <= 4'd1;
                        end else if (string_len[i] > 4'd16) begin
                            clamped_len[i] <= 4'd16;
                        end else begin
                            clamped_len[i] <= string_len[i];
                        end

                        // Calculate position and extract character
                        last_char[i] <= strings[i][(clamped_len[i] - 4'd1) * 8 + 7 : (clamped_len[i] - 4'd1) * 8];
                    end

                    // Pack results
                    for (i = 0; i < 8; i = i + 1) begin
                        result[i] <= last_char[i];
                    end

                    valid <= 1'b1;
                    state <= DONE_STATE;
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