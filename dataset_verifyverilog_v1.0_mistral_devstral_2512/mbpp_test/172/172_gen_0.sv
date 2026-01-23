module string_pattern_matcher (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] char_in,
    input wire [3:0] str_len,
    output reg [7:0] count,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] PROCESS = 2'd1;
    localparam [1:0] FINISH = 2'd2;

    // Internal signals
    reg [1:0] state;
    reg [3:0] index;
    reg [7:0] window [0:2];
    reg [7:0] cnt;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd255;

    // ASCII values
    localparam CHAR_S = 8'h73;
    localparam CHAR_T = 8'h74;
    localparam CHAR_D = 8'h64;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            index <= 4'd0;
            cnt <= 8'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            window[0] <= 8'd0;
            window[1] <= 8'd0;
            window[2] <= 8'd0;
            count <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= PROCESS;
                        index <= 4'd0;
                        cnt <= 8'd0;
                        window[0] <= 8'd0;
                        window[1] <= 8'd0;
                        window[2] <= 8'd0;
                    end
                end

                PROCESS: begin
                    cycle_count <= cycle_count + 8'd1;

                    // Shift window and load new character
                    window[0] <= window[1];
                    window[1] <= window[2];
                    window[2] <= char_in;

                    // Check for 'std' pattern
                    if (window[0] == CHAR_S && window[1] == CHAR_T && window[2] == CHAR_D) begin
                        cnt <= cnt + 8'd1;
                    end

                    // Update index
                    index <= index + 4'd1;

                    // Check completion conditions
                    if (index >= str_len || cycle_count >= MAX_CYCLES) begin
                        state <= FINISH;
                    end
                end

                FINISH: begin
                    done <= 1'b1;
                    count <= cnt;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule