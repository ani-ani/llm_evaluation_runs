module eagleton_solver (
    input clk,
    input rst_n,
    input start,
    input [31:0] k,
    input [31:0] h_0,
    output reg [31:0] max_height,
    output reg done
);

    // State definitions
    localparam [1:0] IDLE = 2'b00;
    localparam [1:0] ADD_LOOP = 2'b01;
    localparam [1:0] DONE = 2'b10;

    reg [1:0] state = IDLE;
    reg [2:0] counter = 0;
    reg [31:0] accumulator = 0;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            counter <= 0;
            accumulator <= 0;
            max_height <= 0;
            done <= 0;
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        state <= ADD_LOOP;
                        accumulator <= h_0;
                        counter <= 0;
                        done <= 0;
                    end
                end
                ADD_LOOP: begin
                    if (counter < 7) begin
                        accumulator <= accumulator + k;
                        counter <= counter + 1;
                    end else begin
                        state <= DONE;
                        max_height <= accumulator;
                    end
                end
                DONE: begin
                    done <= 1;
                    if (!start) begin
                        state <= IDLE;
                        done <= 0;
                    end
                end
            endcase
        end
    end

endmodule