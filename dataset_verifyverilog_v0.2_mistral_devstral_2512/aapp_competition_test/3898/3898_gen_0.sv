module puzzle_rearrangement (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [2:0] n,
    input wire [7:0] a_in,
    input wire [7:0] b_in,
    output reg result,
    output reg done
);

    localparam IDLE = 2'b00;
    localparam PROCESSING = 2'b01;
    localparam DONE_STATE = 2'b10;

    reg [1:0] state, next_state;
    reg [7:0] a, b;
    reg [2:0] i_counter;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 0;
            result <= 0;
            i_counter <= 0;
        end else begin
            state <= next_state;
        end
    end

    always @(*) begin
        case (state)
            IDLE: begin
                if (start) next_state = PROCESSING;
                else next_state = IDLE;
            end
            PROCESSING: begin
                if (i_counter >= n) next_state = DONE_STATE;
                else next_state = PROCESSING;
            end
            DONE_STATE: next_state = DONE_STATE;
            default: next_state = IDLE;
        endcase
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            a <= 0;
            b <= 0;
            i_counter <= 0;
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        a <= a_in;
                        b <= b_in;
                        i_counter <= 0;
                    end
                end
                PROCESSING: begin
                    if (i_counter < n) begin
                        if ( ((a >> i_counter) | (a << (n - i_counter))) == b ) begin
                            result <= 1;
                            done <= 1;
                        end else begin
                            i_counter <= i_counter + 1;
                            if (i_counter == n - 1) begin
                                result <= 0;
                                done <= 1;
                            end
                        end
                    end
                end
                DONE_STATE: begin
                    // Hold state
                end
            endcase
        end
    end

endmodule